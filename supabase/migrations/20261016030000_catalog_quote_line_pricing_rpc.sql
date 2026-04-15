-- RPC to update catalog QuoteLine pricing from CatalogItemsMSRP.
-- Bypasses the trigger guard by setting app.write_source = 'rpc'.
-- Used by the frontend for both ADD and EDIT of catalog items.

CREATE OR REPLACE FUNCTION public.update_catalog_quote_line_pricing(
  p_quote_line_id uuid,
  p_catalog_item_id uuid,
  p_name text,
  p_sku text,
  p_qty numeric,
  p_area text DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_configured_product_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ql RECORD;
  v_msrp numeric;
  v_dealer_price numeric;
  v_total_cost numeric;
  v_qty numeric;
BEGIN
  SELECT ql.id, ql.organization_id
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  SELECT cim.msrp, cim.dealer_price, cim.total_cost
  INTO v_msrp, v_dealer_price, v_total_cost
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.catalog_item_id = p_catalog_item_id
    AND cim.organization_id = v_ql.organization_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  v_msrp := COALESCE(v_msrp, 0);
  v_dealer_price := COALESCE(v_dealer_price, 0);
  v_total_cost := COALESCE(v_total_cost, 0);
  v_qty := GREATEST(COALESCE(p_qty, 1), 1);

  PERFORM set_config('app.write_source', 'rpc', true);
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    catalog_item_id = p_catalog_item_id,
    configured_product_id = COALESCE(p_configured_product_id, configured_product_id),
    name = p_name,
    sku = p_sku,
    quantity = v_qty,
    area = p_area,
    position = p_position,
    unit_msrp = v_msrp,
    msrp = ROUND(v_msrp * v_qty, 2),
    net_price = ROUND(v_dealer_price * v_qty, 2),
    unit_msrp_total_snapshot = v_msrp,
    unit_dealer_price_snapshot = v_dealer_price,
    dealer_price_total = ROUND(v_dealer_price * v_qty, 2),
    unit_cost_total_snapshot = v_total_cost,
    total_cost = ROUND(v_total_cost * v_qty, 2),
    pricing_locked = true,
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$function$;
