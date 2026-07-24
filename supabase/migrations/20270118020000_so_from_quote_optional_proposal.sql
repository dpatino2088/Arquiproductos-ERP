-- =====================================================================
-- Fix: Create Sales Order from Quote failed for One-of / service / catalog
-- quotes that skip the Proposal step.
--
-- QT-00334 (service line, no proposal) hit:
--   RAISE 'No accepted proposal found for this quote'
-- while the UI correctly offered "Create Sales Order" once the quote was
-- approved and measures were not required.
--
-- Proposal remains optional: when an accepted proposal exists it is linked;
-- otherwise the SO is created from QuoteLines alone (proposal_id NULL),
-- matching create_sales_order_on_quote_approve.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.create_sales_order_from_quote(
  p_quote_id uuid,
  p_user_id uuid,
  p_user_name text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quote record;
  v_proposal record;
  v_proposal_id uuid := NULL;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric := 0;
  v_quote_lines_count int := 0;
  v_line_total numeric := 0;
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

  IF public.quote_requires_measures(p_quote_id)
     AND NOT COALESCE(v_quote.measures_confirmed, false) THEN
    RAISE EXCEPTION 'Measures must be confirmed for production before creating a Sales Order.';
  END IF;

  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RAISE EXCEPTION 'A Sales Order already exists for this quote';
  END IF;

  -- Optional: MTM dealer flow usually has an accepted proposal; One-of / service /
  -- catalog quotes often go Quote → Approve → SO without a proposal.
  SELECT * INTO v_proposal FROM "Proposals"
    WHERE quote_id = p_quote_id AND status = 'accepted'
    ORDER BY updated_at DESC LIMIT 1;
  IF FOUND THEN
    v_proposal_id := v_proposal.id;
  END IF;

  v_org_id := v_quote.organization_id;
  v_exempt := COALESCE(v_quote.exempt_tax, false);

  SELECT COUNT(*) INTO v_quote_lines_count FROM "QuoteLines" WHERE quote_id = p_quote_id;
  IF v_quote_lines_count = 0 THEN
    RAISE EXCEPTION 'Cannot create a Sales Order for a custom-only quote: it has no Arquiproductos product lines.';
  END IF;

  SELECT COALESCE(SUM(
    COALESCE(dealer_price_total,
      COALESCE(quantity, 1) * COALESCE(unit_dealer_price_snapshot, unit_msrp, 0)
    )
  ), 0)
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
    subtotal, tax_amount, total_amount, exempt_tax, notes
  ) VALUES (
    v_org_id, p_quote_id, v_proposal_id, 'confirmed', 'confirmed',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, v_tax, v_total, v_exempt, v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  FOR v_ql IN
    SELECT * FROM "QuoteLines"
    WHERE quote_id = p_quote_id
    ORDER BY sort_order ASC NULLS LAST, created_at ASC
  LOOP
    v_line_num := v_line_num + 1;
    v_line_total := COALESCE(v_ql.dealer_price_total,
      (COALESCE(v_ql.quantity, 1) * COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0)));
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
      COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0),
      v_line_total,
      v_ql.area, v_ql."position", v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, COALESCE(v_ql.width_m, 0) * COALESCE(v_ql.height_m, 0)
    );
  END LOOP;

  INSERT INTO "SaleOrderAccessories" (
    organization_id, sales_order_id, catalog_item_id,
    qty, unit_cost_exw, unit_price
  )
  SELECT DISTINCT ON (qlc.catalog_item_id)
    v_org_id, v_so_id, qlc.catalog_item_id,
    SUM(qlc.qty) OVER (PARTITION BY qlc.catalog_item_id),
    qlc.unit_cost_exw, qlc.unit_cost_exw
  FROM "QuoteLineComponents" qlc
  JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
  WHERE ql.quote_id = p_quote_id
    AND COALESCE(qlc.deleted, false) = false
    AND (qlc.component_role = 'accessory' OR qlc.source = 'accessory');

  UPDATE "Quotes"
  SET status = 'converted',
      subtotal = v_subtotal,
      tax_amount = v_tax,
      total_amount = v_total,
      updated_at = now()
  WHERE id = p_quote_id;

  IF v_proposal_id IS NOT NULL THEN
    UPDATE "Proposals" SET updated_at = now() WHERE id = v_proposal_id;
  END IF;

  INSERT INTO "ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
  VALUES ('quote', p_quote_id, 'converted_to_so',
          format('Sales Order %s created', v_so_number),
          COALESCE(p_user_name, p_user_id::text),
          v_org_id);

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

NOTIFY pgrst, 'reload schema';
