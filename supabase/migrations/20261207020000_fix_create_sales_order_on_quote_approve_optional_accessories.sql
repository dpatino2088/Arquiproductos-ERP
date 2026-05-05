-- ============================================================================
-- Fix: create_sales_order_on_quote_approve() unconditionally inserts into
-- "SaleOrderAccessories", a table that never made it to this environment
-- (migration 20260807010000_so_accessories_and_delivery_by_so.sql was not
-- applied). The failed INSERT rolled back the whole RPC, so no SalesOrder
-- was ever created on quote approval (UI showed "Order Created" because
-- the client swallowed the warning, but SO_count remained 0).
--
-- Make the accessory copy step a no-op when the destination table is
-- missing, so the core SO + lines insertion always succeeds. Accessories
-- are already snapshotted on ConfiguredProducts.config_snapshot via the
-- linked SaleOrderLines.configured_product_id, so we don't lose data.
-- ============================================================================

SET search_path = public;

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
  v_pl record;
  v_line_num int := 0;
  v_subtotal numeric := 0;
  v_custom_subtotal numeric := 0;
  v_line_total numeric := 0;
  v_tax_pct numeric := 0;
  v_tax numeric := 0;
  v_total numeric := 0;
  v_exempt boolean;
  v_accepted_proposal_id uuid := NULL;
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

  SELECT p.id
    INTO v_accepted_proposal_id
  FROM "Proposals" p
  WHERE p.quote_id = p_quote_id
    AND p.status = 'accepted'
    AND COALESCE(p.deleted, false) = false
  ORDER BY p.updated_at DESC, p.created_at DESC
  LIMIT 1;

  SELECT COALESCE(SUM(
    COALESCE(dealer_price_total,
      COALESCE(quantity, 1) * COALESCE(unit_dealer_price_snapshot, unit_msrp, 0)
    )
  ), 0) INTO v_subtotal
  FROM "QuoteLines" WHERE quote_id = p_quote_id;

  IF v_accepted_proposal_id IS NOT NULL THEN
    SELECT COALESCE(SUM(COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0)), 0)
      INTO v_custom_subtotal
    FROM "ProposalLines" pl
    WHERE pl.proposal_id = v_accepted_proposal_id
      AND COALESCE(pl.deleted, false) = false
      AND pl.line_type = 'custom';
  END IF;
  v_subtotal := v_subtotal + COALESCE(v_custom_subtotal, 0);

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

  IF v_accepted_proposal_id IS NOT NULL THEN
    FOR v_pl IN
      SELECT *
      FROM "ProposalLines"
      WHERE proposal_id = v_accepted_proposal_id
        AND COALESCE(deleted, false) = false
        AND line_type = 'custom'
      ORDER BY sort_order ASC NULLS LAST, created_at ASC
    LOOP
      v_line_num := v_line_num + 1;
      v_line_total := ROUND(COALESCE(v_pl.qty, 1) * COALESCE(v_pl.unit_price, 0), 2);

      INSERT INTO "SaleOrderLines" (
        organization_id, sales_order_id, line_number,
        quantity, unit_price, line_total, description, area, "position"
      ) VALUES (
        v_org_id, v_so_id, v_line_num,
        COALESCE(v_pl.qty, 1),
        COALESCE(v_pl.unit_price, 0),
        v_line_total,
        COALESCE(v_pl.description, 'Custom line'),
        v_pl.area, v_pl."position"
      );
    END LOOP;
  END IF;

  -- Optional: copy accessories from QuoteLineComponents to SaleOrderAccessories
  -- only when both legacy tables are present in this environment.
  IF to_regclass('public."SaleOrderAccessories"') IS NOT NULL
     AND to_regclass('public."QuoteLineComponents"') IS NOT NULL THEN
    EXECUTE $sql$
      INSERT INTO "SaleOrderAccessories" (
        organization_id, sales_order_id, catalog_item_id,
        qty, unit_cost_exw, unit_price
      )
      SELECT DISTINCT ON (qlc.catalog_item_id)
        $1,
        $2,
        qlc.catalog_item_id,
        SUM(qlc.qty) OVER (PARTITION BY qlc.catalog_item_id),
        qlc.unit_cost_exw,
        qlc.unit_cost_exw
      FROM "QuoteLineComponents" qlc
      JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
      WHERE ql.quote_id = $3
        AND COALESCE(qlc.deleted, false) = false
        AND (qlc.component_role = 'accessory' OR qlc.source = 'accessory')
    $sql$ USING v_org_id, v_so_id, p_quote_id;
  END IF;

  IF p_user_id IS NOT NULL THEN
    PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created',
      'Sales Order created from Quote', p_user_id, p_user_name,
      jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));
  END IF;

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;
