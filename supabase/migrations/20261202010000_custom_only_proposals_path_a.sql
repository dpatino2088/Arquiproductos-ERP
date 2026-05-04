-- Path A: allow custom-only proposals (no QuoteLines required),
-- gated by DealerConfiguratorPolicies.allow_custom_only_proposals.

SET search_path = public;

-- 1) Dealer policy flag
ALTER TABLE public."DealerConfiguratorPolicies"
  ADD COLUMN IF NOT EXISTS allow_custom_only_proposals boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.upsert_dealer_configurator_policy(
  p_org_id uuid,
  p_dealer_id uuid,
  p_allowed_product_type_codes text[],
  p_allow_variants_catalog boolean,
  p_allow_accessories_only boolean,
  p_allow_hardware boolean,
  p_allow_operating_system boolean,
  p_allow_custom_only_proposals boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public."DealerConfiguratorPolicies" (
    organization_id,
    dealer_id,
    allowed_product_type_codes,
    allow_variants_catalog,
    allow_accessories_only,
    allow_hardware,
    allow_operating_system,
    allow_custom_only_proposals
  )
  VALUES (
    p_org_id,
    p_dealer_id,
    p_allowed_product_type_codes,
    p_allow_variants_catalog,
    p_allow_accessories_only,
    p_allow_hardware,
    p_allow_operating_system,
    COALESCE(p_allow_custom_only_proposals, false)
  )
  ON CONFLICT (organization_id, dealer_id)
  DO UPDATE SET
    allowed_product_type_codes = EXCLUDED.allowed_product_type_codes,
    allow_variants_catalog = EXCLUDED.allow_variants_catalog,
    allow_accessories_only = EXCLUDED.allow_accessories_only,
    allow_hardware = EXCLUDED.allow_hardware,
    allow_operating_system = EXCLUDED.allow_operating_system,
    allow_custom_only_proposals = EXCLUDED.allow_custom_only_proposals,
    updated_at = now();
END;
$function$;

-- 2) Approval guardrail:
-- allow quote approval with zero QuoteLines only when dealer policy is enabled
-- and there is at least one custom ProposalLine linked to the same quote.
CREATE OR REPLACE FUNCTION public.tg_require_quote_lines_before_approval()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote_line_count integer := 0;
  v_custom_line_count integer := 0;
  v_allow_custom_only boolean := false;
BEGIN
  IF COALESCE(NEW.deleted, false) = false
     AND lower(COALESCE(NEW.status, '')) = 'approved'
     AND lower(COALESCE(OLD.status, '')) IS DISTINCT FROM 'approved' THEN

    SELECT COUNT(*)
      INTO v_quote_line_count
    FROM public."QuoteLines" ql
    WHERE ql.quote_id = NEW.id;

    IF COALESCE(v_quote_line_count, 0) > 0 THEN
      RETURN NEW;
    END IF;

    SELECT COALESCE(dcp.allow_custom_only_proposals, false)
      INTO v_allow_custom_only
    FROM public."DealerConfiguratorPolicies" dcp
    WHERE dcp.organization_id = NEW.organization_id
      AND dcp.dealer_id = NEW.dealer_id
    LIMIT 1;

    IF v_allow_custom_only THEN
      SELECT COUNT(*)
        INTO v_custom_line_count
      FROM public."Proposals" p
      JOIN public."ProposalLines" pl
        ON pl.proposal_id = p.id
      WHERE p.quote_id = NEW.id
        AND COALESCE(p.deleted, false) = false
        AND COALESCE(pl.deleted, false) = false
        AND pl.line_type = 'custom';

      IF COALESCE(v_custom_line_count, 0) > 0 THEN
        RETURN NEW;
      END IF;
    END IF;

    RAISE EXCEPTION 'Cannot approve quote without lines. Add at least one quote line or a custom proposal line before approval.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

-- 3) Include accepted custom ProposalLines when creating Sales Orders.
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

  IF p_user_id IS NOT NULL THEN
    PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created',
      'Sales Order created from Quote', p_user_id, p_user_name,
      jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));
  END IF;

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

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
  v_pl record;
  v_line_num int := 0;
  v_subtotal numeric := 0;
  v_quote_lines_subtotal numeric := 0;
  v_custom_subtotal numeric := 0;
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

  SELECT COALESCE(SUM(
    COALESCE(dealer_price_total,
      COALESCE(quantity, 1) * COALESCE(unit_dealer_price_snapshot, unit_msrp, 0)
    )
  ), 0)
  INTO v_quote_lines_subtotal
  FROM "QuoteLines"
  WHERE quote_id = p_quote_id;

  SELECT COALESCE(SUM(COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0)), 0)
  INTO v_custom_subtotal
  FROM "ProposalLines" pl
  WHERE pl.proposal_id = v_proposal.id
    AND COALESCE(pl.deleted, false) = false
    AND pl.line_type = 'custom';

  v_subtotal := COALESCE(v_quote_lines_subtotal, 0) + COALESCE(v_custom_subtotal, 0);

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

  FOR v_pl IN
    SELECT *
    FROM "ProposalLines"
    WHERE proposal_id = v_proposal.id
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

NOTIFY pgrst, 'reload schema';
