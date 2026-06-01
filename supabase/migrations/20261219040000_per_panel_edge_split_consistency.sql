-- Per-panel consistency fix for compute_cut_breakdown_core.
--
-- PROBLEM: the per-panel distribution of an "edge" (both-ends) deductor applied
-- the FULL delta to each outer panel, so SUM(panel_cuts) diverged from the global
-- resolved_mm (which counts the deductor once). Example: a headbox endcap that the
-- global subtracts as 8mm was applied as 8mm to panel-1 AND 8mm to panel-N (=16mm),
-- breaking the invariant SUM(panel_cuts) === resolved_mm.
--
-- FIX (per-panel section ONLY — global totals are untouched, so no cost/cut total
-- changes and no pricing impact):
--   * edge / both-ends deductor: split its global contribution (delta×qty) across the
--     two outer panels → (delta×qty)/2 to each. Sum across panels == global.
--   * drive_side / passive_side: apply the full global contribution (delta×qty) to the
--     single end panel it belongs to (was delta only; now robust to qty>1). When
--     drive_side='both', split (delta×qty)/2 across both ends.
--   * intermediate (joint) split logic is unchanged (already sums to delta×(N-1)).
--
-- This guarantees SUM(panel_cuts[i].cut_mm) === resolved_mm for every cuttable.

