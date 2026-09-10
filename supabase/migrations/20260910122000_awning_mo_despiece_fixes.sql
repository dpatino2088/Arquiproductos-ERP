-- Awning MO despiece fixes
--
-- 1) The load bar (bottom_bar) was missing from the BOM preview snapshot:
--    build_bom_preview_snapshot skips selectable roles (bottom_bar/tube/motor/...)
--    when is_required = false AND the config has no <role>_item_id selection.
--    The awning flow has no bottom-bar picker (there is exactly ONE load bar),
--    so the row must be is_required = true to always be included.
--
-- 2) The curron (center support, per_joint spacing 5999) came out as qty 0:
--    build_bom_preview_snapshot computed per_joint as (panel_count - 1), which is
--    correct for roller intermediates (spacing NULL) but ignores width-based
--    joints. calc_bom_qty (instance engine) already uses CEIL(width/spacing)-1.
--    Patch: when qty_spacing_mm is set, use the width-based formula; otherwise
--    keep the panel-count behavior (rollers unchanged — all their per_joint
--    components have qty_spacing_mm NULL, verified 2026-09-10).

-- ── 1. Load bar always included ────────────────────────────────────────────────
UPDATE public."BOMComponents" bc
SET is_required = true
FROM public."BOMTemplates" b
WHERE b.id = bc.bom_template_id
  AND b.code IN ('AWNING_MONOBLOC_EPSYLON', 'AWNING_VERTICAL_BASIC')
  AND bc.component_role = 'bottom_bar'
  AND bc.deleted = false;

-- ── 2. per_joint width-based when qty_spacing_mm is set ───────────────────────
DO $$
DECLARE
  v_def text;
  v_parent_old text := 'WHEN ''per_joint'' THEN v_qty := GREATEST(0,v_panel_count-1)*COALESCE(v_comp.qty_value,1);';
  v_parent_new text := 'WHEN ''per_joint'' THEN IF v_comp.qty_spacing_mm IS NOT NULL AND v_comp.qty_spacing_mm > 0 THEN v_qty := GREATEST(0, CEIL(GREATEST(0,v_eff_width)/v_comp.qty_spacing_mm::numeric) - 1)*COALESCE(v_comp.qty_value,1); ELSE v_qty := GREATEST(0,v_panel_count-1)*COALESCE(v_comp.qty_value,1); END IF;';
  v_child_old text := 'WHEN ''per_joint'' THEN v_child_qty := GREATEST(0,v_panel_count-1)*COALESCE(v_child.qty_value,1);';
  v_child_new text := 'WHEN ''per_joint'' THEN IF v_child.qty_spacing_mm IS NOT NULL AND v_child.qty_spacing_mm > 0 THEN v_child_qty := GREATEST(0, CEIL(GREATEST(0,v_width_mm+COALESCE(v_child.qty_delta_mm,0))/v_child.qty_spacing_mm::numeric) - 1)*COALESCE(v_child.qty_value,1); ELSE v_child_qty := GREATEST(0,v_panel_count-1)*COALESCE(v_child.qty_value,1); END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'build_bom_preview_snapshot';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'build_bom_preview_snapshot not found';
  END IF;

  -- Idempotency: skip if already patched
  IF position(v_parent_new IN v_def) > 0 THEN
    RAISE NOTICE 'build_bom_preview_snapshot already patched, skipping';
    RETURN;
  END IF;

  IF position(v_parent_old IN v_def) = 0 OR position(v_child_old IN v_def) = 0 THEN
    RAISE EXCEPTION 'per_joint clauses not found in build_bom_preview_snapshot — source changed, review manually';
  END IF;

  v_def := replace(v_def, v_parent_old, v_parent_new);
  v_def := replace(v_def, v_child_old, v_child_new);
  EXECUTE v_def;
END $$;
