-- Preserve commercial adjustments when quote line pricing is re-synced
-- from ConfiguredProducts (catalog/roll updates, recalculations, etc.).

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(
  p_quote_line_id uuid,
  p_force boolean DEFAULT false
)
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
        THEN v_unit_cost / (
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
          THEN v_unit_cost / (
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

  SELECT cim.dealer_price
  INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = v_ql.organization_id
    AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  -- Preserve previously applied commercial adjustment semantics on top of fresh base unit dealer.
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