CREATE OR REPLACE FUNCTION public.compute_cut_breakdown_core(p_org_id uuid, p_bom_template_id uuid, p_config_snapshot jsonb DEFAULT '{}'::jsonb, p_width_mm numeric DEFAULT NULL::numeric, p_height_mm numeric DEFAULT NULL::numeric, p_panel_count integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_config_snap  jsonb := COALESCE(p_config_snapshot, '{}'::jsonb);
  v_panels       jsonb := v_config_snap -> 'panels';
  v_width_mm     numeric := COALESCE(p_width_mm, 1000);
  v_height_mm    numeric := COALESCE(p_height_mm, 1000);
  v_panel_count  integer := GREATEST(COALESCE(p_panel_count, 1), 1);

  v_cuttable     RECORD;
  v_deductor     RECORD;
  v_child_ded    RECORD;

  v_result       jsonb := '[]'::jsonb;
  v_resolved_map jsonb := '{}'::jsonb;
  v_panel_cuts_map jsonb := '{}'::jsonb;

  v_role         text;
  v_axis         text;
  v_base_label   text;
  v_base_mm      numeric;
  v_tolerance    numeric;
  v_total_ded    numeric;
  v_resolved_mm  numeric;
  v_deductions   jsonb;
  v_children_sum numeric;
  v_combined_d   numeric;
  v_joint_qty    numeric;

  v_panel_cuts   jsonb;
  v_p_idx        integer;
  v_p_pos        text;
  v_p_width      numeric;
  v_p_cut        numeric;
  v_p_deds       jsonb;
  v_p_total_ded  numeric;
  v_is_edge_left boolean;
  v_is_edge_right boolean;
  v_drive_side   text;
  v_parent_panels jsonb;
  v_amt          numeric;
BEGIN
  IF p_org_id IS NULL OR p_bom_template_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  IF v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' AND jsonb_array_length(v_panels) > 0 THEN
    v_panel_count := jsonb_array_length(v_panels);
  END IF;

  v_drive_side := lower(COALESCE(v_config_snap ->> 'drive_side', 'left'));
  IF v_drive_side NOT IN ('left', 'right', 'both') THEN
    v_drive_side := 'left';
  END IF;

  FOR v_cuttable IN
    SELECT bc.id, bc.component_role, bc.depends_on_role,
           COALESCE(bc.cut_delta_mm, 0) AS tolerance,
           COALESCE(bc.cut_axis, '')    AS cut_axis,
           ci.sku                       AS cuttable_sku,
           COALESCE(bc.qty_type, 'fixed') AS qty_type,
           COALESCE(bc.qty_value, 1)    AS qty_value,
           COALESCE(bc.per_panel, false) AS per_panel
      FROM public."BOMComponents" bc
      LEFT JOIN public."CatalogItems" ci
        ON ci.id = bc.component_item_id AND ci.organization_id = p_org_id
     WHERE bc.bom_template_id = p_bom_template_id
       AND bc.organization_id = p_org_id
       AND bc.deleted = false AND bc.archived = false
       AND bc.parent_component_id IS NULL
       AND COALESCE(ci.measure_basis, '') IN ('linear', 'area')
     ORDER BY bc.sort_order
  LOOP
    v_role := v_cuttable.component_role;
    v_tolerance := v_cuttable.tolerance;

    IF v_config_snap ->> (v_role || '_item_id') = 'NONE' THEN CONTINUE; END IF;
    IF v_config_snap ->> v_role = 'false' THEN CONTINUE; END IF;

    IF v_cuttable.cut_axis = 'height' OR v_role IN ('side_channel', 'chain', 'belt', 'brush') THEN
      v_axis := 'height';
    ELSE
      v_axis := 'width';
    END IF;

    IF v_cuttable.depends_on_role IS NOT NULL AND v_cuttable.depends_on_role <> '' AND v_resolved_map ? v_cuttable.depends_on_role THEN
      v_base_label := INITCAP(REPLACE(v_cuttable.depends_on_role, '_', ' '));
      v_base_mm := (v_resolved_map ->> v_cuttable.depends_on_role)::numeric;
    ELSIF v_axis = 'height' THEN
      v_base_label := 'Height';
      v_base_mm := v_height_mm;
    ELSE
      v_base_label := 'Width';
      v_base_mm := v_width_mm;
    END IF;

    v_deductions := '[]'::jsonb;
    v_total_ded := 0;

    FOR v_deductor IN
      SELECT bc2.id, bc2.component_role, ci2.sku,
             ( CASE WHEN COALESCE(bc2.delta_mode, 'subtract') = 'add' THEN -(CASE WHEN v_axis = 'height' THEN COALESCE(ci2.delta_y_mm, 0) ELSE COALESCE(ci2.delta_x_mm, 0) END) WHEN COALESCE(bc2.delta_mode, 'subtract') = 'info' THEN 0 ELSE (CASE WHEN v_axis = 'height' THEN COALESCE(ci2.delta_y_mm, 0) ELSE COALESCE(ci2.delta_x_mm, 0) END) END ) * (CASE WHEN COALESCE(bc2.cut_delta_scope, 'per_item') = 'per_side' THEN 2 ELSE 1 END) AS self_delta,
             COALESCE(NULLIF(bc2.qty_value, 0), 1) AS qty,
             COALESCE(bc2.per_panel, false) AS is_per_panel,
             COALESCE(bc2.qty_type, 'fixed') AS qty_type,
             ( COALESCE(bc2.qty_type, 'fixed') = 'per_joint' OR lower(COALESCE(bc2.component_role, '')) LIKE '%intermediate%' OR lower(COALESCE(bc2.component_role, '')) LIKE '%interconnect%' OR lower(COALESCE(bc2.component_role, '')) LIKE '%joint%' ) AS is_joint_cut_multiplier,
             bc2.condition_key, bc2.condition_value,
             COALESCE(bc2.delta_mode, 'subtract') AS delta_mode,
             COALESCE(bc2.cut_delta_scope, 'per_item') AS cut_delta_scope,
             COALESCE(NULLIF(bc2.placement_section, ''), '') AS placement_section
        FROM public."BOMComponents" bc2
        LEFT JOIN public."CatalogItems" ci2 ON ci2.id = bc2.component_item_id AND ci2.organization_id = p_org_id
       WHERE bc2.bom_template_id = p_bom_template_id
         AND bc2.organization_id = p_org_id
         AND bc2.deleted = false AND bc2.archived = false
         AND bc2.parent_component_id IS NULL
         AND bc2.id <> v_cuttable.id
         AND COALESCE(bc2.delta_mode, 'subtract') IN ('subtract', 'add', 'info')
         AND ( v_role = ANY(string_to_array(COALESCE(bc2.affects_role, ''), ',')) OR ( COALESCE(bc2.affects_role, '') = '' AND COALESCE(NULLIF(bc2.placement_section, ''), '') IN ('drive', 'passive', 'shared') AND ( (v_axis = 'width' AND v_role IN ('tube', 'bottom_bar', 'bottom_channel')) OR (v_axis = 'height' AND v_role IN ('side_channel')) ) ) )
       ORDER BY bc2.sort_order
    LOOP
      IF v_deductor.condition_key IS NOT NULL AND v_deductor.condition_key <> '' THEN
        IF NOT ( v_deductor.condition_key = 'drive_side' AND COALESCE(v_config_snap ->> 'drive_side', '') = 'both' AND COALESCE(v_deductor.condition_value, '') IN ('left', 'right') ) AND COALESCE(v_config_snap ->> v_deductor.condition_key, '') <> COALESCE(v_deductor.condition_value, '') THEN
          CONTINUE;
        END IF;
      END IF;
      IF v_config_snap ->> (v_deductor.component_role || '_item_id') = 'NONE' THEN CONTINUE; END IF;
      IF v_deductor.is_joint_cut_multiplier AND v_panel_count <= 1 THEN CONTINUE; END IF;

      SELECT COALESCE(SUM( CASE WHEN COALESCE(bc_ch.delta_mode, 'subtract') = 'add' THEN -(CASE WHEN v_axis = 'height' THEN COALESCE(ci_ch.delta_y_mm, 0) ELSE COALESCE(ci_ch.delta_x_mm, 0) END) * (CASE WHEN COALESCE(bc_ch.cut_delta_scope, 'per_item') = 'per_side' THEN 2 ELSE 1 END) * COALESCE(NULLIF(bc_ch.qty_value, 0), 1) WHEN COALESCE(bc_ch.delta_mode, 'subtract') = 'info' THEN 0 ELSE (CASE WHEN v_axis = 'height' THEN COALESCE(ci_ch.delta_y_mm, 0) ELSE COALESCE(ci_ch.delta_x_mm, 0) END) * (CASE WHEN COALESCE(bc_ch.cut_delta_scope, 'per_item') = 'per_side' THEN 2 ELSE 1 END) * COALESCE(NULLIF(bc_ch.qty_value, 0), 1) END ), 0)
        INTO v_children_sum
        FROM public."BOMComponents" bc_ch
        LEFT JOIN public."CatalogItems" ci_ch ON ci_ch.id = bc_ch.component_item_id AND ci_ch.organization_id = p_org_id
       WHERE bc_ch.parent_component_id = v_deductor.id
         AND bc_ch.organization_id = p_org_id
         AND bc_ch.deleted = false AND bc_ch.archived = false
         AND COALESCE(bc_ch.delta_mode, 'subtract') IN ('subtract', 'add', 'info');

      v_combined_d := v_deductor.self_delta + v_children_sum;
      v_joint_qty := GREATEST(v_panel_count - 1, 0)::numeric;

      IF v_combined_d <> 0 OR v_deductor.delta_mode = 'info' THEN
        v_deductions := v_deductions || jsonb_build_object(
          'role', v_deductor.component_role, 'sku', COALESCE(v_deductor.sku, '?'),
          'delta', v_combined_d,
          'qty', CASE WHEN v_deductor.is_joint_cut_multiplier THEN v_joint_qty ELSE v_deductor.qty END,
          'total', CASE WHEN v_deductor.is_joint_cut_multiplier THEN v_combined_d * v_joint_qty ELSE v_combined_d * v_deductor.qty END,
          'mode', v_deductor.delta_mode, 'scope', v_deductor.cut_delta_scope, 'qty_type', v_deductor.qty_type,
          'affects_cut', (v_deductor.delta_mode <> 'info'),
          'conditional', (v_deductor.condition_key IS NOT NULL AND v_deductor.condition_key <> ''),
          'intermediate', v_deductor.is_joint_cut_multiplier,
          'position', CASE WHEN v_deductor.placement_section = 'drive' THEN 'drive_side' WHEN v_deductor.placement_section = 'passive' THEN 'passive_side' WHEN v_deductor.placement_section = 'shared' THEN 'edge' WHEN v_deductor.placement_section = 'cuttable' THEN 'center' WHEN v_deductor.is_joint_cut_multiplier THEN 'shared' WHEN v_deductor.is_per_panel THEN 'per_panel' WHEN v_deductor.component_role IN ('drive', 'motor', 'chain_drive') THEN 'drive_side' WHEN v_deductor.component_role = 'end_plug' THEN 'passive_side' ELSE 'edge' END
        );
        IF v_deductor.delta_mode <> 'info' THEN
          v_total_ded := v_total_ded + CASE WHEN v_deductor.is_joint_cut_multiplier THEN v_combined_d * v_joint_qty ELSE v_combined_d * v_deductor.qty END;
        END IF;
      END IF;
    END LOOP;

    FOR v_child_ded IN
      SELECT bc3.component_role, ci3.sku,
             ( CASE WHEN COALESCE(bc3.delta_mode, 'subtract') = 'add' THEN -(CASE WHEN v_axis = 'height' THEN COALESCE(ci3.delta_y_mm, 0) ELSE COALESCE(ci3.delta_x_mm, 0) END) WHEN COALESCE(bc3.delta_mode, 'subtract') = 'info' THEN 0 ELSE (CASE WHEN v_axis = 'height' THEN COALESCE(ci3.delta_y_mm, 0) ELSE COALESCE(ci3.delta_x_mm, 0) END) END ) * (CASE WHEN COALESCE(bc3.cut_delta_scope, 'per_item') = 'per_side' THEN 2 ELSE 1 END) AS delta,
             COALESCE(NULLIF(bc3.qty_value, 0), 1) AS qty,
             COALESCE(bc3.per_panel, false) AS is_per_panel,
             COALESCE(bc3.qty_type, 'fixed') AS qty_type,
             ( COALESCE(bc3.qty_type, 'fixed') = 'per_joint' OR lower(COALESCE(bc3.component_role, '')) LIKE '%intermediate%' OR lower(COALESCE(bc3.component_role, '')) LIKE '%interconnect%' OR lower(COALESCE(bc3.component_role, '')) LIKE '%joint%' ) AS is_joint_cut_multiplier,
             bc3.condition_key, bc3.condition_value,
             COALESCE(bc3.delta_mode, 'subtract') AS delta_mode,
             COALESCE(bc3.cut_delta_scope, 'per_item') AS cut_delta_scope,
             COALESCE(NULLIF(bc3.placement_section, ''), '') AS placement_section
      FROM public."BOMComponents" bc3
      LEFT JOIN public."CatalogItems" ci3 ON ci3.id = bc3.component_item_id AND ci3.organization_id = p_org_id
      WHERE bc3.parent_component_id = v_cuttable.id
        AND bc3.organization_id = p_org_id
        AND bc3.deleted = false AND bc3.archived = false
        AND COALESCE(bc3.delta_mode, 'subtract') IN ('subtract', 'add', 'info')
      ORDER BY bc3.sort_order
    LOOP
      IF v_child_ded.condition_key IS NOT NULL AND v_child_ded.condition_key <> '' THEN
        IF NOT ( v_child_ded.condition_key = 'drive_side' AND COALESCE(v_config_snap ->> 'drive_side', '') = 'both' AND COALESCE(v_child_ded.condition_value, '') IN ('left', 'right') ) AND COALESCE(v_config_snap ->> v_child_ded.condition_key, '') <> COALESCE(v_child_ded.condition_value, '') THEN
          CONTINUE;
        END IF;
      END IF;
      IF v_child_ded.is_joint_cut_multiplier AND v_panel_count <= 1 THEN CONTINUE; END IF;

      IF v_child_ded.delta <> 0 OR v_child_ded.delta_mode = 'info' THEN
        v_joint_qty := GREATEST(v_panel_count - 1, 0)::numeric;
        v_deductions := v_deductions || jsonb_build_object(
          'role', v_child_ded.component_role, 'sku', COALESCE(v_child_ded.sku, '?'),
          'delta', v_child_ded.delta,
          'qty', CASE WHEN v_child_ded.is_joint_cut_multiplier THEN v_joint_qty ELSE v_child_ded.qty END,
          'total', CASE WHEN v_child_ded.is_joint_cut_multiplier THEN v_child_ded.delta * v_joint_qty ELSE v_child_ded.delta * v_child_ded.qty END,
          'mode', v_child_ded.delta_mode, 'scope', v_child_ded.cut_delta_scope, 'qty_type', v_child_ded.qty_type,
          'affects_cut', (v_child_ded.delta_mode <> 'info'),
          'conditional', false,
          'intermediate', v_child_ded.is_joint_cut_multiplier,
          'position', CASE WHEN v_child_ded.placement_section = 'drive' THEN 'drive_side' WHEN v_child_ded.placement_section = 'passive' THEN 'passive_side' WHEN v_child_ded.placement_section = 'shared' THEN 'edge' WHEN v_child_ded.placement_section = 'cuttable' THEN 'center' WHEN v_child_ded.is_joint_cut_multiplier THEN 'shared' WHEN v_child_ded.is_per_panel THEN 'per_panel' WHEN v_child_ded.component_role = 'end_plug' THEN 'passive_side' ELSE 'edge' END
        );
        IF v_child_ded.delta_mode <> 'info' THEN
          v_total_ded := v_total_ded + CASE WHEN v_child_ded.is_joint_cut_multiplier THEN v_child_ded.delta * v_joint_qty ELSE v_child_ded.delta * v_child_ded.qty END;
        END IF;
      END IF;
    END LOOP;

    v_resolved_mm := GREATEST(0, v_base_mm + v_tolerance - v_total_ded);
    v_resolved_map := v_resolved_map || jsonb_build_object(v_role, v_resolved_mm);

    v_panel_cuts := '[]'::jsonb;
    IF v_cuttable.per_panel AND v_panel_count > 1 THEN
      v_parent_panels := NULL;
      IF v_cuttable.depends_on_role IS NOT NULL
         AND v_cuttable.depends_on_role <> ''
         AND v_panel_cuts_map ? v_cuttable.depends_on_role
         AND jsonb_typeof(v_panel_cuts_map -> v_cuttable.depends_on_role) = 'array'
         AND jsonb_array_length(v_panel_cuts_map -> v_cuttable.depends_on_role) >= v_panel_count THEN
        v_parent_panels := v_panel_cuts_map -> v_cuttable.depends_on_role;
      END IF;

      FOR v_p_idx IN 1..v_panel_count LOOP
        v_is_edge_left := (v_p_idx = 1);
        v_is_edge_right := (v_p_idx = v_panel_count);
        v_p_pos := CASE WHEN v_is_edge_left THEN 'left' WHEN v_is_edge_right THEN 'right' ELSE 'center' END;

        IF v_axis = 'height' THEN
          v_p_width := v_height_mm;
        ELSIF v_parent_panels IS NOT NULL THEN
          v_p_width := COALESCE(((v_parent_panels -> (v_p_idx - 1)))::text::numeric, v_width_mm / v_panel_count);
        ELSIF v_cuttable.depends_on_role IS NOT NULL AND v_cuttable.depends_on_role <> '' AND v_resolved_map ? v_cuttable.depends_on_role AND COALESCE(v_width_mm, 0) > 0 THEN
          -- parent is a cuttable resolved globally but NOT per-panel: scale each panel's
          -- config width so the panels inherit the parent's reduced cut proportionally.
          v_p_width := COALESCE(
            CASE WHEN v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' AND v_p_idx <= jsonb_array_length(v_panels)
                 THEN ((v_panels -> (v_p_idx - 1)) ->> 'width_mm')::numeric
                 ELSE v_width_mm / v_panel_count END,
            v_width_mm / v_panel_count
          ) * (v_base_mm / v_width_mm);
        ELSIF v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' AND v_p_idx <= jsonb_array_length(v_panels) THEN
          v_p_width := COALESCE(((v_panels -> (v_p_idx - 1)) ->> 'width_mm')::numeric, v_width_mm / v_panel_count);
        ELSE
          v_p_width := v_width_mm / v_panel_count;
        END IF;

        v_p_deds := '[]'::jsonb;
        v_p_total_ded := 0;

        FOR v_deductor IN
          SELECT d->>'role' AS drole, d->>'sku' AS dsku,
                 COALESCE((d->>'delta')::numeric, 0) AS ddelta,
                 COALESCE((d->>'qty')::numeric, 1) AS dqty,
                 COALESCE((d->>'total')::numeric, 0) AS dtotal,
                 COALESCE(d->>'mode', 'subtract') AS dmode,
                 COALESCE((d->>'intermediate')::boolean, false) AS dinter,
                 COALESCE(d->>'position', 'edge') AS dpos
            FROM jsonb_array_elements(v_deductions) AS d
        LOOP
          IF v_deductor.dinter THEN
            -- Intermediate joint: shared 50/50 between adjacent panels.
            IF v_is_edge_left OR v_is_edge_right THEN
              v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta / 2, 'qty', 1, 'total', v_deductor.ddelta / 2, 'note', '½ intermedio');
              v_p_total_ded := v_p_total_ded + (v_deductor.ddelta / 2);
            ELSE
              v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta / 2, 'qty', 2, 'total', v_deductor.ddelta, 'note', '½ izq + ½ der');
              v_p_total_ded := v_p_total_ded + v_deductor.ddelta;
            END IF;
          ELSIF v_deductor.dmode = 'info' THEN
            -- informational: never affects the cut.
            v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta, 'qty', v_deductor.dqty, 'total', 0, 'mode', 'info');
          ELSIF v_deductor.dpos = 'drive_side' THEN
            IF v_drive_side = 'both' THEN
              IF v_is_edge_left OR v_is_edge_right THEN
                v_amt := v_deductor.dtotal / 2;
                v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta, 'qty', 1, 'total', v_amt);
                v_p_total_ded := v_p_total_ded + v_amt;
              END IF;
            ELSIF (v_drive_side = 'left' AND v_is_edge_left) OR (v_drive_side = 'right' AND v_is_edge_right) THEN
              v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta, 'qty', v_deductor.dqty, 'total', v_deductor.dtotal);
              v_p_total_ded := v_p_total_ded + v_deductor.dtotal;
            END IF;
          ELSIF v_deductor.dpos = 'passive_side' THEN
            IF (v_drive_side = 'left' AND v_is_edge_right) OR (v_drive_side = 'right' AND v_is_edge_left) THEN
              v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta, 'qty', v_deductor.dqty, 'total', v_deductor.dtotal);
              v_p_total_ded := v_p_total_ded + v_deductor.dtotal;
            END IF;
          ELSIF v_deductor.dpos = 'per_panel' THEN
            v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta, 'qty', v_deductor.dqty, 'total', v_deductor.ddelta * v_deductor.dqty);
            v_p_total_ded := v_p_total_ded + (v_deductor.ddelta * v_deductor.dqty);
          ELSE
            -- edge / both-ends: split the global contribution across the two outer panels
            -- so SUM(panel deductions) == global total for this deductor.
            IF v_is_edge_left OR v_is_edge_right THEN
              v_amt := v_deductor.dtotal / 2;
              v_p_deds := v_p_deds || jsonb_build_object('role', v_deductor.drole, 'sku', v_deductor.dsku, 'delta', v_deductor.ddelta, 'qty', 1, 'total', v_amt);
              v_p_total_ded := v_p_total_ded + v_amt;
            END IF;
          END IF;
        END LOOP;

        v_p_cut := GREATEST(0, v_p_width + v_tolerance - v_p_total_ded);
        v_panel_cuts := v_panel_cuts || jsonb_build_object('panel', v_p_idx, 'base_mm', v_p_width, 'cut_mm', v_p_cut, 'deduction', GREATEST(0, v_p_width - v_p_cut), 'calc_ded', v_p_total_ded, 'position', v_p_pos, 'deductions', v_p_deds);
        v_panel_cuts_map := jsonb_set(v_panel_cuts_map, ARRAY[v_role], COALESCE(v_panel_cuts_map -> v_role, '[]'::jsonb) || to_jsonb(v_p_cut), true);
      END LOOP;

      -- For a per-panel cuttable the physical total is the sum of the individual panel
      -- cuts (you cut N pieces). Define the summary resolved_mm / total_deduction from
      -- the panels so the invariant SUM(panel_cuts) === resolved_mm holds by construction,
      -- and dependents (depends_on) inherit the correct total as their base.
      v_resolved_mm := (SELECT COALESCE(SUM((pc->>'cut_mm')::numeric), v_resolved_mm) FROM jsonb_array_elements(v_panel_cuts) pc);
      v_total_ded := GREATEST(0, v_base_mm + v_tolerance - v_resolved_mm);
      v_resolved_map := v_resolved_map || jsonb_build_object(v_role, v_resolved_mm);
    END IF;

    v_result := v_result || jsonb_build_object(
      'role', v_role, 'label', INITCAP(REPLACE(v_role, '_', ' ')),
      'sku', COALESCE(v_cuttable.cuttable_sku, '?'),
      'axis', v_axis, 'base_label', v_base_label, 'base_mm', v_base_mm,
      'tolerance_mm', v_tolerance, 'deductions', v_deductions,
      'total_deduction', v_total_ded, 'resolved_mm', v_resolved_mm,
      'instance_cut_mm', NULL, 'match', true,
      'per_panel', v_cuttable.per_panel, 'panel_count', v_panel_count,
      'panel_cuts', v_panel_cuts, 'qty_type', v_cuttable.qty_type,
      'qty_value', v_cuttable.qty_value
    );
  END LOOP;

  RETURN v_result;
END;
$function$;
