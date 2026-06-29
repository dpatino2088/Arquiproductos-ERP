-- Dealer-tier-aware pricing for configured products.
--
-- BUG: commit_configured_product_to_quote_line and
-- sync_quote_line_pricing_from_configured_product resolved the dealer tier
-- (and stored dealer_discount_pct / dealer_tier_id_snapshot) but ALWAYS priced
-- the line at the min-margin floor (unit_cost / (1 - minimum_margin_pct) = 0.65),
-- which equals the Platinum tier price. So a Gold/Silver/Bronze dealer got the
-- Platinum price.
--
-- FIX: dealer price = MSRP * (1 - tier_discount_pct/100), with a guardrail floor
-- of the min-margin dealer price. MSRP is universal and UNCHANGED.
--   - Platinum (65% off, msrp_pct 65%) => MSRP*0.35 == floor => no change.
--   - Gold (50% off) => MSRP*0.50 > floor => dealer pays more than Platinum. Correct.
--
-- This does NOT touch the MSRP formula nor calculate_configured_product_totals
-- (which has no dealer context). The override is applied only where the dealer
-- (hence the tier) is actually known.

-- Helper: canonical tier-aware dealer unit price with min-margin guardrail.
CREATE OR REPLACE FUNCTION public.apply_dealer_tier_dealer_price(
  p_unit_msrp numeric,
  p_unit_cost numeric,
  p_discount_pct numeric,
  p_min_margin_pct numeric
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT GREATEST(
    -- tier price: discount applied to the universal MSRP
    ROUND(
      COALESCE(p_unit_msrp, 0)
      * (1 - LEAST(GREATEST(COALESCE(p_discount_pct, 35), 0), 100) / 100.0),
      4
    ),
    -- guardrail floor: min-margin dealer price (never sell below this)
    CASE
      WHEN (1 - COALESCE(p_min_margin_pct, 0.35)) > 0.01
        THEN ROUND(COALESCE(p_unit_cost, 0) / (1 - COALESCE(p_min_margin_pct, 0.35)), 4)
      ELSE 0
    END
  );
$$;

COMMENT ON FUNCTION public.apply_dealer_tier_dealer_price(numeric, numeric, numeric, numeric)
IS 'Tier-aware dealer unit price: MAX(MSRP*(1-discount_pct/100), unit_cost/(1-min_margin_pct)). MSRP universal; tier discount applied with min-margin floor guardrail.';

-- ============================================================================
-- commit_configured_product_to_quote_line: apply tier discount to dealer price
-- ============================================================================
CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(p_org_id uuid, p_quote_id uuid, p_configured_product_id uuid, p_dealer_id uuid DEFAULT NULL::uuid, p_position text DEFAULT NULL::text, p_area text DEFAULT NULL::text, p_fabric_drop text DEFAULT NULL::text, p_installation_type text DEFAULT NULL::text, p_installation_location text DEFAULT NULL::text)
 RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_cp                   RECORD;
  v_roll_item            RECORD;
  v_quote_line_id        uuid;
  v_bom_instance_id      uuid;
  v_width_m              numeric(12,4);
  v_height_m             numeric(12,4);
  v_line_quantity        numeric(12,4);
  v_operating_type       text;
  v_product_type_code    text;
  v_effective_dealer_id  uuid;
  v_dealer_tier_id       uuid;
  v_dealer_tier_code     text;
  v_unit_dealer          numeric(12,4);
  v_totals               jsonb;
  v_installation_type    text;
  v_installation_location text;
  v_has_snapshot_items   boolean := false;
  v_roll_msrp_selected   numeric(12,4) := 0;
  v_bom_msrp_selected    numeric(12,4) := 0;
  v_roll_cost_selected   numeric(12,4) := 0;
  v_bom_cost_selected    numeric(12,4) := 0;
  v_labor_msrp           numeric(12,4) := 0;
  v_labor_cost           numeric(12,4) := 0;
  v_accessories_total    numeric(12,4) := 0;
  v_accessories_cost     numeric(12,4) := 0;
  v_unit_msrp_selected   numeric(12,4) := 0;
  v_unit_cost_selected   numeric(12,4) := 0;
  -- tier-aware pricing
  v_min_margin           numeric := 0.35;
  v_tier_discount_pct    numeric := 35;
  v_unit_msrp_committed  numeric(12,4) := 0;
  v_unit_cost_committed  numeric(12,4) := 0;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  PERFORM public.calculate_configured_product_totals(p_configured_product_id);

  SELECT *
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  v_installation_type := COALESCE(p_installation_type, v_cp.config_snapshot->>'installationType');
  v_installation_location := COALESCE(p_installation_location, v_cp.config_snapshot->>'installationLocation');

  v_has_snapshot_items := COALESCE(jsonb_array_length(COALESCE(v_cp.bom_preview_snapshot->'items', '[]'::jsonb)), 0) > 0;

  WITH roll_items AS (
    SELECT item
    FROM jsonb_array_elements(COALESCE(v_cp.bom_preview_snapshot->'items', '[]'::jsonb)) item
    WHERE item->>'kind' = 'roll'
  ),
  parent_items AS (
    SELECT item
    FROM jsonb_array_elements(COALESCE(v_cp.bom_preview_snapshot->'items', '[]'::jsonb)) item
    WHERE item->>'kind' = 'parent'
      AND COALESCE((item->>'selected')::boolean, false) = true
  )
  SELECT
    COALESCE((SELECT SUM((r.item->>'line_total')::numeric) FROM roll_items r), 0),
    COALESCE((SELECT SUM((r.item->>'cost_total')::numeric) FROM roll_items r), 0),
    COALESCE((
      SELECT SUM(
        (p.item->>'line_total')::numeric
        + COALESCE((
          SELECT SUM((c->>'line_total')::numeric)
          FROM jsonb_array_elements(COALESCE(p.item->'children', '[]'::jsonb)) c
        ), 0)
      )
      FROM parent_items p
    ), 0),
    COALESCE((
      SELECT SUM(
        (p.item->>'cost_total')::numeric
        + COALESCE((
          SELECT SUM((c->>'cost_total')::numeric)
          FROM jsonb_array_elements(COALESCE(p.item->'children', '[]'::jsonb)) c
        ), 0)
      )
      FROM parent_items p
    ), 0)
  INTO v_roll_msrp_selected, v_roll_cost_selected, v_bom_msrp_selected, v_bom_cost_selected;

  v_labor_msrp := COALESCE(
    v_cp.labor_amount,
    v_cp.labor_msrp,
    (v_totals->>'labor_amount')::numeric,
    (v_totals->>'labor_msrp_total')::numeric,
    0
  );
  v_labor_cost := COALESCE(
    v_cp.unit_labor_cost,
    (v_totals->>'labor_cost')::numeric,
    (v_totals->>'unit_labor_cost')::numeric,
    0
  );
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  v_unit_msrp_selected := v_roll_msrp_selected + v_bom_msrp_selected + v_labor_msrp + v_accessories_total;
  v_unit_cost_selected := v_roll_cost_selected + v_bom_cost_selected + v_accessories_cost + v_labor_cost;

  v_unit_dealer := CASE
    WHEN v_has_snapshot_items THEN
      CASE
        WHEN (
          1 - COALESCE(
            (
              SELECT cs.minimum_margin_pct
              FROM public."CostSettings" cs
              WHERE cs.organization_id = v_cp.organization_id
                AND COALESCE(cs.is_active, true)
              ORDER BY cs.created_at DESC
              LIMIT 1
            ),
            0.35
          )
        ) > 0.01
        THEN v_unit_cost_selected / (
          1 - COALESCE(
            (
              SELECT cs.minimum_margin_pct
              FROM public."CostSettings" cs
              WHERE cs.organization_id = v_cp.organization_id
                AND COALESCE(cs.is_active, true)
              ORDER BY cs.created_at DESC
              LIMIT 1
            ),
            0.35
          )
        )
        ELSE 0
      END
    ELSE
      COALESCE(
        NULLIF((v_totals->>'unit_dealer_price')::numeric, 0),
        CASE
          WHEN (
            1 - COALESCE(
              (
                SELECT cs.minimum_margin_pct
                FROM public."CostSettings" cs
                WHERE cs.organization_id = v_cp.organization_id
                  AND COALESCE(cs.is_active, true)
                ORDER BY cs.created_at DESC
                LIMIT 1
              ),
              0.35
            )
          ) > 0.01
          THEN COALESCE(v_cp.total_cost, 0) / (
            1 - COALESCE(
              (
                SELECT cs.minimum_margin_pct
                FROM public."CostSettings" cs
                WHERE cs.organization_id = v_cp.organization_id
                  AND COALESCE(cs.is_active, true)
                ORDER BY cs.created_at DESC
                LIMIT 1
              ),
              0.35
            )
          )
          ELSE 0
        END
      )
  END;

  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_tier_discount_pct
  FROM public."Dealers" d
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE d.id = v_effective_dealer_id
  LIMIT 1;

  IF v_tier_discount_pct IS NULL THEN
    v_tier_discount_pct := 35;
  END IF;

  v_min_margin := COALESCE(
    (
      SELECT cs.minimum_margin_pct
      FROM public."CostSettings" cs
      WHERE cs.organization_id = v_cp.organization_id
        AND COALESCE(cs.is_active, true)
      ORDER BY cs.created_at DESC
      LIMIT 1
    ),
    0.35
  );

  -- Universal MSRP and cost that will be stored on the line.
  v_unit_msrp_committed := CASE WHEN v_has_snapshot_items THEN v_unit_msrp_selected ELSE COALESCE(v_cp.total_msrp, 0) END;
  v_unit_cost_committed := CASE WHEN v_has_snapshot_items THEN v_unit_cost_selected ELSE COALESCE(v_cp.total_cost, 0) END;

  -- Tier-aware dealer price (MSRP unchanged), with min-margin floor guardrail.
  v_unit_dealer := public.apply_dealer_tier_dealer_price(
    v_unit_msrp_committed,
    v_unit_cost_committed,
    v_tier_discount_pct,
    v_min_margin
  );

  SELECT pt.code
  INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id
  LIMIT 1;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id
    AND ci.is_active = true
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer,
    collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, labor_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot, labor_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    unit_dealer_price_snapshot,
    msrp, unit_msrp, net_price,
    total_cost, dealer_price_total,
    dealer_discount_pct, dealer_tier_id_snapshot, dealer_tier_code_snapshot,
    catalog_dealer_unit_snapshot, dealer_price_source,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, v_effective_dealer_id,
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id,
    COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name,
    v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name),
    COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL,
    CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END,
    COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area,
    COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    v_installation_type, v_installation_location,
    CASE WHEN v_has_snapshot_items THEN v_roll_msrp_selected ELSE COALESCE(v_cp.roll_msrp_total, 0) END,
    CASE WHEN v_has_snapshot_items THEN v_bom_msrp_selected ELSE COALESCE(v_cp.bom_total, 0) END,
    v_labor_msrp,
    CASE WHEN v_has_snapshot_items THEN v_roll_cost_selected ELSE COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0) END,
    CASE WHEN v_has_snapshot_items THEN v_bom_cost_selected ELSE COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0) END,
    v_labor_cost,
    v_unit_msrp_committed,
    v_unit_cost_committed,
    v_unit_dealer,
    ROUND(v_unit_msrp_committed * v_line_quantity, 2),
    ROUND(v_unit_msrp_committed, 4),
    ROUND(v_unit_dealer * v_line_quantity, 2),
    ROUND(v_unit_cost_committed * v_line_quantity, 2),
    ROUND(v_unit_dealer * v_line_quantity, 2),
    v_tier_discount_pct,
    v_dealer_tier_id, v_dealer_tier_code,
    (
      SELECT cim.dealer_price
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.organization_id = p_org_id
        AND cim.catalog_item_id = v_cp.roll_catalog_item_id
      ORDER BY cim.updated_at DESC NULLS LAST
      LIMIT 1
    ),
    'tier',
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$function$;

