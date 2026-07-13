-- ============================================================================
-- Exclude custom Proposal lines from Sales Orders.
--
-- Custom ProposalLines (line_type = 'custom', e.g. "Escaleras", installation,
-- transportation) are the DEALER's own items. Arquiproductos does not
-- manufacture or sell them, so they must live ONLY on the Proposal (the
-- dealer's customer-facing document) and must NOT propagate to the Quote nor
-- to the Sales Order (Arquiproductos' production/sales document).
--
-- Commit 583b327 ("custom-only proposal flow") had made both SO-creation RPCs
-- copy those custom lines into "SaleOrderLines" and add them to the SO totals.
-- This migration reverts that copy in both RPCs and, per business rule, a quote
-- with zero product QuoteLines (custom-only) no longer produces a Sales Order.
--
-- It also cleans up any Sales Orders that already received orphan custom lines,
-- recomputing their totals from the remaining product lines.
-- ============================================================================

SET search_path = public;

-- ── Path A: auto SO on quote approval ───────────────────────────────────────
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
  v_quote_lines_count int := 0;
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

  -- Arquiproductos only sells its own product lines. A custom-only quote (no
  -- QuoteLines, only custom proposal lines) must NOT generate a Sales Order.
  SELECT COUNT(*) INTO v_quote_lines_count FROM "QuoteLines" WHERE quote_id = p_quote_id;
  IF v_quote_lines_count = 0 THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true,
      'reason', 'custom_only_quote_no_product_lines');
  END IF;

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

-- ── Path B: manual "Create Sales Order" from an approved quote ───────────────
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

  IF NOT COALESCE(v_quote.measures_confirmed, false) THEN
    RAISE EXCEPTION 'Measures must be confirmed for production before creating a Sales Order.';
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

  -- Arquiproductos only sells its own product lines. Custom proposal lines are
  -- the dealer's own items and are never copied to the Sales Order. A quote with
  -- zero product lines cannot be converted to a Sales Order.
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

  -- Copy accessories from QuoteLineComponents to SaleOrderAccessories
  INSERT INTO "SaleOrderAccessories" (
    organization_id, sales_order_id, catalog_item_id,
    qty, unit_cost_exw, unit_price
  )
  SELECT DISTINCT ON (qlc.catalog_item_id)
    v_org_id,
    v_so_id,
    qlc.catalog_item_id,
    SUM(qlc.qty) OVER (PARTITION BY qlc.catalog_item_id),
    qlc.unit_cost_exw,
    qlc.unit_cost_exw
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

  UPDATE "Proposals" SET updated_at = now() WHERE id = v_proposal.id;

  INSERT INTO "ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
  VALUES ('quote', p_quote_id, 'converted_to_so',
          format('Sales Order %s created', v_so_number),
          COALESCE(p_user_name, p_user_id::text),
          v_org_id);

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

-- ── One-time cleanup: remove custom proposal lines already copied into SOs ───
-- Orphan custom lines have no product reference (quote_line_id, catalog_item_id
-- and configured_product_id all NULL). Delete them and recompute the parent SO
-- totals from the remaining product lines (tax-aware, exempt-aware).
DO $cleanup$
DECLARE
  v_so record;
  v_subtotal numeric;
  v_tax_pct numeric;
  v_tax numeric;
BEGIN
  FOR v_so IN
    SELECT DISTINCT so.id, so.organization_id, COALESCE(so.exempt_tax, false) AS exempt_tax
    FROM "SalesOrders" so
    JOIN "SaleOrderLines" sol ON sol.sales_order_id = so.id
    WHERE COALESCE(sol.deleted, false) = false
      AND sol.quote_line_id IS NULL
      AND sol.configured_product_id IS NULL
      AND sol.catalog_item_id IS NULL
  LOOP
    DELETE FROM "SaleOrderLines"
    WHERE sales_order_id = v_so.id
      AND quote_line_id IS NULL
      AND configured_product_id IS NULL
      AND catalog_item_id IS NULL;

    SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
    FROM "SaleOrderLines"
    WHERE sales_order_id = v_so.id
      AND COALESCE(deleted, false) = false;

    IF v_so.exempt_tax THEN
      v_tax_pct := 0;
    ELSE
      SELECT COALESCE(cs.tax_pct, 0) INTO v_tax_pct
      FROM "CostSettings" cs WHERE cs.organization_id = v_so.organization_id LIMIT 1;
    END IF;

    v_tax := ROUND(v_subtotal * COALESCE(v_tax_pct, 0), 2);

    UPDATE "SalesOrders"
    SET subtotal = v_subtotal,
        tax_amount = v_tax,
        total_amount = v_subtotal + v_tax,
        updated_at = now()
    WHERE id = v_so.id;
  END LOOP;
END;
$cleanup$;

NOTIFY pgrst, 'reload schema';
