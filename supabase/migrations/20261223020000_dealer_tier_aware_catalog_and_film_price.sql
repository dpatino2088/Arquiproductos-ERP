-- Dealer-tier-aware pricing for catalog items and window film.
--
-- BUG: update_catalog_quote_line_pricing and update_window_film_quote_line_pricing
-- priced the line at the catalog base dealer_price (= MSRP * 0.35 = the min-margin
-- floor = the Platinum tier price), ignoring the quote's dealer tier entirely.
-- So a Gold/Silver/Bronze dealer was given the Platinum price.
--
-- FIX: use the canonical helper apply_dealer_tier_dealer_price (same one used by
-- configured products):
--   dealer = MAX( MSRP * (1 - tier_discount_pct/100), unit_cost / (1 - min_margin) )
-- MSRP is universal and unchanged. Platinum (65% off) lands exactly on the floor
-- (no change); Gold (50%) etc. pay MSRP*(1-disc) > floor. Also persist the tier
-- snapshot columns so the proposal/order reflect the correct margin.
--
-- Custom and service lines are intentionally left as-is: they are priced manually
-- by the user (no MSRP / tier concept).

-- ============================================================================
-- update_catalog_quote_line_pricing: tier-aware dealer price
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_catalog_quote_line_pricing(
  p_quote_line_id uuid,
  p_catalog_item_id uuid,
  p_name text,
  p_sku text,
  p_qty numeric,
  p_area text DEFAULT NULL::text,
  p_position text DEFAULT NULL::text,
  p_configured_product_id uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ql               RECORD;
  v_msrp             numeric;
  v_dealer_base      numeric;
  v_total_cost       numeric;
  v_min_margin       numeric;
  v_qty              numeric;
  v_dealer_tier_id   uuid;
  v_dealer_tier_code text;
  v_discount_pct     numeric;
  v_unit_dealer      numeric;
BEGIN
  SELECT ql.id, ql.organization_id, ql.quote_id
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  SELECT cim.msrp, cim.dealer_price, cim.total_cost, COALESCE(cim.minimum_margin_pct, 0.35)
  INTO v_msrp, v_dealer_base, v_total_cost, v_min_margin
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.catalog_item_id = p_catalog_item_id
    AND cim.organization_id = v_ql.organization_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  v_msrp        := COALESCE(v_msrp, 0);
  v_dealer_base := COALESCE(v_dealer_base, 0);
  v_total_cost  := COALESCE(v_total_cost, 0);
  v_qty         := GREATEST(COALESCE(p_qty, 1), 1);

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_ql.quote_id
  LIMIT 1;
  v_discount_pct := COALESCE(v_discount_pct, 35);

  v_unit_dealer := public.apply_dealer_tier_dealer_price(
    v_msrp, v_total_cost, v_discount_pct, v_min_margin
  );

  PERFORM set_config('app.write_source', 'rpc', true);
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    catalog_item_id              = p_catalog_item_id,
    configured_product_id        = COALESCE(p_configured_product_id, configured_product_id),
    name                         = p_name,
    sku                          = p_sku,
    quantity                     = v_qty,
    area                         = p_area,
    position                     = p_position,
    unit_msrp                    = v_msrp,
    msrp                         = ROUND(v_msrp * v_qty, 2),
    net_price                    = ROUND(v_unit_dealer * v_qty, 2),
    unit_msrp_total_snapshot     = v_msrp,
    unit_dealer_price_snapshot   = v_unit_dealer,
    dealer_price_total           = ROUND(v_unit_dealer * v_qty, 2),
    unit_cost_total_snapshot     = v_total_cost,
    total_cost                   = ROUND(v_total_cost * v_qty, 2),
    dealer_discount_pct          = v_discount_pct,
    dealer_tier_id_snapshot      = v_dealer_tier_id,
    dealer_tier_code_snapshot    = v_dealer_tier_code,
    catalog_dealer_unit_snapshot = v_dealer_base,
    dealer_price_source          = 'tier',
    pricing_locked               = true,
    last_priced_at               = now(),
    pricing_version              = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$function$;

-- ============================================================================
-- update_window_film_quote_line_pricing: tier-aware dealer price (linear meters)
-- ============================================================================
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
SET search_path TO 'public'
AS $function$
DECLARE
  v_ql                    RECORD;
  v_pricing_uom           text;
  v_roll_width_m          numeric;
  v_roll_length_m_catalog numeric;
  v_roll_length_m_cfg     numeric;
  v_linear_length_m_cfg   numeric;
  v_sell_mode             text;
  v_unit_length_m         numeric;

  v_msrp_rate             numeric;
  v_dealer_rate           numeric;
  v_cost_rate             numeric;
  v_min_margin            numeric;
  v_msrp_per_m            numeric;
  v_dealer_per_m          numeric;
  v_cost_per_m            numeric;

  v_unit_msrp             numeric;
  v_unit_dealer           numeric;
  v_unit_cost             numeric;
  v_qty                   integer;

  v_dealer_tier_id        uuid;
  v_dealer_tier_code      text;
  v_discount_pct          numeric;
  v_catalog_dealer_unit   numeric;
BEGIN
  SELECT ql.id, ql.organization_id, ql.quote_id
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
    COALESCE(cim.minimum_margin_pct, 0.35),
    LOWER(COALESCE(cim.pricing_uom, 'm')),
    ci.roll_width_m,
    ci.roll_length_m
  INTO
    v_msrp_rate,
    v_dealer_rate,
    v_cost_rate,
    v_min_margin,
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

  v_msrp_rate    := COALESCE(v_msrp_rate, 0);
  v_dealer_rate  := COALESCE(v_dealer_rate, 0);
  v_cost_rate    := COALESCE(v_cost_rate, 0);
  v_roll_width_m := COALESCE(v_roll_width_m, 0);
  v_qty          := GREATEST(COALESCE(p_qty, 1), 1);

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

  v_unit_msrp := ROUND(v_msrp_per_m * v_unit_length_m, 4);
  v_unit_cost := ROUND(v_cost_per_m * v_unit_length_m, 4);
  -- base (catalog) dealer unit = the Platinum/min-margin floor for this line
  v_catalog_dealer_unit := ROUND(v_dealer_per_m * v_unit_length_m, 4);

  -- Resolve dealer tier from the quote.
  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_ql.quote_id
  LIMIT 1;
  v_discount_pct := COALESCE(v_discount_pct, 35);

  -- Tier-aware dealer price (MSRP unchanged), min-margin floor guardrail.
  v_unit_dealer := public.apply_dealer_tier_dealer_price(
    v_unit_msrp, v_unit_cost, v_discount_pct, v_min_margin
  );

  PERFORM set_config('app.write_source', 'rpc', true);
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    catalog_item_id              = p_catalog_item_id,
    configured_product_id        = COALESCE(p_configured_product_id, configured_product_id),
    name                         = p_name,
    sku                          = p_sku,
    quantity                     = v_qty,
    area                         = p_area,
    position                     = p_position,
    config_snapshot              = COALESCE(p_config_snapshot, config_snapshot),
    unit_msrp                    = v_unit_msrp,
    msrp                         = ROUND(v_unit_msrp * v_qty, 2),
    net_price                    = ROUND(v_unit_dealer * v_qty, 2),
    unit_msrp_total_snapshot     = v_unit_msrp,
    unit_dealer_price_snapshot   = v_unit_dealer,
    dealer_price_total           = ROUND(v_unit_dealer * v_qty, 2),
    unit_cost_total_snapshot     = v_unit_cost,
    total_cost                   = ROUND(v_unit_cost * v_qty, 2),
    dealer_discount_pct          = v_discount_pct,
    dealer_tier_id_snapshot      = v_dealer_tier_id,
    dealer_tier_code_snapshot    = v_dealer_tier_code,
    catalog_dealer_unit_snapshot = v_catalog_dealer_unit,
    dealer_price_source          = 'tier',
    pricing_locked               = true,
    last_priced_at               = now(),
    pricing_version              = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$function$;