-- ============================================================================
-- sync_quote_line_pricing_from_configured_product: apply tier discount
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid, p_force boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ql                   RECORD;
  v_cp                   RECORD;
  v_totals               jsonb;
  v_qty                  numeric(12,4);
  v_unit_msrp            numeric(12,4);
  v_unit_cost            numeric(12,4);
  v_unit_dealer          numeric(12,4);
  v_dealer_tier_id       uuid;
  v_dealer_tier_code     text;
  v_discount_pct         numeric(5,2);
  v_catalog_dealer_unit  numeric(12,4);
  v_labor_cost           numeric(12,4);
  v_labor_msrp           numeric(12,4);
  v_has_snapshot_items   boolean := false;
  v_roll_msrp_selected   numeric(12,4) := 0;
  v_bom_msrp_selected    numeric(12,4) := 0;
  v_roll_cost_selected   numeric(12,4) := 0;
  v_bom_cost_selected    numeric(12,4) := 0;
  v_accessories_total    numeric(12,4) := 0;
  v_accessories_cost     numeric(12,4) := 0;
  v_total_msrp_selected  numeric(12,4) := 0;
  v_total_cost_selected  numeric(12,4) := 0;
  v_min_margin           numeric := 0.35;

  -- Commercial adjustment preservation
  v_meta                        jsonb := '{}'::jsonb;
  v_adjust                      jsonb := '{}'::jsonb;
  v_non_billable               boolean := false;
  v_extra_discount_pct         numeric := NULL;
  v_extra_discount_amount      numeric := NULL;
  v_has_commercial_adjustment  boolean := false;
  v_adjust_base_unit           numeric(12,4) := 0;
  v_adjust_base_total          numeric(12,4) := 0;
  v_adjust_discount_amount     numeric(12,4) := 0;
  v_adjust_final_total         numeric(12,4) := 0;
  v_adjust_final_unit          numeric(12,4) := 0;
  v_adjust_effective_pct       numeric(5,2) := 0;
  v_effective_dealer_discount  numeric(5,2);
  v_dealer_price_source_text   text := 'tier';
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id, ql.quantity, ql.pricing_locked, ql.quote_id, ql.metadata
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN
    RETURN;
  END IF;

  IF COALESCE(v_ql.pricing_locked, false) = true AND NOT p_force THEN
    RETURN;
  END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT *
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_has_snapshot_items := COALESCE(jsonb_array_length(COALESCE(v_cp.bom_preview_snapshot->'items', '[]'::jsonb)), 0) > 0;

  WITH roll_items AS (
    SELECT item
    FROM jsonb_array_elements(COALESCE(v_cp.bom_preview_snapshot->'items', '[]'::jsonb)) item
    WHERE item->>'kind' = 'roll'
  ),
  parent_items AS (
    SELECT item
    FROM jsonb_array_elements(COALESCE(v_cp.bom_preview_snapshot->'items', '[]'::jsonb)) item
    WHERE item->>'kind' = 'parent'
      AND COALESCE((item->>'selected')::boolean, false) = true
  )
  SELECT
    COALESCE((SELECT SUM((r.item->>'line_total')::numeric) FROM roll_items r), 0),
    COALESCE((SELECT SUM((r.item->>'cost_total')::numeric) FROM roll_items r), 0),
    COALESCE((
      SELECT SUM(
        (p.item->>'line_total')::numeric
        + COALESCE((
          SELECT SUM((c->>'line_total')::numeric)
          FROM jsonb_array_elements(COALESCE(p.item->'children', '[]'::jsonb)) c
        ), 0)
      )
      FROM parent_items p
    ), 0),
    COALESCE((
      SELECT SUM(
        (p.item->>'cost_total')::numeric
        + COALESCE((
          SELECT SUM((c->>'cost_total')::numeric)
          FROM jsonb_array_elements(COALESCE(p.item->'children', '[]'::jsonb)) c
        ), 0)
      )
      FROM parent_items p
    ), 0)
  INTO v_roll_msrp_selected, v_roll_cost_selected, v_bom_msrp_selected, v_bom_cost_selected;

  v_labor_cost := COALESCE(
    v_cp.unit_labor_cost,
    (v_totals->>'labor_cost')::numeric,
    (v_totals->>'unit_labor_cost')::numeric,
    0
  );
  v_labor_msrp := COALESCE(
    v_cp.labor_amount,
    v_cp.labor_msrp,
    (v_totals->>'labor_amount')::numeric,
    (v_totals->>'labor_msrp_total')::numeric,
    0
  );
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  v_total_msrp_selected := v_roll_msrp_selected + v_bom_msrp_selected + v_labor_msrp + v_accessories_total;
  v_total_cost_selected := v_roll_cost_selected + v_bom_cost_selected + v_accessories_cost + v_labor_cost;

  v_unit_msrp := CASE
    WHEN v_has_snapshot_items THEN v_total_msrp_selected
    ELSE COALESCE(v_cp.total_msrp, (v_totals->>'total_msrp')::numeric, 0)
  END;

  v_unit_cost := CASE
    WHEN v_has_snapshot_items THEN v_total_cost_selected
    ELSE COALESCE(v_cp.unit_product_cost, 0) + v_labor_cost
  END;

  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(
      (v_totals->>'total_cost')::numeric,
      COALESCE(v_cp.roll_total_cost, 0)
        + COALESCE(v_cp.bom_total_cost, 0)
        + COALESCE(v_cp.accessories_total_cost, 0)
        + v_labor_cost,
      0
    );
  END IF;

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_ql.quote_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35;
  END IF;

  v_min_margin := COALESCE(
    (
      SELECT cs.minimum_margin_pct
      FROM public."CostSettings" cs
      WHERE cs.organization_id = v_cp.organization_id
        AND COALESCE(cs.is_active, true)
      ORDER BY cs.created_at DESC
      LIMIT 1
    ),
    0.35
  );

  -- Tier-aware dealer price (MSRP unchanged), with min-margin floor guardrail.
  v_unit_dealer := public.apply_dealer_tier_dealer_price(
    v_unit_msrp,
    v_unit_cost,
    v_discount_pct,
    v_min_margin
  );

  SELECT cim.dealer_price
  INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = v_ql.organization_id
    AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  -- Preserve adjustment intent and apply it once on top of current base.
  v_meta := COALESCE(v_ql.metadata, '{}'::jsonb);
  v_adjust := COALESCE(v_meta->'commercial_adjustment', '{}'::jsonb);
  v_non_billable := COALESCE((v_adjust->>'non_billable')::boolean, false);
  v_extra_discount_pct := NULLIF(v_adjust->>'extra_discount_pct', '')::numeric;
  v_extra_discount_amount := NULLIF(v_adjust->>'extra_discount_amount', '')::numeric;
  v_has_commercial_adjustment := v_non_billable
    OR COALESCE(v_extra_discount_pct, 0) > 0
    OR COALESCE(v_extra_discount_amount, 0) > 0;

  IF v_has_commercial_adjustment THEN
    -- Rebase commercial adjustment on the latest computed dealer unit so
    -- catalog/cost updates are reflected, while still applying discount once.
    v_adjust_base_unit := ROUND(COALESCE(v_unit_dealer, 0), 4);
    v_adjust_base_total := ROUND(v_adjust_base_unit * v_qty, 4);

    IF v_non_billable THEN
      v_adjust_discount_amount := v_adjust_base_total;
    ELSIF COALESCE(v_extra_discount_amount, 0) > 0 THEN
      v_adjust_discount_amount := LEAST(ROUND(v_extra_discount_amount, 4), v_adjust_base_total);
    ELSIF COALESCE(v_extra_discount_pct, 0) > 0 THEN
      v_adjust_discount_amount := ROUND(
        v_adjust_base_total * LEAST(100, GREATEST(0, v_extra_discount_pct)) / 100.0,
        4
      );
    ELSE
      v_adjust_discount_amount := 0;
    END IF;

    v_adjust_final_total := ROUND(GREATEST(v_adjust_base_total - v_adjust_discount_amount, 0), 4);
    v_adjust_final_unit := ROUND(v_adjust_final_total / v_qty, 4);
    v_adjust_effective_pct := CASE
      WHEN v_adjust_base_total > 0 THEN ROUND((v_adjust_discount_amount / v_adjust_base_total) * 100.0, 2)
      ELSE 0
    END;

    v_unit_dealer := v_adjust_final_unit;
    v_dealer_price_source_text := 'commercial_adjustment';
    v_effective_dealer_discount := v_adjust_effective_pct;

    v_adjust := jsonb_set(v_adjust, '{base_unit_dealer_price}', to_jsonb(v_adjust_base_unit), true);
    v_adjust := jsonb_set(v_adjust, '{base_line_total}', to_jsonb(v_adjust_base_total), true);
    v_adjust := jsonb_set(v_adjust, '{applied_unit_dealer_price}', to_jsonb(v_adjust_final_unit), true);
    v_adjust := jsonb_set(v_adjust, '{applied_line_total}', to_jsonb(v_adjust_final_total), true);
    v_adjust := jsonb_set(v_adjust, '{effective_discount_pct}', to_jsonb(v_adjust_effective_pct), true);
    v_adjust := jsonb_set(v_adjust, '{applied_at}', to_jsonb(now()), true);
    v_meta := jsonb_set(v_meta, '{commercial_adjustment}', v_adjust, true);
  ELSE
    v_effective_dealer_discount := v_discount_pct;
  END IF;

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);
  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot           = CASE WHEN v_has_snapshot_items THEN v_roll_msrp_selected ELSE COALESCE(v_cp.roll_msrp_total, (v_totals->>'roll_msrp_total')::numeric, 0) END,
    bom_msrp_snapshot            = CASE WHEN v_has_snapshot_items THEN v_bom_msrp_selected ELSE COALESCE(v_cp.bom_total, (v_totals->>'bom_total')::numeric, 0) END,
    labor_msrp_snapshot          = v_labor_msrp,
    roll_cost_snapshot           = CASE WHEN v_has_snapshot_items THEN v_roll_cost_selected ELSE COALESCE(v_cp.roll_total_cost, (v_totals->>'roll_total_cost')::numeric, 0) END,
    bom_cost_snapshot            = CASE WHEN v_has_snapshot_items THEN v_bom_cost_selected ELSE COALESCE(v_cp.bom_total_cost, (v_totals->>'bom_total_cost')::numeric, 0) END,
    labor_cost_snapshot          = v_labor_cost,
    unit_msrp_total_snapshot     = v_unit_msrp,
    unit_cost_total_snapshot     = v_unit_cost,
    unit_dealer_price_snapshot   = v_unit_dealer,
    msrp                         = ROUND(v_unit_msrp * v_qty, 2),
    unit_msrp                    = ROUND(v_unit_msrp, 4),
    net_price                    = ROUND(v_unit_dealer * v_qty, 2),
    total_cost                   = ROUND(v_unit_cost * v_qty, 2),
    dealer_price_total           = ROUND(v_unit_dealer * v_qty, 2),
    dealer_discount_pct          = v_effective_dealer_discount,
    dealer_tier_id_snapshot      = v_dealer_tier_id,
    dealer_tier_code_snapshot    = v_dealer_tier_code,
    catalog_dealer_unit_snapshot = v_catalog_dealer_unit,
    dealer_price_source          = v_dealer_price_source_text,
    metadata                     = v_meta,
    last_priced_at               = now(),
    pricing_version              = COALESCE(pricing_version, 0) + 1,
    pricing_locked               = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$function$;
