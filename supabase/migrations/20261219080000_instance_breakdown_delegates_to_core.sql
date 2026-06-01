-- Phase 4: compute_instance_cut_breakdown delegates geometry/deductions to
-- compute_cut_breakdown_core (single source of truth). It no longer re-derives
-- its own deduction cascade (which had the motor_item_id UUID-vs-SKU bug and a
-- divergent position model). Actual cuts are overlaid from BOMInstanceLines so
-- the work-order display reflects real production geometry. The fabric block is
-- preserved verbatim (FabricRules-driven) and now reads the core-resolved tube
-- width as its base.

CREATE OR REPLACE FUNCTION public.compute_instance_cut_breakdown(p_bom_instance_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $fn$
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

  v_core         jsonb;
  v_elem         jsonb;
  v_result       jsonb := '[]'::jsonb;
  v_role         text;
  v_per_panel    boolean;
  v_resolved_mm  numeric;
  v_resolved_map jsonb := '{}'::jsonb;
  v_inst_cut     numeric;
  v_panel_cuts   jsonb;
  v_new_pcs      jsonb;
  v_pc           jsonb;
  v_pidx         int;
  v_actual       numeric;
  v_match        boolean;

  v_fab          RECORD;
  v_fr           RECORD;
  v_tube_width   numeric;
  v_fab_w        numeric;
  v_fab_h        numeric;
  v_fab_deds     jsonb;
  v_p_rec        RECORD;
  v_p_width      numeric;
BEGIN
  IF p_bom_instance_id IS NULL THEN RETURN '[]'::jsonb; END IF;

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

  v_panels := COALESCE(v_config_snap -> 'panels', v_config_snap -> 'measurements' -> 'panels');
  IF v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' AND jsonb_array_length(v_panels) > 0 THEN
    v_panel_count := jsonb_array_length(v_panels);
  ELSE
    v_panel_count := 1;
    v_panels := NULL;
  END IF;

  -- ============================================================
  -- SINGLE SOURCE OF TRUTH: delegate cut geometry to the core
  -- ============================================================
  v_core := public.compute_cut_breakdown_core(
              v_org_id,
              v_template_id,
              v_config_snap,
              NULLIF(v_width_mm, 0),
              NULLIF(v_height_mm, 0),
              v_panel_count);

  IF v_core IS NULL OR jsonb_typeof(v_core) <> 'array' THEN
    v_core := '[]'::jsonb;
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(v_core) LOOP
    v_role        := v_elem->>'role';
    v_per_panel   := COALESCE((v_elem->>'per_panel')::boolean, false);
    v_resolved_mm := COALESCE((v_elem->>'resolved_mm')::numeric, 0);
    v_resolved_map := v_resolved_map || jsonb_build_object(v_role, v_resolved_mm);

    -- overlay actual single-line cut from the produced instance lines
    v_inst_cut := NULL;
    IF v_panel_count = 1 OR NOT v_per_panel THEN
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

    -- overlay actual per-panel cuts onto the core panel_cuts (keep core's
    -- per-panel deduction explanation; replace cut_mm/deduction with reality)
    v_panel_cuts := COALESCE(v_elem->'panel_cuts', '[]'::jsonb);
    IF v_per_panel AND v_panel_count > 1 AND jsonb_array_length(v_panel_cuts) > 0 THEN
      v_new_pcs := '[]'::jsonb;
      FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) LOOP
        v_pidx := (v_pc->>'panel')::int;
        SELECT bil.cut_length_mm INTO v_actual
          FROM public."BOMInstanceLines" bil
         WHERE bil.bom_instance_id = p_bom_instance_id
           AND bil.part_role = v_role
           AND bil.panel_index = v_pidx
         LIMIT 1;
        IF v_actual IS NOT NULL THEN
          v_pc := jsonb_set(v_pc, '{cut_mm}', to_jsonb(v_actual));
          v_pc := jsonb_set(v_pc, '{deduction}',
                    to_jsonb(COALESCE((v_pc->>'base_mm')::numeric, 0) - v_actual));
        END IF;
        v_new_pcs := v_new_pcs || v_pc;
      END LOOP;
      v_panel_cuts := v_new_pcs;
    END IF;

    -- match against produced reality
    IF v_panel_count > 1 AND v_per_panel THEN
      v_match := jsonb_array_length(v_panel_cuts) = v_panel_count;
    ELSE
      v_match := v_inst_cut IS NOT NULL AND ABS(v_inst_cut - v_resolved_mm) < 1;
    END IF;

    v_result := v_result || (
      v_elem
      || jsonb_build_object(
           'instance_cut_mm', v_inst_cut,
           'match',           v_match,
           'panel_cuts',      v_panel_cuts)
    );
  END LOOP;

  -- ============================================================
  -- FABRIC (FabricRules-driven; base width = core-resolved tube)
  -- ============================================================
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
$fn$;
