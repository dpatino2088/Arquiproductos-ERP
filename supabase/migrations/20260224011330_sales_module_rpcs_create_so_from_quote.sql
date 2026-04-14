
CREATE OR REPLACE FUNCTION create_sales_order_from_quote(p_quote_id uuid, p_user_id uuid, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_quote record;
  v_proposal record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
BEGIN
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN RAISE EXCEPTION 'Quote must be in "approved" status to convert (current: %)', v_quote.status; END IF;

  SELECT * INTO v_proposal FROM "Proposals"
    WHERE quote_id = p_quote_id AND status = 'accepted' AND (deleted IS NULL OR deleted = false)
    ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'No accepted proposal found for this quote'; END IF;

  v_org_id := v_quote.organization_id;

  INSERT INTO "SalesOrders" (
    organization_id, quote_id, proposal_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, payment_status, notes
  ) VALUES (
    v_org_id, p_quote_id, v_proposal.id, 'confirmed', 'confirmed',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_quote.subtotal, v_quote.tax_amount, v_quote.total_amount,
    'pending', v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  FOR v_ql IN
    SELECT * FROM "QuoteLines"
    WHERE quote_id = p_quote_id AND deleted = false
    ORDER BY sort_order ASC NULLS LAST, created_at ASC
  LOOP
    v_line_num := v_line_num + 1;
    INSERT INTO "SalesOrderLines" (
      organization_id, sales_order_id, quote_line_id,
      catalog_item_id, configured_product_id, line_number,
      quantity, unit_price, line_total,
      area, position, description, product_type, product_type_id,
      collection_name, variant_name, hardware_color,
      width_m, height_m, sqm
    ) VALUES (
      v_org_id, v_so_id, v_ql.id,
      v_ql.catalog_item_id, v_ql.configured_product_id, v_line_num,
      COALESCE(v_ql.quantity, 1),
      COALESCE(v_ql.net_price, v_ql.msrp, 0),
      COALESCE(v_ql.net_price, v_ql.msrp, 0) * COALESCE(v_ql.quantity, 1),
      v_ql.area, v_ql.position, v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, v_ql.sqm
    );
  END LOOP;

  UPDATE "Quotes" SET status = 'converted', converted_at = now(), updated_at = now() WHERE id = p_quote_id;
  UPDATE "Proposals" SET updated_at = now() WHERE id = v_proposal.id;

  PERFORM _insert_timeline(v_org_id, 'quote', p_quote_id, 'converted', 'Converted to Sales Order ' || v_so_number, p_user_id, p_user_name, jsonb_build_object('sales_order_id', v_so_id, 'so_number', v_so_number));
  PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created', 'Created from Quote ' || v_quote.quote_no, p_user_id, p_user_name, jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$$;

GRANT EXECUTE ON FUNCTION create_sales_order_from_quote(uuid, uuid, text) TO authenticated;
;
