-- RPC: create SO + lines when quote is approved (no proposal required, does not set quote to 'converted')
SET search_path = public;

CREATE OR REPLACE FUNCTION public.create_sales_order_on_quote_approve(p_quote_id uuid, p_user_id uuid DEFAULT NULL, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quote record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric := 0;
  v_total numeric := 0;
BEGIN
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN
    RAISE EXCEPTION 'Quote must be approved (current: %)', v_quote.status;
  END IF;
  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RETURN jsonb_build_object('ok', true, 'sales_order_id', (SELECT id FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false LIMIT 1), 'so_number', (SELECT sales_order_no FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false LIMIT 1));
  END IF;

  v_org_id := v_quote.organization_id;

  SELECT COALESCE(SUM(COALESCE(dealer_price_total, unit_msrp_total_snapshot, 0)), 0) INTO v_subtotal
  FROM "QuoteLines" WHERE quote_id = p_quote_id;
  v_total := v_subtotal;

  INSERT INTO "SalesOrders" (
    organization_id, quote_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, payment_status, notes
  ) VALUES (
    v_org_id, p_quote_id, 'confirmed', 'pending_confirmation',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, 0, v_total, 'pending', v_quote.notes
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

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$$;;
