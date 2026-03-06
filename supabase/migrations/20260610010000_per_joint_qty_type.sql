-- ============================================================================
-- per_joint qty_type: track joins based on max segment length
-- Formula: max(0, ceil(dim_mm / spacing_mm) - 1)
-- Also adds per_spacing support to build_bom_preview_snapshot
-- ============================================================================

-- 1. Helper function for BOM qty calculation (reusable)
CREATE OR REPLACE FUNCTION public.calc_bom_qty(
  p_qty_type text,
  p_qty_value numeric,
  p_qty_delta_mm numeric,
  p_qty_spacing_mm integer,
  p_qty_min numeric,
  p_width_mm numeric,
  p_height_mm numeric,
  p_area_m2 numeric,
  p_force_track_join boolean DEFAULT false
) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_qty numeric;
  v_dim_mm numeric;
BEGIN
  CASE COALESCE(p_qty_type, 'fixed')
    WHEN 'per_width', 'width' THEN
      v_qty := GREATEST(0, (COALESCE(p_width_mm, 0) + COALESCE(p_qty_delta_mm, 0)) / 1000.0);
    WHEN 'per_height', 'height' THEN
      v_qty := GREATEST(0, (COALESCE(p_height_mm, 0) + COALESCE(p_qty_delta_mm, 0)) / 1000.0);
    WHEN 'per_m2', 'area', 'per_area' THEN
      v_qty := GREATEST(0, COALESCE(p_area_m2, 0));
    WHEN 'per_spacing' THEN
      v_dim_mm := COALESCE(p_width_mm, 0);
      IF v_dim_mm <= 0 THEN RETURN 0; END IF;
      v_qty := CEIL(v_dim_mm / GREATEST(COALESCE(p_qty_spacing_mm, 500), 1));
      IF p_qty_min IS NOT NULL AND v_qty < p_qty_min THEN
        v_qty := p_qty_min;
      END IF;
    WHEN 'per_joint' THEN
      v_dim_mm := COALESCE(p_width_mm, 0);
      IF v_dim_mm <= 0 THEN RETURN 0; END IF;
      v_qty := GREATEST(0, CEIL(v_dim_mm / GREATEST(COALESCE(p_qty_spacing_mm, 4000), 1)) - 1);
      IF p_force_track_join AND v_qty = 0 THEN
        v_qty := 1;
      END IF;
    ELSE
      v_qty := COALESCE(p_qty_value, 1);
  END CASE;
  RETURN v_qty;
END;
$$;

COMMENT ON FUNCTION public.calc_bom_qty IS 'Calculates BOM component quantity based on qty_type. Supports: fixed, per_width, per_height, per_area, per_spacing, per_joint. per_joint = max(0, ceil(dim/spacing)-1) for track joins.';
