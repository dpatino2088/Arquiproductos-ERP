-- compute_instance_cut_breakdown v7: single-panel intermediate guard.
-- Intermediates are SKIPPED when panel_count <= 1 (N-1 rule: 1 panel = 0 intermediates).
-- Intermediates are ALWAYS shared 50/50 between adjacent panels (multi-panel only).
-- Edge components (bracket, drive, end_plug) only affect edge panels.
-- Per-panel components (end_cap with per_panel=true) apply to EVERY panel.
-- Conditional deductions are SKIPPED if config_snapshot doesn't match condition_key/value.
-- Optional cuttables (side_channel, bottom_channel, headbox) are SKIPPED if item_id = 'NONE'.

CREATE OR REPLACE FUNCTION public.compute_instance_cut_breakdown(
  p_bom_instance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_org_id       uuid;
  v_template_id  uuid;
  v_sol_id       uuid;
  v_width_mm     numeric;
  v_height_mm    numeric;
  v_product_type text;
  v_cp_id        uuid;
  v_dim_outputs  jsonb;
  v_config_snap  jsonb;
  v_panels       jsonb;
  v_panel_count  int := 1;

  v_cuttable     RECORD;
  v_deductor     RECORD;
  v_child_ded    RECORD;
  v_result       jsonb := '[]'::jsonb;
  v_deductions   jsonb;
  v_role         text;
  v_axis         text;
  v_base_label   text;
  v_base_mm      numeric;
  v_tolerance    numeric;
  v_total_ded    numeric;
  v_resolved_mm  numeric;
  v_parent_uuid  uuid;
  v_children_sum numeric;
  v_combined_d   numeric;

  v_resolved_map jsonb := '{}'::jsonb;
  v_inst_cut     numeric;

  -- per-panel
  v_panel_cuts   jsonb;
  v_p_rec        RECORD;
  v_p_width      numeric;
  v_p_idx        int;
  v_p_pos        text;
  v_p_deds       jsonb;
  v_p_total_ded  numeric;
  v_is_edge_left boolean;
  v_is_edge_right boolean;
  v_is_intermediate boolean;

  -- fabric
  v_fab          RECORD;
  v_fr           RECORD;
  v_tube_width   numeric;
  v_fab_w        numeric;
  v_fab_h        numeric;
  v_fab_deds     jsonb;
BEGIN
  IF p_bom_instance_id IS NULL THEN RETURN '[]'::jsonb; END IF;

  -- ── 1. Resolve context ────────────────────────────────────────────
  SELECT bi.organization_id, bi.bom_template_id, bi.sales_order_line_id
    INTO v_org_id, v_template_id, v_sol_id
    FROM public."BOMInstances" bi
   WHERE bi.id = p_bom_instance_id;

  IF v_org_id IS NULL THEN RETURN '[]'::jsonb; END IF;

  SELECT sol.width_m, sol.height_m, sol.product_type, sol.configured_product_id
    INTO v_width_mm, v_height_mm, v_product_type, v_cp_id
    FROM public."SaleOrderLines" sol
   WHERE sol.id = v_sol_id;

  v_width_mm  := COALESCE(v_width_mm, 0) * 1000;
  v_height_mm := COALESCE(v_height_mm, 0) * 1000;

  IF v_cp_id IS NOT NULL THEN
    SELECT cp.dimension_outputs, cp.config_snapshot
      INTO v_dim_outputs, v_config_snap
      FROM public."ConfiguredProducts" cp WHERE cp.id = v_cp_id;
  END IF;
  v_dim_outputs := COALESCE(v_dim_outputs, '{}'::jsonb);
  v_config_snap := COALESCE(v_config_snap, '{}'::jsonb);

  v_panels := v_config_snap -> 'panels';
  IF v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' THEN
    v_panel_count := jsonb_array_length(v_panels);
  ELSE
    v_panel_count := 1;
    v_panels := NULL;
  END IF;

  -- ── 2. Iterate cuttable components ────────────────────────────────
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
        ON ci.id = bc.component_item_id AND ci.organization_id = v_org_id
     WHERE bc.bom_template_id = v_template_id
       AND bc.organization_id = v_org_id
       AND bc.deleted = false AND bc.archived = false
       AND bc.parent_component_id IS NULL
       AND COALESCE(ci.measure_basis, '') IN ('linear', 'area')
     ORDER BY bc.sort_order
  LOOP
    v_role      := v_cuttable.component_role;
    v_tolerance := v_cuttable.tolerance;

    -- Skip cuttables not selected in ConfiguredProduct (item_id = "NONE" or boolean = false)
    IF v_config_snap ->> (v_role || '_item_id') = 'NONE' THEN
      CONTINUE;
    END IF;
    IF v_config_snap ->> v_role = 'false' THEN
      CONTINUE;
    END IF;

    IF v_cuttable.cut_axis = 'height'
       OR v_role IN ('side_channel', 'chain', 'belt', 'brush') THEN
      v_axis := 'height';
    ELSE
      v_axis := 'width';
    END IF;

    IF v_cuttable.depends_on_role IS NOT NULL
       AND v_cuttable.depends_on_role != ''
       AND v_resolved_map ? v_cuttable.depends_on_role THEN
      v_base_label := INITCAP(REPLACE(v_cuttable.depends_on_role, '_', ' '));
      v_base_mm    := (v_resolved_map ->> v_cuttable.depends_on_role)::numeric;
    ELSIF v_axis = 'height' THEN
      v_base_label := 'Height';
      v_base_mm    := v_height_mm;
    ELSE
      v_base_label := 'Width';
      v_base_mm    := v_width_mm;
    END IF;

    -- ── Collect all template deductions with position classification ──
    v_deductions := '[]'::jsonb;
    v_total_ded  := 0;

    FOR v_deductor IN
      SELECT bc2.id, bc2.component_role, ci2.sku,
             CASE
               WHEN COALESCE(bc2.delta_mode, 'subtract') = 'add' THEN
                 -(CASE WHEN v_axis = 'height'
                        THEN COALESCE(ci2.delta_y_mm, 0)
                        ELSE COALESCE(ci2.delta_x_mm, 0)
                   END)
               WHEN COALESCE(bc2.delta_mode, 'subtract') = 'info' THEN
                 0
               ELSE
                 CASE WHEN v_axis = 'height'
                      THEN COALESCE(ci2.delta_y_mm, 0)
                      ELSE COALESCE(ci2.delta_x_mm, 0)
                 END
             END AS self_delta,
             COALESCE(bc2.qty_value, 1) AS qty,
             COALESCE(bc2.per_panel, false) AS is_per_panel,
             (bc2.condition_key IS NOT NULL AND bc2.condition_key != '')
               OR COALESCE(bc2.is_required, true) = false AS is_conditional,
             lower(COALESCE(bc2.component_role, '')) LIKE 'intermediate%' AS is_intermediate,
             bc2.condition_key,
             bc2.condition_value,
             COALESCE(bc2.delta_mode, 'subtract') AS delta_mode
        FROM public."BOMComponents" bc2
        LEFT JOIN public."CatalogItems" ci2
          ON ci2.id = bc2.component_item_id AND ci2.organization_id = v_org_id
       WHERE bc2.bom_template_id = v_template_id
         AND bc2.organization_id = v_org_id
         AND bc2.deleted = false AND bc2.archived = false
         AND bc2.parent_component_id IS NULL
         AND v_role = ANY(string_to_array(bc2.affects_role, ','))
         AND COALESCE(bc2.delta_mode, 'subtract') IN ('subtract', 'add', 'info')
       ORDER BY bc2.sort_order
    LOOP
      -- Skip conditional deductions that don't match config_snapshot
      IF v_deductor.condition_key IS NOT NULL AND v_deductor.condition_key != '' THEN
        IF COALESCE(v_config_snap ->> v_deductor.condition_key, '') != v_deductor.condition_value THEN
          CONTINUE;
        END IF;
      END IF;

      -- Skip deductions whose item_id is "NONE" in config (optional not selected)
      IF v_config_snap ->> (v_deductor.component_role || '_item_id') = 'NONE' THEN
        CONTINUE;
      END IF;

      -- N-1 rule: intermediates only exist between panels; 1 panel = 0 intermediates
      IF v_deductor.is_intermediate AND v_panel_count <= 1 THEN
        CONTINUE;
      END IF;

      SELECT COALESCE(SUM(
        CASE WHEN COALESCE(bc_ch.delta_mode, 'subtract') = 'add'
          THEN -(CASE WHEN v_axis = 'height'
                      THEN COALESCE(ci_ch.delta_y_mm, 0)
                      ELSE COALESCE(ci_ch.delta_x_mm, 0)
                 END) * COALESCE(bc_ch.qty_value, 1)
          WHEN COALESCE(bc_ch.delta_mode, 'subtract') = 'info'
          THEN 0
          ELSE (CASE WHEN v_axis = 'height'
                     THEN COALESCE(ci_ch.delta_y_mm, 0)
                     ELSE COALESCE(ci_ch.delta_x_mm, 0)
                END) * COALESCE(bc_ch.qty_value, 1)
        END
      ), 0)
        INTO v_children_sum
        FROM public."BOMComponents" bc_ch
        LEFT JOIN public."CatalogItems" ci_ch
          ON ci_ch.id = bc_ch.component_item_id AND ci_ch.organization_id = v_org_id
       WHERE bc_ch.parent_component_id = v_deductor.id
         AND bc_ch.organization_id = v_org_id
         AND bc_ch.deleted = false AND bc_ch.archived = false
         AND COALESCE(bc_ch.delta_mode, 'subtract') IN ('subtract', 'add', 'info')
         AND v_role = ANY(string_to_array(bc_ch.affects_role, ','));

      v_combined_d := v_deductor.self_delta + v_children_sum;

      IF v_combined_d != 0 OR v_deductor.delta_mode = 'info' THEN
        v_deductions := v_deductions || jsonb_build_object(
          'role',          v_deductor.component_role,
          'sku',           COALESCE(v_deductor.sku, '?'),
          'delta',         v_combined_d,
          'qty',           v_deductor.qty,
          'total',         v_combined_d * v_deductor.qty,
          'mode',          v_deductor.delta_mode,
          'affects_cut',   (v_deductor.delta_mode != 'info'),
          'conditional',   v_deductor.is_conditional,
          'intermediate',  v_deductor.is_intermediate,
          'position',      CASE
                             WHEN v_deductor.is_intermediate THEN 'shared'
                             WHEN v_deductor.is_per_panel THEN 'per_panel'
                             WHEN v_deductor.component_role IN ('drive', 'motor', 'chain_drive') THEN 'drive_side'
                             WHEN v_deductor.component_role = 'end_plug' THEN 'passive_side'
                             ELSE 'edge'
                           END
        );
        IF v_deductor.delta_mode != 'info' THEN
          v_total_ded := v_total_ded + (v_combined_d * v_deductor.qty);
        END IF;
      END IF;
    END LOOP;

    -- own-child deductions (e.g., end_plug is child of tube, end_cap is child of bottom_bar)
    v_parent_uuid := v_cuttable.id;
    FOR v_child_ded IN
      SELECT bc3.component_role, ci3.sku,
             CASE
               WHEN COALESCE(bc3.delta_mode, 'subtract') = 'add' THEN
                 -(CASE WHEN v_axis = 'height'
                        THEN COALESCE(ci3.delta_y_mm, 0)
                        ELSE COALESCE(ci3.delta_x_mm, 0)
                   END)
               WHEN COALESCE(bc3.delta_mode, 'subtract') = 'info' THEN
                 0
               ELSE
                 CASE WHEN v_axis = 'height'
                      THEN COALESCE(ci3.delta_y_mm, 0)
                      ELSE COALESCE(ci3.delta_x_mm, 0)
                 END
             END AS delta,
             COALESCE(bc3.qty_value, 1) AS qty,
             COALESCE(bc3.per_panel, false) AS is_per_panel,
             lower(COALESCE(bc3.component_role, '')) LIKE 'intermediate%' AS is_intermediate,
             bc3.condition_key,
             bc3.condition_value,
             COALESCE(bc3.delta_mode, 'subtract') AS delta_mode
        FROM public."BOMComponents" bc3
        LEFT JOIN public."CatalogItems" ci3
          ON ci3.id = bc3.component_item_id AND ci3.organization_id = v_org_id
       WHERE bc3.parent_component_id = v_parent_uuid
         AND bc3.organization_id = v_org_id
         AND bc3.deleted = false AND bc3.archived = false
         AND COALESCE(bc3.delta_mode, 'subtract') IN ('subtract', 'add', 'info')
       ORDER BY bc3.sort_order
    LOOP
      -- Skip conditional child deductions that don't match config_snapshot
      IF v_child_ded.condition_key IS NOT NULL AND v_child_ded.condition_key != '' THEN
        IF COALESCE(v_config_snap ->> v_child_ded.condition_key, '') != v_child_ded.condition_value THEN
          CONTINUE;
        END IF;
      END IF;

      -- N-1 rule: intermediates only exist between panels; 1 panel = 0 intermediates
      IF v_child_ded.is_intermediate AND v_panel_count <= 1 THEN
        CONTINUE;
      END IF;

      IF v_child_ded.delta != 0 OR v_child_ded.delta_mode = 'info' THEN
        v_deductions := v_deductions || jsonb_build_object(
          'role',          v_child_ded.component_role,
          'sku',           COALESCE(v_child_ded.sku, '?'),
          'delta',         v_child_ded.delta,
          'qty',           v_child_ded.qty,
          'total',         v_child_ded.delta * v_child_ded.qty,
          'mode',          v_child_ded.delta_mode,
          'affects_cut',   (v_child_ded.delta_mode != 'info'),
          'conditional',   false,
          'intermediate',  v_child_ded.is_intermediate,
          'position',      CASE
                             WHEN v_child_ded.is_intermediate THEN 'shared'
                             WHEN v_child_ded.is_per_panel THEN 'per_panel'
                             WHEN v_child_ded.component_role = 'end_plug' THEN 'passive_side'
                             ELSE 'edge'
                           END
        );
        IF v_child_ded.delta_mode != 'info' THEN
          v_total_ded := v_total_ded + (v_child_ded.delta * v_child_ded.qty);
        END IF;
      END IF;
    END LOOP;

    v_resolved_mm := GREATEST(0, v_base_mm + v_tolerance - v_total_ded);

    -- ── Per-panel: build deduction detail per panel based on position ──
    v_panel_cuts := '[]'::jsonb;
    IF v_cuttable.per_panel AND v_panel_count > 1 THEN
      FOR v_p_rec IN
        SELECT bil.panel_index, bil.cut_length_mm, bil.cut_height_mm
          FROM public."BOMInstanceLines" bil
         WHERE bil.bom_instance_id = p_bom_instance_id
           AND bil.part_role = v_role
           AND bil.panel_index IS NOT NULL
         ORDER BY bil.panel_index
      LOOP
        v_p_idx := v_p_rec.panel_index;
        v_is_edge_left  := (v_p_idx = 1);
        v_is_edge_right := (v_p_idx = v_panel_count);

        -- panel base width
        v_p_width := v_width_mm;
        IF v_panels IS NOT NULL AND v_p_idx <= v_panel_count THEN
          v_p_width := COALESCE(
            ((v_panels -> (v_p_idx - 1)) ->> 'width_mm')::numeric,
            v_width_mm / v_panel_count
          );
        END IF;
        IF v_axis = 'height' THEN v_p_width := v_height_mm; END IF;

        v_p_pos := CASE
          WHEN v_is_edge_left THEN 'left'
          WHEN v_is_edge_right THEN 'right'
          ELSE 'center'
        END;

        -- Build per-panel deduction list
        v_p_deds := '[]'::jsonb;
        v_p_total_ded := 0;

        FOR v_deductor IN
          SELECT d->>'role' AS drole, d->>'sku' AS dsku,
                 (d->>'delta')::numeric AS ddelta,
                 (d->>'qty')::numeric AS dqty,
                 COALESCE(d->>'mode', 'subtract') AS dmode,
                 (d->>'conditional')::boolean AS dcond,
                 (d->>'intermediate')::boolean AS dinter,
                 d->>'position' AS dpos
            FROM jsonb_array_elements(v_deductions) AS d
        LOOP
          -- Determine if this deduction applies to this panel
          IF v_deductor.dinter THEN
            -- Intermediate: shared ½ per adjacent panel
            -- Left edge panel: gets ½ intermediate on its right side
            -- Right edge panel: gets ½ intermediate on its left side
            -- Center panel: gets ½ intermediate on left + ½ intermediate on right = 1 full
            IF v_is_edge_left OR v_is_edge_right THEN
              v_p_deds := v_p_deds || jsonb_build_object(
                'role', v_deductor.drole, 'sku', v_deductor.dsku,
                'delta', v_deductor.ddelta / 2,
                'qty', 1, 'total', v_deductor.ddelta / 2,
                'note', '½ intermedio'
              );
              v_p_total_ded := v_p_total_ded + (v_deductor.ddelta / 2);
            ELSE
              -- center panel: ½ left + ½ right = 1 full intermediate
              v_p_deds := v_p_deds || jsonb_build_object(
                'role', v_deductor.drole, 'sku', v_deductor.dsku,
                'delta', v_deductor.ddelta / 2,
                'qty', 2, 'total', v_deductor.ddelta,
                'note', '½ izq + ½ der'
              );
              v_p_total_ded := v_p_total_ded + v_deductor.ddelta;
            END IF;
          ELSIF v_deductor.dpos = 'drive_side' THEN
            -- Drive only applies to edge panels (typically left or right)
            -- Apply to both edge panels since the tube needs clearance on both ends
            IF v_is_edge_left OR v_is_edge_right THEN
              v_p_deds := v_p_deds || jsonb_build_object(
                'role', v_deductor.drole, 'sku', v_deductor.dsku,
                'delta', v_deductor.ddelta,
                'qty', 1, 'total', v_deductor.ddelta,
                'note', CASE WHEN v_is_edge_left THEN 'lado activo' ELSE 'lado pasivo' END
              );
              v_p_total_ded := v_p_total_ded + v_deductor.ddelta;
            END IF;
          ELSIF v_deductor.dpos = 'passive_side' THEN
            -- End plug only on the passive edge panel
            IF v_is_edge_left OR v_is_edge_right THEN
              v_p_deds := v_p_deds || jsonb_build_object(
                'role', v_deductor.drole, 'sku', v_deductor.dsku,
                'delta', v_deductor.ddelta,
                'qty', 1, 'total', v_deductor.ddelta,
                'note', 'lado pasivo'
              );
              v_p_total_ded := v_p_total_ded + v_deductor.ddelta;
            END IF;
          ELSIF v_deductor.dpos = 'per_panel' THEN
            -- Per-panel components (e.g., end_cap): apply to ALL panels with full qty
            v_p_deds := v_p_deds || jsonb_build_object(
              'role', v_deductor.drole, 'sku', v_deductor.dsku,
              'delta', v_deductor.ddelta,
              'qty', v_deductor.dqty,
              'total', CASE WHEN v_deductor.dmode = 'info' THEN 0 ELSE v_deductor.ddelta * v_deductor.dqty END,
              'mode', v_deductor.dmode,
              'note', CASE
                        WHEN v_deductor.dmode = 'info' THEN 'info • x' || v_deductor.dqty::int || ' por paño'
                        ELSE 'x' || v_deductor.dqty::int || ' por paño'
                      END
            );
            IF v_deductor.dmode != 'info' THEN
              v_p_total_ded := v_p_total_ded + (v_deductor.ddelta * v_deductor.dqty);
            END IF;
          ELSIF v_deductor.dpos = 'edge' THEN
            -- Edge components (brackets): 1 per edge panel
            IF v_is_edge_left OR v_is_edge_right THEN
              v_p_deds := v_p_deds || jsonb_build_object(
                'role', v_deductor.drole, 'sku', v_deductor.dsku,
                'delta', v_deductor.ddelta,
                'qty', 1, 'total', v_deductor.ddelta,
                'note', CASE WHEN v_is_edge_left THEN 'bracket izq' ELSE 'bracket der' END
              );
              v_p_total_ded := v_p_total_ded + v_deductor.ddelta;
            END IF;
          END IF;
        END LOOP;

        v_panel_cuts := v_panel_cuts || jsonb_build_object(
          'panel',      v_p_idx,
          'base_mm',    v_p_width,
          'cut_mm',     v_p_rec.cut_length_mm,
          'deduction',  COALESCE(v_p_width - v_p_rec.cut_length_mm, 0),
          'calc_ded',   v_p_total_ded,
          'position',   v_p_pos,
          'deductions',  v_p_deds
        );
      END LOOP;
    END IF;

    -- single panel or non-per_panel: instance cut for verification
    v_inst_cut := NULL;
    IF v_panel_count = 1 OR NOT v_cuttable.per_panel THEN
      SELECT bil.cut_length_mm INTO v_inst_cut
        FROM public."BOMInstanceLines" bil
       WHERE bil.bom_instance_id = p_bom_instance_id
         AND bil.part_role = v_role
         AND (bil.panel_index IS NULL OR bil.panel_index = 0)
       LIMIT 1;
      IF v_inst_cut IS NULL THEN
        SELECT bil.cut_length_mm INTO v_inst_cut
          FROM public."BOMInstanceLines" bil
         WHERE bil.bom_instance_id = p_bom_instance_id
           AND bil.part_role = v_role
         ORDER BY bil.panel_index NULLS FIRST
         LIMIT 1;
      END IF;
    END IF;

    v_resolved_map := v_resolved_map || jsonb_build_object(v_role, v_resolved_mm);

    v_result := v_result || jsonb_build_object(
      'role',            v_role,
      'label',           INITCAP(REPLACE(v_role, '_', ' ')),
      'sku',             COALESCE(v_cuttable.cuttable_sku, '?'),
      'axis',            v_axis,
      'base_label',      v_base_label,
      'base_mm',         v_base_mm,
      'tolerance_mm',    v_tolerance,
      'deductions',      v_deductions,
      'total_deduction', v_total_ded,
      'resolved_mm',     v_resolved_mm,
      'instance_cut_mm', v_inst_cut,
      'match',           CASE WHEN v_panel_count > 1 AND v_cuttable.per_panel
                               THEN jsonb_array_length(v_panel_cuts) = v_panel_count
                               ELSE v_inst_cut IS NOT NULL AND ABS(v_inst_cut - v_resolved_mm) < 1
                          END,
      'per_panel',       v_cuttable.per_panel,
      'panel_count',     v_panel_count,
      'panel_cuts',      v_panel_cuts,
      'qty_type',        v_cuttable.qty_type,
      'qty_value',       v_cuttable.qty_value
    );
  END LOOP;

  -- ── 3. Fabric breakdown ───────────────────────────────────────────
  v_fab := NULL;
  SELECT bil.cut_length_mm, bil.cut_height_mm, ci.sku AS fab_sku
    INTO v_fab
    FROM public."BOMInstanceLines" bil
    LEFT JOIN public."CatalogItems" ci ON ci.id = bil.catalog_item_id
   WHERE bil.bom_instance_id = p_bom_instance_id
     AND bil.part_role = 'fabric'
   ORDER BY bil.panel_index NULLS FIRST
   LIMIT 1;

  IF v_fab.fab_sku IS NOT NULL OR v_fab.cut_length_mm IS NOT NULL THEN
    v_fr := NULL;
    BEGIN
      SELECT fr.* INTO v_fr
        FROM public."FabricRules" fr
       WHERE fr.organization_id = v_org_id
         AND fr.product_type_id = (
               SELECT pt.id FROM public."ProductTypes" pt
                WHERE pt.organization_id = v_org_id
                  AND lower(pt.name) = lower(COALESCE(v_product_type, ''))
                LIMIT 1
             )
         AND fr.is_active = true
       LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_fr := NULL;
    END;

    v_fab_deds := '[]'::jsonb;
    v_tube_width := COALESCE(
      (v_dim_outputs ->> 'tube_width_mm')::numeric,
      (v_resolved_map ->> 'tube')::numeric,
      v_width_mm
    );

    IF v_fr IS NOT NULL THEN
      IF COALESCE(v_fr.fabric_width_source, 'finished_width') = 'tube_width' THEN
        v_fab_w := v_tube_width;
        v_fab_deds := v_fab_deds || jsonb_build_object(
          'role', 'width_source', 'label', 'Ancho = Tubo resuelto',
          'delta', v_tube_width, 'qty', 1, 'total', v_tube_width, 'conditional', false
        );
      ELSIF v_fr.fabric_width_source = 'finished_width_x_fullness' THEN
        v_fab_w := v_width_mm * COALESCE(v_fr.fullness_factor, 1);
        v_fab_deds := v_fab_deds || jsonb_build_object(
          'role', 'width_source', 'label',
          'Ancho = ' || v_width_mm || ' x ' || COALESCE(v_fr.fullness_factor, 1) || ' fullness',
          'delta', v_fab_w, 'qty', 1, 'total', v_fab_w, 'conditional', false
        );
      ELSE
        v_fab_w := v_width_mm;
      END IF;

      v_fab_h := v_height_mm * COALESCE(v_fr.panel_multiplier, 1);
      IF COALESCE(v_fr.panel_multiplier, 1) != 1 THEN
        v_fab_deds := v_fab_deds || jsonb_build_object(
          'role', 'panel_multiplier', 'label',
          'Alto x ' || v_fr.panel_multiplier || ' (panel multiplier)',
          'delta', v_fab_h, 'qty', 1, 'total', v_fab_h, 'conditional', false
        );
      END IF;

      IF COALESCE(v_fr.tube_wrap_mm, 0) > 0 THEN
        v_fab_h := v_fab_h + v_fr.tube_wrap_mm;
        v_fab_deds := v_fab_deds || jsonb_build_object(
          'role', 'tube_wrap', 'label', '+ Envolvente tubo',
          'delta', v_fr.tube_wrap_mm, 'qty', 1, 'total', v_fr.tube_wrap_mm, 'conditional', false
        );
      END IF;

      IF COALESCE(v_fr.bottom_wrap_mm, 0) > 0 THEN
        v_fab_h := v_fab_h + v_fr.bottom_wrap_mm;
        v_fab_deds := v_fab_deds || jsonb_build_object(
          'role', 'bottom_wrap', 'label', '+ Envolvente barra',
          'delta', v_fr.bottom_wrap_mm, 'qty', 1, 'total', v_fr.bottom_wrap_mm, 'conditional', false
        );
      END IF;

      IF COALESCE(v_fr.safety_margin_mm, 0) > 0 THEN
        v_fab_h := v_fab_h + v_fr.safety_margin_mm;
        v_fab_deds := v_fab_deds || jsonb_build_object(
          'role', 'safety_margin', 'label', '+ Margen seguridad',
          'delta', v_fr.safety_margin_mm, 'qty', 1, 'total', v_fr.safety_margin_mm, 'conditional', false
        );
      END IF;

      v_fab_h := ROUND(v_fab_h, 1);
    ELSE
      v_fab_w := COALESCE(v_fab.cut_length_mm, v_width_mm);
      v_fab_h := COALESCE(v_fab.cut_height_mm, v_height_mm);
    END IF;

    -- Per-panel fabric from instance lines
    v_panel_cuts := '[]'::jsonb;
    IF v_panel_count > 1 THEN
      FOR v_p_rec IN
        SELECT bil.panel_index, bil.cut_length_mm, bil.cut_height_mm
          FROM public."BOMInstanceLines" bil
         WHERE bil.bom_instance_id = p_bom_instance_id
           AND bil.part_role = 'fabric'
           AND bil.panel_index IS NOT NULL
         ORDER BY bil.panel_index
      LOOP
        v_p_width := v_width_mm;
        IF v_panels IS NOT NULL AND v_p_rec.panel_index <= v_panel_count THEN
          v_p_width := COALESCE(
            ((v_panels -> (v_p_rec.panel_index - 1)) ->> 'width_mm')::numeric,
            v_width_mm / v_panel_count
          );
        END IF;

        v_panel_cuts := v_panel_cuts || jsonb_build_object(
          'panel',      v_p_rec.panel_index,
          'base_mm',    v_p_width,
          'cut_mm',     v_p_rec.cut_length_mm,
          'cut_height', v_p_rec.cut_height_mm,
          'deduction',  COALESCE(v_p_width - v_p_rec.cut_length_mm, 0),
          'position',   CASE
                          WHEN v_p_rec.panel_index = 1 THEN 'left'
                          WHEN v_p_rec.panel_index = v_panel_count THEN 'right'
                          ELSE 'center'
                        END
        );
      END LOOP;
    END IF;

    v_result := v_result || jsonb_build_object(
      'role',                   'fabric',
      'label',                  'Tela',
      'sku',                    COALESCE(v_fab.fab_sku, '?'),
      'axis',                   'special',
      'base_label',             'Alto',
      'base_mm',                v_height_mm,
      'tolerance_mm',           0,
      'deductions',             v_fab_deds,
      'total_deduction',        0,
      'resolved_mm',            v_fab_w,
      'resolved_height_mm',     v_fab_h,
      'instance_cut_mm',        v_fab.cut_length_mm,
      'instance_cut_height_mm', v_fab.cut_height_mm,
      'match',                  true,
      'per_panel',              (v_panel_count > 1),
      'panel_count',            v_panel_count,
      'panel_cuts',             v_panel_cuts,
      'qty_type',               'area',
      'qty_value',              1,
      'fabric_width_mm',        v_fab_w,
      'fabric_width_source',    COALESCE(v_fr.fabric_width_source, 'finished_width')
    );
  END IF;

  RETURN v_result;
END;
$$;
