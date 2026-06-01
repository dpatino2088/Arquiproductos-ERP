-- =====================================================================
-- Unify production cut geometry onto the canonical engine
-- (compute_cut_breakdown_core), which already carries the corrected
-- per-panel edge split, chained-base inheritance and Σ(panel_cuts)===resolved.
--
-- compute_system_dimensions is the lynchpin: its output (dimension_outputs)
-- is consumed by
--   * create_configured_product_and_bom_preview  (persists the column)
--   * build_bom_preview_snapshot / compute_fabric_pricing_from_rule (fabric width)
--   * generate_bom_for_manufacturing_order        (per-panel cut split, MO)
--   * compute_instance_cut_breakdown               (WO display)
--   * get_panel_cut_mm / get_dimension_panel_count (helpers)
--
-- BEFORE: compute_system_dimensions ran its own (4th) delta engine that only
-- understood tube / bottom_bar / track / headbox and split panels with a
-- simplified endpoint/joint heuristic.
-- AFTER:  it delegates to compute_cut_breakdown_core and emits, for EVERY
-- cuttable role, the exact key contract that downstream consumers expect:
--   <role>_width_mm                         (scalar resolved cut)
--   <role>_panel_cuts[{index, position,     (only when panel_count > 1)
--                      panel_width_mm,
--                      <role>_width_mm}]
--   panel_count, finished_width_mm, finished_height_mm
--   cuts  -> raw canonical breakdown (deductions included, for WO display)
--
-- PRICING NOTE: this does NOT touch component qty/cost in
-- build_bom_preview_snapshot (those keep using the audited v_resolved_cuts
-- cascade). It only changes the geometry/fabric-width source so that the
-- quote and production share the same canonical cut math.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.compute_system_dimensions(p_configured_product_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_cp          RECORD;
  v_config      jsonb;
  v_core_config jsonb;
  v_panels      jsonb;
  v_panel_count integer;
  v_width_mm    numeric;
  v_height_mm   numeric;
  v_breakdown   jsonb;
  v_c           jsonb;
  v_role        text;
  v_resolved    numeric;
  v_pcs         jsonb;
  v_pc          jsonb;
  v_out_pcs     jsonb;
  v_result      jsonb := '{}'::jsonb;
BEGIN
  SELECT cp.*, bt.id AS bt_id
  INTO v_cp
  FROM "ConfiguredProducts" cp
  LEFT JOIN "BOMTemplates" bt ON bt.id = cp.bom_template_id
  WHERE cp.id = p_configured_product_id AND cp.deleted = false;

  IF NOT FOUND OR v_cp.bt_id IS NULL THEN
    RETURN v_result;
  END IF;

  v_width_mm  := COALESCE(v_cp.width_mm, 0);
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_config    := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
  v_panels    := COALESCE(v_config->'panels', v_config->'measurements'->'panels');
  v_panel_count := CASE
    WHEN v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' AND jsonb_array_length(v_panels) > 1
    THEN jsonb_array_length(v_panels)
    ELSE 1
  END;

  -- The canonical core reads `panels` and `drive_side` from the top level of
  -- the config. Stored config_snapshots may nest panels under measurements,
  -- so lift them up without mutating anything else.
  v_core_config := v_config;
  IF v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' THEN
    v_core_config := v_core_config || jsonb_build_object('panels', v_panels);
  END IF;

  v_breakdown := public.compute_cut_breakdown_core(
    v_cp.organization_id,
    v_cp.bt_id,
    v_core_config,
    v_width_mm,
    v_height_mm,
    v_panel_count
  );

  v_result := jsonb_build_object(
    'panel_count',       v_panel_count,
    'finished_width_mm', v_width_mm,
    'finished_height_mm',v_height_mm,
    'source',            'compute_cut_breakdown_core',
    'cuts',              COALESCE(v_breakdown, '[]'::jsonb)
  );

  IF v_breakdown IS NOT NULL AND jsonb_typeof(v_breakdown) = 'array' THEN
    FOR v_c IN SELECT value FROM jsonb_array_elements(v_breakdown) AS value LOOP
      v_role := lower(COALESCE(v_c->>'role', ''));
      IF v_role = '' THEN CONTINUE; END IF;

      -- Scalar resolved cut for the role (Σ panel cuts when per-panel).
      v_resolved := COALESCE((v_c->>'resolved_mm')::numeric, 0);
      v_result := v_result || jsonb_build_object(v_role || '_width_mm', ROUND(v_resolved, 1));

      -- Per-panel cuts (only emitted multi-panel, mirroring the legacy contract
      -- so generate_bom / fabric / get_panel_cut_mm keep working unchanged).
      v_pcs := v_c->'panel_cuts';
      IF v_pcs IS NOT NULL
         AND jsonb_typeof(v_pcs) = 'array'
         AND jsonb_array_length(v_pcs) > 1 THEN
        v_out_pcs := '[]'::jsonb;
        FOR v_pc IN SELECT value FROM jsonb_array_elements(v_pcs) AS value LOOP
          v_out_pcs := v_out_pcs || jsonb_build_object(
            'index',          (v_pc->>'panel')::integer,
            'position',       v_pc->>'position',
            'panel_width_mm', ROUND(COALESCE((v_pc->>'base_mm')::numeric, 0), 1),
            v_role || '_width_mm', ROUND(COALESCE((v_pc->>'cut_mm')::numeric, 0), 1)
          );
        END LOOP;
        v_result := v_result || jsonb_build_object(v_role || '_panel_cuts', v_out_pcs);
      END IF;
    END LOOP;
  END IF;

  RETURN v_result;
END;
$function$;
