-- Fix: SO subtotal calculation must match the line_total formula.
-- Previously catalog-type QuoteLines (dealer_price_total=NULL, unit_msrp_total_snapshot=NULL)
-- contributed $0 to the subtotal but their msrp was used for the SaleOrderLine.line_total,
-- causing a mismatch where SO.subtotal < SUM(SaleOrderLines.line_total).

CREATE OR REPLACE FUNCTION public.create_sales_order_on_quote_approve(
  p_quote_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quote record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric := 0;
  v_line_total numeric := 0;
  v_tax_pct numeric := 0;
  v_tax numeric := 0;
  v_total numeric := 0;
  v_exempt boolean;
BEGIN
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN
    RAISE EXCEPTION 'Quote must be approved (current: %)', v_quote.status;
  END IF;
  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RETURN jsonb_build_object('ok', true,
      'sales_order_id', (SELECT id FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false LIMIT 1),
      'so_number', (SELECT sales_order_no FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false LIMIT 1));
  END IF;

  v_org_id := v_quote.organization_id;
  v_exempt := COALESCE(v_quote.exempt_tax, false);

  -- Subtotal: use same formula as line_total to ensure consistency
  SELECT COALESCE(SUM(
    COALESCE(dealer_price_total,
      COALESCE(quantity, 1) * COALESCE(unit_dealer_price_snapshot, unit_msrp, 0)
    )
  ), 0) INTO v_subtotal
  FROM "QuoteLines" WHERE quote_id = p_quote_id;

  IF v_exempt THEN
    v_tax_pct := 0;
  ELSE
    SELECT COALESCE(cs.tax_pct, 0) INTO v_tax_pct
    FROM "CostSettings" cs WHERE cs.organization_id = v_org_id LIMIT 1;
  END IF;

  v_tax := ROUND(v_subtotal * v_tax_pct, 2);
  v_total := v_subtotal + v_tax;

  INSERT INTO "SalesOrders" (
    organization_id, quote_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, exempt_tax, notes
  ) VALUES (
    v_org_id, p_quote_id, 'confirmed', 'pending_confirmation',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, v_tax, v_total, v_exempt, v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  FOR v_ql IN
    SELECT * FROM "QuoteLines" WHERE quote_id = p_quote_id ORDER BY sort_order ASC NULLS LAST, created_at ASC
  LOOP
    v_line_num := v_line_num + 1;
    v_line_total := COALESCE(v_ql.dealer_price_total,
      (COALESCE(v_ql.quantity, 1) * COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0)));
    INSERT INTO "SaleOrderLines" (
      organization_id, sales_order_id, quote_line_id, catalog_item_id, configured_product_id, line_number,
      quantity, unit_price, line_total, description, product_type, product_type_id,
      collection_name, variant_name, hardware_color, width_m, height_m, sqm, area, "position"
    ) VALUES (
      v_org_id, v_so_id, v_ql.id, v_ql.catalog_item_id, v_ql.configured_product_id, v_line_num,
      COALESCE(v_ql.quantity, 1),
      COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0),
      v_line_total,
      v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, (COALESCE(v_ql.width_m, 0) * COALESCE(v_ql.height_m, 0)),
      v_ql.area, v_ql."position"
    );
  END LOOP;

  IF p_user_id IS NOT NULL THEN
    PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created',
      'Sales Order created from Quote', p_user_id, p_user_name,
      jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));
  END IF;

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

-- Fix existing SalesOrders where subtotal doesn't match sum of SaleOrderLines
-- Recalculate subtotal from actual line totals, then recompute tax and total
DO $$
DECLARE
  v_so record;
  v_lines_sum numeric;
  v_tax_pct numeric;
  v_tax numeric;
  v_total numeric;
BEGIN
  FOR v_so IN
    SELECT so.id, so.organization_id, so.subtotal, so.exempt_tax,
      (SELECT COALESCE(SUM(line_total), 0) FROM "SaleOrderLines" WHERE sales_order_id = so.id AND deleted = false) as actual_lines_sum
    FROM "SalesOrders" so
    WHERE so.deleted = false
  LOOP
    IF ABS(v_so.subtotal - v_so.actual_lines_sum) > 0.01 THEN
      v_lines_sum := v_so.actual_lines_sum;
      IF COALESCE(v_so.exempt_tax, false) THEN
        v_tax_pct := 0;
      ELSE
        SELECT COALESCE(cs.tax_pct, 0) INTO v_tax_pct
        FROM "CostSettings" cs WHERE cs.organization_id = v_so.organization_id LIMIT 1;
      END IF;
      v_tax := ROUND(v_lines_sum * COALESCE(v_tax_pct, 0), 2);
      v_total := v_lines_sum + v_tax;

      UPDATE "SalesOrders"
      SET subtotal = v_lines_sum, tax_amount = v_tax, total_amount = v_total
      WHERE id = v_so.id;

      RAISE NOTICE 'Fixed SO %: subtotal % -> %, total -> %', v_so.id, v_so.subtotal, v_lines_sum, v_total;
    END IF;
  END LOOP;
END $$;
