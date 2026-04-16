-- RPC for pricing window film quote lines
-- Unlike catalog items (unit-based), window film is area-based
-- Prices from CatalogItemsMSRP are per m², multiplied by the sold area
CREATE OR REPLACE FUNCTION public.update_window_film_quote_line_pricing(
  p_quote_line_id uuid,
  p_catalog_item_id uuid,
  p_name text,
  p_sku text,
  p_qty integer,
  p_area_m2 numeric,
  p_area text DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_configured_product_id uuid DEFAULT NULL,
  p_config_snapshot jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_ql RECORD;
  v_msrp_per_m2 numeric;
  v_dealer_per_m2 numeric;
  v_cost_per_m2 numeric;
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

  SELECT cim.msrp, cim.dealer_price, cim.total_cost
  INTO v_msrp_per_m2, v_dealer_per_m2, v_cost_per_m2
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.catalog_item_id = p_catalog_item_id
    AND cim.organization_id = v_ql.organization_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  v_msrp_per_m2  := COALESCE(v_msrp_per_m2, 0);
  v_dealer_per_m2 := COALESCE(v_dealer_per_m2, 0);
  v_cost_per_m2  := COALESCE(v_cost_per_m2, 0);

  v_unit_msrp   := ROUND(v_msrp_per_m2 * p_area_m2, 4);
  v_unit_dealer := ROUND(v_dealer_per_m2 * p_area_m2, 4);
  v_unit_cost   := ROUND(v_cost_per_m2 * p_area_m2, 4);

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
$$;
