-- Window Film pricing normalization to linear meters.
-- Business rule: films are sold by linear meter of the roll (or full roll length),
-- not by square meter.

-- 1) Normalize CatalogItemsMSRP base rate to $/m for window_film items currently in $/m2.
-- total_cost/shipping_cost/import_tax_cost are generated columns.
-- dealer_price/msrp are maintained by existing MSRP triggers based on pricing_cost_exw.
UPDATE public."CatalogItemsMSRP" cim
SET
  pricing_cost_exw = ROUND((cim.pricing_cost_exw * ci.roll_width_m)::numeric, 4),
  pricing_uom      = 'm',
  updated_at       = now()
FROM public."CatalogItems" ci
WHERE cim.catalog_item_id = ci.id
  AND cim.organization_id = ci.organization_id
  AND ci.item_role = 'window_film'
  AND ci.is_active = true
  AND cim.pricing_uom = 'm2'
  AND ci.roll_width_m IS NOT NULL
  AND ci.roll_width_m > 0;

-- 2) Quote pricing RPC: compute Window Film by linear meters.
--    - sell_mode = 'linear' -> unit = rate_per_m * linear_length_m
--    - sell_mode = 'roll'   -> unit = rate_per_m * roll_length_m
-- Fallbacks keep backward compatibility for old snapshots.
CREATE OR REPLACE FUNCTION public.update_window_film_quote_line_pricing(
  p_quote_line_id uuid,
  p_catalog_item_id uuid,
  p_name text,
  p_sku text,
  p_qty integer,
  p_area_m2 numeric,
  p_area text DEFAULT NULL::text,
  p_position text DEFAULT NULL::text,
  p_configured_product_id uuid DEFAULT NULL::uuid,
  p_config_snapshot jsonb DEFAULT NULL::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_ql RECORD;
  v_pricing_uom text;
  v_roll_width_m numeric;
  v_roll_length_m_catalog numeric;
  v_roll_length_m_cfg numeric;
  v_linear_length_m_cfg numeric;
  v_sell_mode text;
  v_unit_length_m numeric;

  v_msrp_rate numeric;
  v_dealer_rate numeric;
  v_cost_rate numeric;
  v_msrp_per_m numeric;
  v_dealer_per_m numeric;
  v_cost_per_m numeric;

  v_unit_msrp numeric;
  v_unit_dealer numeric;
  v_unit_cost numeric;
BEGIN
  SELECT ql.id, ql.organization_id
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  SELECT
    cim.msrp,
    cim.dealer_price,
    cim.total_cost,
    LOWER(COALESCE(cim.pricing_uom, 'm')),
    ci.roll_width_m,
    ci.roll_length_m
  INTO
    v_msrp_rate,
    v_dealer_rate,
    v_cost_rate,
    v_pricing_uom,
    v_roll_width_m,
    v_roll_length_m_catalog
  FROM public."CatalogItemsMSRP" cim
  JOIN public."CatalogItems" ci
    ON ci.id = cim.catalog_item_id
   AND ci.organization_id = cim.organization_id
  WHERE cim.catalog_item_id = p_catalog_item_id
    AND cim.organization_id = v_ql.organization_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  v_msrp_rate   := COALESCE(v_msrp_rate, 0);
  v_dealer_rate := COALESCE(v_dealer_rate, 0);
  v_cost_rate   := COALESCE(v_cost_rate, 0);
  v_roll_width_m := COALESCE(v_roll_width_m, 0);

  -- Normalize all rates to $/m.
  IF v_pricing_uom = 'm2' THEN
    v_msrp_per_m   := v_msrp_rate * v_roll_width_m;
    v_dealer_per_m := v_dealer_rate * v_roll_width_m;
    v_cost_per_m   := v_cost_rate * v_roll_width_m;
  ELSE
    v_msrp_per_m   := v_msrp_rate;
    v_dealer_per_m := v_dealer_rate;
    v_cost_per_m   := v_cost_rate;
  END IF;

  v_sell_mode := LOWER(COALESCE(p_config_snapshot->>'sell_mode', 'roll'));
  v_roll_length_m_cfg := COALESCE(NULLIF(p_config_snapshot->>'roll_length_m', '')::numeric, 0);
  v_linear_length_m_cfg := COALESCE(NULLIF(p_config_snapshot->>'linear_length_m', '')::numeric, 0);

  IF v_sell_mode = 'linear' THEN
    v_unit_length_m := v_linear_length_m_cfg;
  ELSE
    v_unit_length_m := COALESCE(NULLIF(v_roll_length_m_cfg, 0), NULLIF(v_roll_length_m_catalog, 0), 0);
  END IF;

  -- Backward compatibility fallback for legacy payloads (area + width only).
  IF (v_unit_length_m IS NULL OR v_unit_length_m <= 0)
     AND COALESCE(p_area_m2, 0) > 0
     AND v_roll_width_m > 0 THEN
    v_unit_length_m := p_area_m2 / v_roll_width_m;
  END IF;

  v_unit_length_m := GREATEST(COALESCE(v_unit_length_m, 0), 0);

  v_unit_msrp   := ROUND(v_msrp_per_m * v_unit_length_m, 4);
  v_unit_dealer := ROUND(v_dealer_per_m * v_unit_length_m, 4);
  v_unit_cost   := ROUND(v_cost_per_m * v_unit_length_m, 4);

  PERFORM set_config('app.write_source', 'rpc', true);
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    catalog_item_id = p_catalog_item_id,
    configured_product_id = COALESCE(p_configured_product_id, configured_product_id),
    name = p_name,
    sku = p_sku,
    quantity = GREATEST(COALESCE(p_qty, 1), 1),
    area = p_area,
    position = p_position,
    config_snapshot = COALESCE(p_config_snapshot, config_snapshot),
    unit_msrp = v_unit_msrp,
    msrp = ROUND(v_unit_msrp * GREATEST(COALESCE(p_qty, 1), 1), 2),
    net_price = ROUND(v_unit_dealer * GREATEST(COALESCE(p_qty, 1), 1), 2),
    unit_msrp_total_snapshot = v_unit_msrp,
    unit_dealer_price_snapshot = v_unit_dealer,
    dealer_price_total = ROUND(v_unit_dealer * GREATEST(COALESCE(p_qty, 1), 1), 2),
    unit_cost_total_snapshot = v_unit_cost,
    total_cost = ROUND(v_unit_cost * GREATEST(COALESCE(p_qty, 1), 1), 2),
    pricing_locked = true,
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$function$;
