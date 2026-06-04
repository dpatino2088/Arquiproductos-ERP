-- Add 'service' ProductType (per-org, same as catalog) and RPC to set pricing
-- for custom/free-form service lines in Quotes (shipping, installation, etc.).

-- Insert ProductType 'service' for every existing org that already has 'catalog'
INSERT INTO public."ProductTypes" (organization_id, code, name, fulfillment_type, status)
SELECT pt.organization_id, 'service', 'Service', 'supply_only', 'active'
FROM public."ProductTypes" pt
WHERE pt.code = 'catalog'
ON CONFLICT DO NOTHING;

-- RPC: set pricing columns on a service QuoteLine (bypasses trigger guard)
CREATE OR REPLACE FUNCTION public.set_service_quote_line_pricing(
  p_quote_line_id uuid,
  p_name         text,
  p_unit_price   numeric,
  p_qty          numeric,
  p_area         text DEFAULT NULL,
  p_position     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ql_id uuid;
  v_qty   numeric;
  v_price numeric;
BEGIN
  SELECT id INTO v_ql_id FROM public."QuoteLines" WHERE id = p_quote_line_id;
  IF v_ql_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_qty   := GREATEST(COALESCE(p_qty, 1), 1);
  v_price := COALESCE(p_unit_price, 0);

  PERFORM set_config('app.write_source', 'rpc', true);
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    name                      = p_name,
    quantity                  = v_qty,
    area                      = p_area,
    position                  = p_position,
    unit_msrp                 = v_price,
    msrp                      = ROUND(v_price * v_qty, 2),
    net_price                 = ROUND(v_price * v_qty, 2),
    unit_msrp_total_snapshot  = v_price,
    unit_dealer_price_snapshot = v_price,
    dealer_price_total        = ROUND(v_price * v_qty, 2),
    unit_cost_total_snapshot  = 0,
    total_cost                = 0,
    pricing_locked            = true,
    last_priced_at            = now(),
    pricing_version           = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_service_quote_line_pricing(uuid, text, numeric, numeric, text, text) TO authenticated;
