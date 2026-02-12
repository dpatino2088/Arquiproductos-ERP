-- ============================================================================
-- Migration: set_quote_line_msrp_from_value — treat value as per-unit total
-- Date: 2026-02-13
-- Description: p_total_msrp is the MSRP total for ONE unit (from configurator Review).
--              unit_msrp = p_total_msrp; msrp = unit_msrp * line quantity.
--              Fixes identical products showing different unit prices when qty differs.
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
  v_line_msrp numeric(12,4);
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

  -- p_total_msrp = per-unit total (from configurator Review). Same product => same unit price.
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := ROUND(p_total_msrp, 4);
  v_line_msrp := ROUND(v_unit_msrp * v_qty, 2);

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    msrp = v_line_msrp,
    unit_msrp = v_unit_msrp,
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.set_quote_line_msrp_from_value(uuid, numeric) IS
'Sets QuoteLine unit_msrp from per-unit total (configurator Review); msrp = unit_msrp * quantity. Ensures identical products have the same unit price regardless of quantity.';
