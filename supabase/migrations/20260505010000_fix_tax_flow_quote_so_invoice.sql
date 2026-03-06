-- Fix complete tax flow: Quote → SO → Invoice
-- 1. Add exempt_tax column to SalesOrders (propagated from Quote)
-- 2. Fix create_sales_order_from_quote to include tax calculation
-- 3. Fix create_sales_order_on_quote_approve to include exempt_tax propagation

ALTER TABLE "SalesOrders" ADD COLUMN IF NOT EXISTS exempt_tax boolean NOT NULL DEFAULT false;

-- Backfill exempt_tax from associated Quotes
UPDATE "SalesOrders" so
SET exempt_tax = COALESCE(q.exempt_tax, false)
FROM "Quotes" q
WHERE q.id = so.quote_id AND so.deleted = false;

-- Fix create_sales_order_from_quote: now computes tax from CostSettings, respects exempt_tax
CREATE OR REPLACE FUNCTION public.create_sales_order_from_quote(
  p_quote_id uuid,
  p_user_id uuid,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quote record;
  v_proposal record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric;
  v_tax_pct numeric := 0;
  v_tax numeric := 0;
  v_total numeric;
  v_exempt boolean;
BEGIN
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN
    RAISE EXCEPTION 'Quote must be in "approved" status to convert (current: %)', v_quote.status;
  END IF;

  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RAISE EXCEPTION 'A Sales Order already exists for this quote';
  END IF;

  SELECT * INTO v_proposal FROM "Proposals"
    WHERE quote_id = p_quote_id AND status = 'accepted'
    ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No accepted proposal found for this quote';
  END IF;

  v_org_id := v_quote.organization_id;
  v_exempt := COALESCE(v_quote.exempt_tax, false);

  SELECT COALESCE(SUM(COALESCE(dealer_price_total, 0)), 0)
  INTO v_subtotal
  FROM "QuoteLines"
  WHERE quote_id = p_quote_id;

  IF v_exempt THEN
    v_tax_pct := 0;
  ELSE
    SELECT COALESCE(cs.tax_pct, 0) INTO v_tax_pct
    FROM "CostSettings" cs WHERE cs.organization_id = v_org_id LIMIT 1;
  END IF;

  v_tax := ROUND(v_subtotal * v_tax_pct, 2);
  v_total := v_subtotal + v_tax;

  INSERT INTO "SalesOrders" (
    organization_id, quote_id, proposal_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, exempt_tax, payment_status, notes
  ) VALUES (
    v_org_id, p_quote_id, v_proposal.id, 'confirmed', 'confirmed',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, v_tax, v_total, v_exempt,
    'pending', v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  FOR v_ql IN
    SELECT * FROM "QuoteLines"
    WHERE quote_id = p_quote_id
    ORDER BY sort_order ASC NULLS LAST, created_at ASC
  LOOP
    v_line_num := v_line_num + 1;
    INSERT INTO "SaleOrderLines" (
      organization_id, sales_order_id, quote_line_id,
      catalog_item_id, configured_product_id, line_number,
      quantity, unit_price, line_total,
      area, "position", description, product_type, product_type_id,
      collection_name, variant_name, hardware_color,
      width_m, height_m, sqm
    ) VALUES (
      v_org_id, v_so_id, v_ql.id,
      v_ql.catalog_item_id, v_ql.configured_product_id, v_line_num,
      COALESCE(v_ql.quantity, 1),
      COALESCE(v_ql.unit_dealer_price_snapshot, 0),
      COALESCE(v_ql.dealer_price_total, 0),
      v_ql.area, v_ql."position", v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, v_ql.width_m * v_ql.height_m
    );
  END LOOP;

  UPDATE "Quotes"
  SET status = 'converted',
      subtotal = v_subtotal,
      tax_amount = v_tax,
      total_amount = v_total,
      updated_at = now()
  WHERE id = p_quote_id;

  UPDATE "Proposals" SET updated_at = now() WHERE id = v_proposal.id;

  PERFORM _insert_timeline(v_org_id, 'quote', p_quote_id, 'converted',
    'Converted to Sales Order ' || v_so_number,
    p_user_id, p_user_name,
    jsonb_build_object('sales_order_id', v_so_id, 'so_number', v_so_number));

  PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created',
    'Created from Quote ' || v_quote.quote_no,
    p_user_id, p_user_name,
    jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

-- Fix create_sales_order_on_quote_approve: also propagate exempt_tax
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

  SELECT COALESCE(SUM(COALESCE(dealer_price_total, unit_msrp_total_snapshot, 0)), 0) INTO v_subtotal
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
    INSERT INTO "SaleOrderLines" (
      organization_id, sales_order_id, quote_line_id, catalog_item_id, configured_product_id, line_number,
      quantity, unit_price, line_total, description, product_type, product_type_id,
      collection_name, variant_name, hardware_color, width_m, height_m, sqm, area, "position"
    ) VALUES (
      v_org_id, v_so_id, v_ql.id, v_ql.catalog_item_id, v_ql.configured_product_id, v_line_num,
      COALESCE(v_ql.quantity, 1),
      COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0),
      COALESCE(v_ql.dealer_price_total, (COALESCE(v_ql.quantity, 1) * COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0))),
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
