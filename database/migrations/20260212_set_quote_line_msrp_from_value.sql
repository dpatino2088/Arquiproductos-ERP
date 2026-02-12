-- ============================================================================
-- Migration: set_quote_line_msrp_from_value
-- Date: 2026-02-12
-- Description: Fallback RPC to set QuoteLine msrp/unit_msrp from a provided
--              value (e.g. from configurator Review). Use when sync from
--              ConfiguredProduct leaves $0 (e.g. snapshot not yet persisted).
--              Guard trigger allows updates when this RPC sets the flag.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_quote_line_msrp_from_value(
  p_quote_line_id uuid,
  p_total_msrp numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'set_quote_line_msrp_from_value: p_quote_line_id is required';
  END IF;
  IF p_total_msrp IS NULL OR p_total_msrp < 0 THEN
    RETURN;
  END IF;

  SELECT id, organization_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := ROUND(p_total_msrp / v_qty, 4);

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    msrp = ROUND(p_total_msrp, 2),
    unit_msrp = v_unit_msrp,
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.set_quote_line_msrp_from_value(uuid, numeric) IS
'Sets QuoteLine msrp and unit_msrp from provided total (e.g. from configurator). Use as fallback when sync_quote_line_pricing_from_configured_product leaves $0.';
