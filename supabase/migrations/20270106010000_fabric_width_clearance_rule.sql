-- Fabric width clearance: fabric is cut narrower than its mechanical width
-- source (tube / bottom_bar / track). Configurable per FabricRule.
-- e.g. fabric_width_clearance_mm = 2 => fabric cut width = tube width - 2mm.
-- Applies to Roller / Dual / Triple (formula_code = 'ROLLER_DROPS').
--
-- Fabric stays a GENERIC, rule-driven element in the eBOM: the actual fabric is
-- the one the dealer selects; only its cut geometry is derived from the tube via
-- the FabricRule. The clearance is applied consistently in:
--   1. compute_fabric_pricing_from_rule       (quote/preview snapshot + pricing)
--   2. compute_instance_cut_breakdown          (manufacturing breakdown display)
--   3. generate_bom_for_manufacturing_order    (multi-panel fabric split at MO gen)

SET search_path = public;

ALTER TABLE public."FabricRules"
  ADD COLUMN IF NOT EXISTS fabric_width_clearance_mm numeric NOT NULL DEFAULT 0;

COMMENT ON COLUMN public."FabricRules".fabric_width_clearance_mm IS
  'mm subtracted from the resolved mechanical width source (tube/bottom_bar/track) to get the fabric cut width. e.g. 2 = fabric is cut 2mm narrower than the tube.';

UPDATE public."FabricRules"
SET fabric_width_clearance_mm = 2, updated_at = now()
WHERE formula_code = 'ROLLER_DROPS'
  AND COALESCE(fabric_width_source,'') IN ('tube_width','bottom_bar_width','track_width')
  AND COALESCE(fabric_width_clearance_mm,0) = 0;

-- ---------------------------------------------------------------------------
-- 1) compute_fabric_pricing_from_rule
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_fabric_pricing_from_rule(p_org_id uuid, p_product_type_id uuid, p_style_code text, p_height_m numeric, p_width_m numeric, p_roll_width_m numeric, p_msrp_per_m numeric, p_dimension_outputs jsonb DEFAULT NULL::jsonb, p_can_rotate boolean DEFAULT NULL::boolean, p_is_weldable boolean DEFAULT NULL::boolean, p_bottom_bar_wrapped boolean DEFAULT false, p_bottom_hem_cm numeric DEFAULT NULL::numeric)
 RETURNS TABLE(qty numeric, pricing_uom text, unit_price numeric, area_base_m2 numeric, drops numeric, waste_pct numeric, fabric_cut_width_mm numeric, fabric_cut_height_mm numeric, fabric_width_used_m numeric, panel_detail jsonb, is_rotated boolean, heatseal_seams integer, heatseal_cost numeric, bottom_bar_wrap_cost numeric, heatseal_dir text)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_r RECORD;
    v_heff numeric; v_weff numeric; v_area numeric; v_drops numeric;
    v_qty numeric; v_uom text; v_unit_price numeric;
    v_cut_height numeric; v_cut_width numeric;
    v_fabric_width_needed numeric; v_panels_count numeric;
    v_dim_outputs jsonb; v_fw_source_mm numeric;
    v_has_panel_cuts boolean := false;
    v_panel_cuts jsonb; v_pc jsonb;
    v_panel_tube_mm numeric; v_panel_weff numeric;
    v_panel_area numeric; v_panel_drops numeric;
    v_panel_detail_arr jsonb := '[]'::jsonb;
    v_total_area numeric := 0; v_total_drops numeric := 0; v_total_weff numeric := 0;
    v_rotated boolean := false; v_hs_seams integer := 0;
    v_can_rotate boolean; v_is_weldable boolean; v_hs_dir text;
    v_clear_mm numeric := 0;
BEGIN
    qty := NULL; pricing_uom := NULL; unit_price := NULL;
    area_base_m2 := NULL; drops := NULL; waste_pct := NULL;
    fabric_cut_width_mm := NULL; fabric_cut_height_mm := NULL;
    fabric_width_used_m := NULL; panel_detail := NULL;
    is_rotated := false; heatseal_seams := 0;
    heatseal_cost := 0; bottom_bar_wrap_cost := 0;
    heatseal_dir := 'none';

    SELECT * INTO v_r FROM public.select_fabric_rule(p_org_id, p_product_type_id, p_style_code) LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;

    v_hs_dir := COALESCE(v_r.heatseal_direction, 'none');
    v_can_rotate := COALESCE(p_can_rotate, v_r.allow_rotation, false);
    v_is_weldable := COALESCE(p_is_weldable, v_hs_dir != 'none', false);
    heatseal_dir := v_hs_dir;

    v_dim_outputs := COALESCE(p_dimension_outputs, '{}'::jsonb);
    waste_pct := COALESCE(v_r.waste_pct, 0);

    -- Fabric width clearance: fabric is cut narrower than the mechanical source (tube/bottom_bar/track).
    v_clear_mm := CASE WHEN COALESCE(v_r.fabric_width_source, 'finished_width') IN ('tube_width','bottom_bar_width','track_width')
                       THEN COALESCE(v_r.fabric_width_clearance_mm, 0) ELSE 0 END;

    v_has_panel_cuts := (v_dim_outputs ? 'tube_panel_cuts')
                        AND COALESCE(v_r.fabric_width_source, 'finished_width') = 'tube_width';

    IF COALESCE(v_r.panel_multiplier, 1) > 0 AND (
         COALESCE(v_r.tube_wrap_mm, 0) > 0 OR
         COALESCE(v_r.bottom_wrap_mm, 0) > 0 OR
         COALESCE(v_r.safety_margin_mm, 0) > 0 OR
         COALESCE(v_r.panel_multiplier, 1) != 1
       ) THEN
      v_heff := (COALESCE(p_height_m, 0) * COALESCE(v_r.panel_multiplier, 1))
              + (COALESCE(v_r.tube_wrap_mm, 0) / 1000.0)
              + (COALESCE(v_r.bottom_wrap_mm, 0) / 1000.0)
              + (COALESCE(v_r.safety_margin_mm, 0) / 1000.0);
    ELSE
      v_heff := COALESCE(p_height_m, 0) * COALESCE(v_r.height_multiplier, 1) + COALESCE(v_r.extra_height_m, 0);
    END IF;

    fabric_cut_height_mm := ROUND(v_heff * 1000.0, 1);

    IF v_has_panel_cuts AND COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS' THEN
      v_panel_cuts := v_dim_outputs->'tube_panel_cuts';
      FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
        v_panel_tube_mm := COALESCE((v_pc->>'tube_width_mm')::numeric, 0);
        v_panel_weff := GREATEST(0, v_panel_tube_mm - v_clear_mm) / 1000.0;
        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
          v_panel_area := v_heff * v_panel_weff;
          v_panel_drops := NULL;
        ELSE
          v_panel_drops := CEIL(v_panel_weff / p_roll_width_m);
          v_panel_area := v_heff * v_panel_drops * p_roll_width_m;
        END IF;
        v_total_area := v_total_area + v_panel_area;
        v_total_drops := v_total_drops + COALESCE(v_panel_drops, 1);
        v_total_weff := v_total_weff + v_panel_weff;
        v_panel_detail_arr := v_panel_detail_arr || jsonb_build_object(
          'index', (v_pc->>'index')::integer, 'position', v_pc->>'position',
          'tube_width_mm', v_panel_tube_mm, 'fabric_cut_width_mm', ROUND(GREATEST(0, v_panel_tube_mm - v_clear_mm), 1),
          'drops', v_panel_drops, 'area_m2', ROUND(v_panel_area, 4)
        );
      END LOOP;
      v_area := v_total_area; v_drops := v_total_drops; v_weff := v_total_weff;
      v_fw_source_mm := v_total_weff * 1000.0;
      fabric_cut_width_mm := NULL;
      fabric_width_used_m := ROUND(v_total_weff, 4);
      panel_detail := v_panel_detail_arr;
    ELSE
      CASE COALESCE(v_r.fabric_width_source, 'finished_width')
        WHEN 'tube_width' THEN
          v_fw_source_mm := COALESCE((v_dim_outputs->>'tube_width_mm')::numeric, COALESCE(p_width_m, 0) * 1000.0);
          v_weff := v_fw_source_mm / 1000.0;
        WHEN 'bottom_bar_width' THEN
          v_fw_source_mm := COALESCE((v_dim_outputs->>'bottom_bar_width_mm')::numeric, COALESCE(p_width_m, 0) * 1000.0);
          v_weff := v_fw_source_mm / 1000.0;
        WHEN 'track_width' THEN
          v_fw_source_mm := COALESCE((v_dim_outputs->>'track_width_mm')::numeric, COALESCE(p_width_m, 0) * 1000.0);
          v_weff := v_fw_source_mm / 1000.0;
        WHEN 'finished_width_x_fullness' THEN
          v_weff := COALESCE(p_width_m, 0) * COALESCE(v_r.fullness_factor, 1);
          v_fw_source_mm := v_weff * 1000.0;
        ELSE
          v_weff := COALESCE(p_width_m, 0) * COALESCE(v_r.width_multiplier, 1) + COALESCE(v_r.extra_width_m, 0);
          v_fw_source_mm := v_weff * 1000.0;
      END CASE;

      -- Apply fabric width clearance for mechanical sources (fabric = source - clearance).
      IF v_clear_mm > 0 THEN
        v_fw_source_mm := GREATEST(0, v_fw_source_mm - v_clear_mm);
        v_weff := v_fw_source_mm / 1000.0;
      END IF;

      fabric_cut_width_mm := ROUND(v_fw_source_mm, 1);
      fabric_width_used_m := ROUND(v_weff, 4);

      IF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS'
         AND p_roll_width_m IS NOT NULL AND p_roll_width_m > 0 THEN
          IF v_weff > p_roll_width_m AND v_can_rotate THEN
              v_rotated := true;
              v_drops := CEIL(v_heff / p_roll_width_m);
              v_area := v_drops * v_weff * p_roll_width_m;
              IF v_hs_dir = 'horizontal' AND v_is_weldable AND v_drops > 1 THEN
                  v_hs_seams := v_drops::integer - 1;
              END IF;
          ELSE
              v_drops := CEIL(v_weff / p_roll_width_m);
              v_area := v_heff * v_drops * p_roll_width_m;
              IF v_hs_dir = 'horizontal' AND v_is_weldable AND v_drops > 1 THEN
                  v_hs_seams := v_drops::integer - 1;
              END IF;
          END IF;
      ELSIF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS' THEN
          v_area := v_heff * v_weff; v_drops := NULL;
      ELSIF COALESCE(v_r.formula_code, '') = 'AREA_BASED' THEN
          v_area := v_heff * (v_weff * COALESCE(v_r.fullness_factor, 1)); v_drops := NULL;
      ELSIF COALESCE(v_r.formula_code, '') = 'DRAPERY_PANELS' THEN
          v_cut_height := COALESCE(p_height_m, 0)
                        + COALESCE(v_r.top_hem_cm, 0) / 100.0
                        + COALESCE(p_bottom_hem_cm, 0) / 100.0;
          v_fabric_width_needed := v_weff;
          IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
              v_panels_count := 1;
          ELSE
              v_panels_count := CEIL(v_fabric_width_needed / p_roll_width_m);
          END IF;
          v_drops := v_panels_count;
          v_area := v_panels_count * v_cut_height * COALESCE(p_roll_width_m, v_fabric_width_needed);
          fabric_cut_height_mm := ROUND(v_cut_height * 1000.0, 1);
          IF v_hs_dir = 'vertical' AND v_is_weldable AND v_panels_count > 1 THEN
              v_hs_seams := v_panels_count::integer - 1;
          END IF;
      ELSE
          v_area := v_heff * v_weff; v_drops := NULL;
      END IF;
    END IF;

    area_base_m2 := v_area;
    IF COALESCE(v_r.pricing_output_uom, 'm2') = 'm' THEN
        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
            v_qty := v_area; v_uom := 'm2'; v_unit_price := p_msrp_per_m;
        ELSE
            v_qty := v_area / p_roll_width_m; v_uom := 'm'; v_unit_price := COALESCE(p_msrp_per_m, 0);
        END IF;
    ELSE
        v_qty := v_area; v_uom := 'm2';
        v_unit_price := CASE WHEN p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN COALESCE(p_msrp_per_m, 0)
                             ELSE COALESCE(p_msrp_per_m, 0) / p_roll_width_m END;
    END IF;
    v_qty := v_qty * (1 + waste_pct);
    v_qty := public.round_up_to_increment(v_qty, COALESCE(v_r.round_to_increment, 0));
    IF v_r.min_qty IS NOT NULL AND v_r.min_qty > 0 AND v_qty < v_r.min_qty THEN
        v_qty := v_r.min_qty;
    END IF;

    qty := v_qty; pricing_uom := v_uom; unit_price := v_unit_price;
    drops := v_drops; is_rotated := v_rotated;
    heatseal_seams := v_hs_seams;
    RETURN NEXT;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2) compute_instance_cut_breakdown  (fabric width = tube - clearance, shown as deduction)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_instance_cut_breakdown(p_bom_instance_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_org_id uuid; v_template_id uuid; v_sol_id uuid;
  v_width_mm numeric; v_height_mm numeric; v_product_type text; v_cp_id uuid;
  v_dim_outputs jsonb; v_config_snap jsonb; v_panels jsonb; v_panel_count int := 1;
  v_core jsonb; v_elem jsonb; v_result jsonb := '[]'::jsonb;
  v_role text; v_per_panel boolean; v_resolved_mm numeric; v_resolved_map jsonb := '{}'::jsonb;
  v_inst_cut numeric; v_panel_cuts jsonb; v_new_pcs jsonb; v_pc jsonb; v_pidx int; v_actual numeric; v_match boolean; v_line_cnt int;
  v_fab RECORD; v_fr RECORD; v_tube_width numeric; v_fab_w numeric; v_fab_h numeric; v_fab_deds jsonb; v_p_rec RECORD; v_p_width numeric;
BEGIN
  IF p_bom_instance_id IS NULL THEN RETURN '[]'::jsonb; END IF;
  SELECT bi.organization_id, bi.bom_template_id, bi.sales_order_line_id INTO v_org_id, v_template_id, v_sol_id FROM public."BOMInstances" bi WHERE bi.id = p_bom_instance_id;
  IF v_org_id IS NULL THEN RETURN '[]'::jsonb; END IF;
  SELECT sol.width_m, sol.height_m, sol.product_type, sol.configured_product_id INTO v_width_mm, v_height_mm, v_product_type, v_cp_id FROM public."SaleOrderLines" sol WHERE sol.id = v_sol_id;
  v_width_mm := COALESCE(v_width_mm, 0) * 1000; v_height_mm := COALESCE(v_height_mm, 0) * 1000;
  IF v_cp_id IS NOT NULL THEN SELECT cp.dimension_outputs, cp.config_snapshot INTO v_dim_outputs, v_config_snap FROM public."ConfiguredProducts" cp WHERE cp.id = v_cp_id; END IF;
  v_dim_outputs := COALESCE(v_dim_outputs, '{}'::jsonb); v_config_snap := COALESCE(v_config_snap, '{}'::jsonb);
  v_panels := COALESCE(v_config_snap -> 'panels', v_config_snap -> 'measurements' -> 'panels');
  IF v_panels IS NOT NULL AND jsonb_typeof(v_panels) = 'array' AND jsonb_array_length(v_panels) > 0 THEN v_panel_count := jsonb_array_length(v_panels); ELSE v_panel_count := 1; v_panels := NULL; END IF;

  v_core := public.compute_cut_breakdown_core(v_org_id, v_template_id, v_config_snap, NULLIF(v_width_mm, 0), NULLIF(v_height_mm, 0), v_panel_count);
  IF v_core IS NULL OR jsonb_typeof(v_core) <> 'array' THEN v_core := '[]'::jsonb; END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(v_core) LOOP
    v_role := v_elem->>'role'; v_per_panel := COALESCE((v_elem->>'per_panel')::boolean, false); v_resolved_mm := COALESCE((v_elem->>'resolved_mm')::numeric, 0);

    SELECT count(*) INTO v_line_cnt FROM public."BOMInstanceLines" bil WHERE bil.bom_instance_id = p_bom_instance_id AND bil.part_role = v_role AND COALESCE(bil.deleted,false) = false;
    IF v_line_cnt = 0 THEN CONTINUE; END IF;

    v_resolved_map := v_resolved_map || jsonb_build_object(v_role, v_resolved_mm);

    v_inst_cut := NULL;
    IF v_panel_count = 1 OR NOT v_per_panel THEN
      SELECT bil.cut_length_mm INTO v_inst_cut FROM public."BOMInstanceLines" bil WHERE bil.bom_instance_id = p_bom_instance_id AND bil.part_role = v_role AND COALESCE(bil.deleted,false) = false AND (bil.panel_index IS NULL OR bil.panel_index = 0) LIMIT 1;
      IF v_inst_cut IS NULL THEN SELECT bil.cut_length_mm INTO v_inst_cut FROM public."BOMInstanceLines" bil WHERE bil.bom_instance_id = p_bom_instance_id AND bil.part_role = v_role AND COALESCE(bil.deleted,false) = false ORDER BY bil.panel_index NULLS FIRST LIMIT 1; END IF;
    END IF;

    v_panel_cuts := COALESCE(v_elem->'panel_cuts', '[]'::jsonb);
    IF v_per_panel AND v_panel_count > 1 AND jsonb_array_length(v_panel_cuts) > 0 THEN
      v_new_pcs := '[]'::jsonb;
      FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) LOOP
        v_pidx := (v_pc->>'panel')::int;
        SELECT bil.cut_length_mm INTO v_actual FROM public."BOMInstanceLines" bil WHERE bil.bom_instance_id = p_bom_instance_id AND bil.part_role = v_role AND COALESCE(bil.deleted,false) = false AND bil.panel_index = v_pidx LIMIT 1;
        IF v_actual IS NOT NULL THEN v_pc := jsonb_set(v_pc, '{cut_mm}', to_jsonb(v_actual)); v_pc := jsonb_set(v_pc, '{deduction}', to_jsonb(COALESCE((v_pc->>'base_mm')::numeric, 0) - v_actual)); END IF;
        v_new_pcs := v_new_pcs || v_pc;
      END LOOP;
      v_panel_cuts := v_new_pcs;
    END IF;

    IF v_panel_count > 1 AND v_per_panel THEN
      v_match := jsonb_array_length(v_panel_cuts) = v_panel_count;
    ELSIF v_inst_cut IS NOT NULL AND v_resolved_mm > 0 THEN
      v_match := ABS(v_inst_cut - GREATEST(1, ROUND(v_inst_cut / v_resolved_mm)) * v_resolved_mm) < 1.5;
    ELSE
      v_match := v_inst_cut IS NOT NULL AND ABS(v_inst_cut - v_resolved_mm) < 1;
    END IF;

    v_result := v_result || (v_elem || jsonb_build_object('instance_cut_mm', v_inst_cut, 'match', v_match, 'panel_cuts', v_panel_cuts));
  END LOOP;

  v_fab := NULL;
  SELECT bil.cut_length_mm, bil.cut_height_mm, ci.sku AS fab_sku INTO v_fab FROM public."BOMInstanceLines" bil LEFT JOIN public."CatalogItems" ci ON ci.id = bil.catalog_item_id WHERE bil.bom_instance_id = p_bom_instance_id AND bil.part_role = 'fabric' AND COALESCE(bil.deleted,false) = false ORDER BY bil.panel_index NULLS FIRST LIMIT 1;

  IF v_fab.fab_sku IS NOT NULL OR v_fab.cut_length_mm IS NOT NULL THEN
    v_fr := NULL;
    BEGIN
      SELECT fr.* INTO v_fr FROM public."FabricRules" fr WHERE fr.organization_id = v_org_id AND fr.product_type_id = (SELECT pt.id FROM public."ProductTypes" pt WHERE pt.organization_id = v_org_id AND lower(pt.name) = lower(COALESCE(v_product_type, '')) LIMIT 1) AND fr.is_active = true LIMIT 1;
    EXCEPTION WHEN OTHERS THEN v_fr := NULL; END;
    v_fab_deds := '[]'::jsonb;
    v_tube_width := COALESCE((v_dim_outputs ->> 'tube_width_mm')::numeric, (v_resolved_map ->> 'tube')::numeric, v_width_mm);
    IF v_fr IS NOT NULL THEN
      IF COALESCE(v_fr.fabric_width_source, 'finished_width') = 'tube_width' THEN
        v_fab_w := v_tube_width;
        v_fab_deds := v_fab_deds || jsonb_build_object('role','width_source','label','Ancho = Tubo resuelto','delta',v_tube_width,'qty',1,'total',v_tube_width,'conditional',false);
        IF COALESCE(v_fr.fabric_width_clearance_mm, 0) > 0 THEN
          v_fab_w := GREATEST(0, v_fab_w - v_fr.fabric_width_clearance_mm);
          v_fab_deds := v_fab_deds || jsonb_build_object('role','width_clearance','label','- Holgura tela (Rule)','delta', -v_fr.fabric_width_clearance_mm,'qty',1,'total', -v_fr.fabric_width_clearance_mm,'conditional',false);
        END IF;
      ELSIF v_fr.fabric_width_source = 'finished_width_x_fullness' THEN v_fab_w := v_width_mm * COALESCE(v_fr.fullness_factor, 1); v_fab_deds := v_fab_deds || jsonb_build_object('role','width_source','label','Ancho = ' || v_width_mm || ' x ' || COALESCE(v_fr.fullness_factor, 1) || ' fullness','delta',v_fab_w,'qty',1,'total',v_fab_w,'conditional',false);
      ELSE v_fab_w := v_width_mm; END IF;
      v_fab_h := v_height_mm * COALESCE(v_fr.panel_multiplier, 1);
      IF COALESCE(v_fr.panel_multiplier, 1) != 1 THEN v_fab_deds := v_fab_deds || jsonb_build_object('role','panel_multiplier','label','Alto x ' || v_fr.panel_multiplier || ' (panel multiplier)','delta',v_fab_h,'qty',1,'total',v_fab_h,'conditional',false); END IF;
      IF COALESCE(v_fr.tube_wrap_mm, 0) > 0 THEN v_fab_h := v_fab_h + v_fr.tube_wrap_mm; v_fab_deds := v_fab_deds || jsonb_build_object('role','tube_wrap','label','+ Envolvente tubo','delta',v_fr.tube_wrap_mm,'qty',1,'total',v_fr.tube_wrap_mm,'conditional',false); END IF;
      IF COALESCE(v_fr.bottom_wrap_mm, 0) > 0 THEN v_fab_h := v_fab_h + v_fr.bottom_wrap_mm; v_fab_deds := v_fab_deds || jsonb_build_object('role','bottom_wrap','label','+ Envolvente barra','delta',v_fr.bottom_wrap_mm,'qty',1,'total',v_fr.bottom_wrap_mm,'conditional',false); END IF;
      IF COALESCE(v_fr.safety_margin_mm, 0) > 0 THEN v_fab_h := v_fab_h + v_fr.safety_margin_mm; v_fab_deds := v_fab_deds || jsonb_build_object('role','safety_margin','label','+ Margen seguridad','delta',v_fr.safety_margin_mm,'qty',1,'total',v_fr.safety_margin_mm,'conditional',false); END IF;
      v_fab_h := ROUND(v_fab_h, 1);
    ELSE v_fab_w := COALESCE(v_fab.cut_length_mm, v_width_mm); v_fab_h := COALESCE(v_fab.cut_height_mm, v_height_mm); END IF;
    v_panel_cuts := '[]'::jsonb;
    IF v_panel_count > 1 THEN
      FOR v_p_rec IN SELECT bil.panel_index, bil.cut_length_mm, bil.cut_height_mm FROM public."BOMInstanceLines" bil WHERE bil.bom_instance_id = p_bom_instance_id AND bil.part_role = 'fabric' AND COALESCE(bil.deleted,false) = false AND bil.panel_index IS NOT NULL ORDER BY bil.panel_index
      LOOP
        v_p_width := v_width_mm;
        IF v_panels IS NOT NULL AND v_p_rec.panel_index <= v_panel_count THEN v_p_width := COALESCE(((v_panels -> (v_p_rec.panel_index - 1)) ->> 'width_mm')::numeric, v_width_mm / v_panel_count); END IF;
        v_panel_cuts := v_panel_cuts || jsonb_build_object('panel',v_p_rec.panel_index,'base_mm',v_p_width,'cut_mm',v_p_rec.cut_length_mm,'cut_height',v_p_rec.cut_height_mm,'deduction',COALESCE(v_p_width - v_p_rec.cut_length_mm, 0),'position',CASE WHEN v_p_rec.panel_index = 1 THEN 'left' WHEN v_p_rec.panel_index = v_panel_count THEN 'right' ELSE 'center' END);
      END LOOP;
    END IF;
    v_result := v_result || jsonb_build_object('role','fabric','label','Tela','sku',COALESCE(v_fab.fab_sku, '?'),'axis','special','base_label','Alto','base_mm',v_height_mm,'tolerance_mm',0,'deductions',v_fab_deds,'total_deduction',0,'resolved_mm',v_fab_w,'resolved_height_mm',v_fab_h,'instance_cut_mm',v_fab.cut_length_mm,'instance_cut_height_mm',v_fab.cut_height_mm,'match',true,'per_panel',(v_panel_count > 1),'panel_count',v_panel_count,'panel_cuts',v_panel_cuts,'qty_type','area','qty_value',1,'fabric_width_mm',v_fab_w,'fabric_width_source',COALESCE(v_fr.fabric_width_source, 'finished_width'));
  END IF;

  RETURN v_result;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3) generate_bom_for_manufacturing_order  (multi-panel fabric split - clearance)
--    Changes vs prior version: declare v_fab_clear_mm; look it up from the
--    active FabricRule per SOL; subtract it from each tube_panel_cut when
--    splitting the fabric line into per-panel cuts.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_mo RECORD; v_mo_line RECORD; v_sol RECORD; v_cp RECORD;
    v_bi_id uuid; v_item jsonb; v_child jsonb;
    v_catalog_item_id uuid; v_role text; v_qty numeric; v_uom text;
    v_ucx numeric(12,4); v_tcx numeric(12,4); v_um numeric(12,4); v_tm numeric(12,4);
    v_snapshot jsonb; v_items jsonb; v_totals jsonb; v_fabric_calc jsonb;
    v_dim_outputs jsonb; v_panel_cuts_key text; v_panel_cuts jsonb; v_pc jsonb;
    v_panel_cut_mm numeric; v_panel_idx integer; v_src_line RECORD;
    v_unit_cost_per_m numeric(12,6); v_unit_msrp_per_m numeric(12,6);
    v_fulfillment text;
    v_sum_m numeric; v_recon_tol numeric;
    v_core_mm numeric; v_quoted_cut_mm numeric; v_line_cnt integer;
    v_frozen_cost numeric(14,4); v_frozen_msrp numeric(14,4); v_pc_total_mm numeric; v_pc_count integer; v_pc_seen integer; v_acc_cost numeric(14,4); v_acc_msrp numeric(14,4); v_panel_cost numeric(14,4); v_panel_msrp numeric(14,4); v_weight numeric;
    v_fab_clear_mm numeric := 0;
    v_mlb integer := 0; v_mla integer := 0; v_cml integer := 0; v_mlp integer := 0;
    v_bib integer := 0; v_bia integer := 0; v_blb integer := 0; v_bla integer := 0;
    v_tbi integer := 0; v_tbl integer := 0;
    v_supply_skipped integer := 0; v_recon_skips integer := 0;
    v_warn text[] := ARRAY[]::text[]; v_err text[] := ARRAY[]::text[];
BEGIN
    SELECT * INTO v_mo FROM public."ManufacturingOrders" WHERE id = p_manufacturing_order_id;
    IF v_mo.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO not found'], 'warnings', ARRAY[]::text[]); END IF;
    IF v_mo.deleted = true THEN RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO is deleted'], 'warnings', ARRAY[]::text[]); END IF;
    IF v_mo.sales_order_id IS NULL THEN v_warn := v_warn || 'MO has no sales_order_id'; END IF;

    SELECT COUNT(*) INTO v_mlb FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bib FROM public."BOMInstances" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_blb FROM public."BOMInstanceLines" bil JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    IF v_mo.status IN ('in_production','completed','cancelled','quality_check','ready_for_pickup','delivered') AND v_bib > 0 THEN
        RETURN jsonb_build_object('ok', true, 'skipped', 'mo_frozen', 'manufacturing_order_id', p_manufacturing_order_id, 'status', v_mo.status::text, 'bom_instances_after', v_bib, 'bom_instance_lines_after', v_blb, 'warnings', v_warn || format('MO status %s is frozen; BOM not regenerated', v_mo.status), 'errors', ARRAY[]::text[]);
    END IF;

    IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'draft'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND NOT EXISTS (SELECT 1 FROM public."ManufacturingOrderLines" m2 WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id);
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;

    SELECT COUNT(*) INTO v_mla FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    IF v_mla = 0 THEN
        RETURN jsonb_build_object('ok', true, 'mo_lines_before', v_mlb, 'mo_lines_after', v_mla, 'mo_lines_created', v_cml, 'bom_instances_before', v_bib, 'bom_instances_after', v_bib, 'bom_instances_created', 0, 'bom_instance_lines_before', v_blb, 'bom_instance_lines_after', v_blb, 'bom_instance_lines_created', 0, 'warnings', v_warn, 'errors', v_err);
    END IF;

    FOR v_mo_line IN SELECT mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false ORDER BY mol.created_at ASC
    LOOP
        v_mlp := v_mlp + 1; v_dim_outputs := '{}'::jsonb; v_fab_clear_mm := 0;
        SELECT sol.id, sol.configured_product_id, sol.quote_line_id, sol.product_type, sol.width_m, sol.height_m INTO v_sol FROM public."SaleOrderLines" sol WHERE sol.id = v_mo_line.sales_order_line_id AND sol.deleted = false;
        IF NOT FOUND THEN v_warn := v_warn || format('SaleOrderLine %s not found', v_mo_line.sales_order_line_id); CONTINUE; END IF;
        SELECT COALESCE(pt.fulfillment_type, 'manufacture') INTO v_fulfillment FROM public."ProductTypes" pt WHERE pt.code = v_sol.product_type AND pt.organization_id = v_mo.organization_id LIMIT 1;
        IF v_fulfillment = 'supply_only' THEN v_supply_skipped := v_supply_skipped + 1; CONTINUE; END IF;
        v_snapshot := NULL;
        IF v_sol.configured_product_id IS NOT NULL THEN
            SELECT cp.bom_preview_snapshot, cp.bom_template_id INTO v_cp FROM public."ConfiguredProducts" cp WHERE cp.id = v_sol.configured_product_id AND cp.deleted = false;
            IF FOUND THEN v_snapshot := v_cp.bom_preview_snapshot; END IF;
        END IF;
        IF v_snapshot IS NULL AND v_sol.quote_line_id IS NOT NULL THEN
            SELECT cp.bom_preview_snapshot, cp.bom_template_id INTO v_cp FROM public."QuoteLines" ql JOIN public."ConfiguredProducts" cp ON cp.id = ql.configured_product_id WHERE ql.id = v_sol.quote_line_id AND cp.deleted = false LIMIT 1;
            IF FOUND THEN v_snapshot := v_cp.bom_preview_snapshot; END IF;
        END IF;
        IF v_snapshot IS NULL OR v_snapshot = '{}'::jsonb THEN v_warn := v_warn || format('No bom_preview_snapshot for SOL %s (configured_product_id=%s)', v_sol.id, v_sol.configured_product_id); CONTINUE; END IF;
        IF v_sol.configured_product_id IS NOT NULL THEN
            BEGIN v_dim_outputs := COALESCE(public.compute_system_dimensions(v_sol.configured_product_id), '{}'::jsonb); EXCEPTION WHEN OTHERS THEN v_dim_outputs := '{}'::jsonb; END;
        END IF;
        v_items := v_snapshot->'items'; v_totals := v_snapshot->'totals'; v_fabric_calc := v_totals->'fabric_calc';

        -- Fabric width clearance from the active FabricRule (only for mechanical width sources).
        BEGIN
            SELECT COALESCE(fr.fabric_width_clearance_mm, 0) INTO v_fab_clear_mm
            FROM public."FabricRules" fr
            JOIN public."ProductTypes" pt ON pt.id = fr.product_type_id AND pt.organization_id = fr.organization_id
            WHERE fr.organization_id = v_mo.organization_id
              AND pt.code = v_sol.product_type
              AND fr.is_active = true
              AND COALESCE(fr.fabric_width_source,'') IN ('tube_width','bottom_bar_width','track_width')
            ORDER BY (fr.style_code IS NULL) ASC
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN v_fab_clear_mm := 0; END;
        v_fab_clear_mm := COALESCE(v_fab_clear_mm, 0);

        IF v_items IS NULL OR jsonb_typeof(v_items) != 'array' OR jsonb_array_length(v_items) = 0 THEN v_warn := v_warn || format('Empty snapshot items for SOL %s', v_sol.id); CONTINUE; END IF;
        UPDATE public."BOMInstanceLines" bil SET deleted = true, updated_at = now() WHERE bil.bom_instance_id IN (SELECT bi.id FROM public."BOMInstances" bi WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false);
        UPDATE public."BOMInstances" bi SET deleted = true, updated_at = now() WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false;
        INSERT INTO public."BOMInstances" (organization_id, manufacturing_order_id, sales_order_line_id, quote_line_id, bom_template_id, deleted, created_at, updated_at) VALUES (v_mo.organization_id, p_manufacturing_order_id, v_sol.id, v_sol.quote_line_id, (v_snapshot->>'bom_template_id')::uuid, false, now(), now()) RETURNING id INTO v_bi_id;
        IF v_bi_id IS NULL THEN CONTINUE; END IF;
        v_tbi := v_tbi + 1;
        FOR v_item IN SELECT value FROM jsonb_array_elements(v_items)
        LOOP
            v_catalog_item_id := (v_item->>'catalog_item_id')::uuid; v_role := v_item->>'role'; v_qty := COALESCE((v_item->>'qty')::numeric, 0); v_uom := COALESCE(v_item->>'uom', 'ea');
            IF v_catalog_item_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;
            SELECT COALESCE(cim.total_cost, ci.cost_exw::numeric(12,4), 0) INTO v_ucx FROM public."CatalogItems" ci LEFT JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id AND cim.organization_id = v_mo.organization_id WHERE ci.id = v_catalog_item_id LIMIT 1;
            IF NOT FOUND THEN v_ucx := 0; END IF;
            v_tcx := v_ucx * v_qty; v_um := COALESCE((v_item->>'unit_price')::numeric(12,4), 0); v_tm := COALESCE((v_item->>'line_total')::numeric(12,4), 0);
            INSERT INTO public."BOMInstanceLines" (organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom, unit_cost_exw, total_cost_exw, unit_msrp, total_msrp, cut_length_mm, cut_height_mm, deleted, created_at, updated_at) VALUES (v_mo.organization_id, v_bi_id, v_catalog_item_id, v_role, v_qty, v_uom, COALESCE(v_ucx, 0), COALESCE(v_tcx, 0), COALESCE(v_um, 0), COALESCE(v_tm, 0), CASE WHEN v_role = 'fabric' AND v_fabric_calc IS NOT NULL THEN (v_fabric_calc->>'fabric_cut_width_mm')::numeric WHEN v_uom = 'm' THEN v_qty * 1000.0 ELSE NULL END, CASE WHEN v_role = 'fabric' AND v_fabric_calc IS NOT NULL THEN (v_fabric_calc->>'fabric_cut_height_mm')::numeric ELSE NULL END, false, now(), now());
            v_tbl := v_tbl + 1;
            IF v_item->'children' IS NOT NULL AND jsonb_typeof(v_item->'children') = 'array' AND jsonb_array_length(v_item->'children') > 0 THEN
                FOR v_child IN SELECT value FROM jsonb_array_elements(v_item->'children')
                LOOP
                    v_catalog_item_id := (v_child->>'catalog_item_id')::uuid; v_role := v_child->>'role'; v_qty := COALESCE((v_child->>'qty')::numeric, 0); v_uom := COALESCE(v_child->>'uom', 'ea');
                    IF v_catalog_item_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;
                    SELECT COALESCE(cim.total_cost, ci.cost_exw::numeric(12,4), 0) INTO v_ucx FROM public."CatalogItems" ci LEFT JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id AND cim.organization_id = v_mo.organization_id WHERE ci.id = v_catalog_item_id LIMIT 1;
                    IF NOT FOUND THEN v_ucx := 0; END IF;
                    v_tcx := v_ucx * v_qty; v_um := COALESCE((v_child->>'unit_price')::numeric(12,4), 0); v_tm := COALESCE((v_child->>'line_total')::numeric(12,4), 0);
                    INSERT INTO public."BOMInstanceLines" (organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom, unit_cost_exw, total_cost_exw, unit_msrp, total_msrp, cut_length_mm, cut_height_mm, deleted, created_at, updated_at) VALUES (v_mo.organization_id, v_bi_id, v_catalog_item_id, v_role, v_qty, v_uom, COALESCE(v_ucx, 0), COALESCE(v_tcx, 0), COALESCE(v_um, 0), COALESCE(v_tm, 0), CASE WHEN v_uom = 'm' THEN v_qty * 1000.0 ELSE NULL END, NULL, false, now(), now());
                    v_tbl := v_tbl + 1;
                END LOOP;
            END IF;
        END LOOP;

        FOR v_role IN SELECT replace(k, '_width_mm', '') FROM jsonb_object_keys(v_dim_outputs) AS k WHERE k LIKE '%\_width\_mm' AND k NOT LIKE 'finished%'
        LOOP
            v_panel_cuts_key := v_role || '_panel_cuts'; v_panel_cuts := v_dim_outputs->v_panel_cuts_key;
            IF v_panel_cuts IS NOT NULL AND jsonb_typeof(v_panel_cuts) = 'array' AND jsonb_array_length(v_panel_cuts) > 1 THEN
                SELECT COALESCE(SUM((pc->>(v_role || '_width_mm'))::numeric), 0) / 1000.0 INTO v_sum_m FROM jsonb_array_elements(v_panel_cuts) AS pc;
                FOR v_src_line IN SELECT * FROM public."BOMInstanceLines" WHERE bom_instance_id = v_bi_id AND part_role = v_role AND deleted = false AND COALESCE(uom,'') = 'm'
                LOOP
                    v_recon_tol := GREATEST(0.01, ABS(COALESCE(v_src_line.qty, 0)) * 0.01);
                    IF ABS(v_sum_m - COALESCE(v_src_line.qty, 0)) > v_recon_tol THEN
                        v_recon_skips := v_recon_skips + 1; v_warn := v_warn || format('Role %s: panel geometry %sm <> quoted %sm (SOL %s); kept single line, cost frozen', v_role, round(v_sum_m, 3), round(COALESCE(v_src_line.qty, 0), 3), v_sol.id); CONTINUE;
                    END IF;
                    v_frozen_cost := COALESCE(v_src_line.total_cost_exw, 0); v_frozen_msrp := COALESCE(v_src_line.total_msrp, 0);
                    SELECT COALESCE(SUM((value->>(v_role||'_width_mm'))::numeric),0), COUNT(*) INTO v_pc_total_mm, v_pc_count FROM jsonb_array_elements(v_panel_cuts) AS value WHERE COALESCE((value->>(v_role||'_width_mm'))::numeric,0) > 0;
                    v_acc_cost := 0; v_acc_msrp := 0; v_pc_seen := 0;
                    UPDATE public."BOMInstanceLines" SET deleted = true, updated_at = now() WHERE id = v_src_line.id;
                    FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
                        v_panel_idx := (v_pc->>'index')::integer; v_panel_cut_mm := COALESCE((v_pc->>(v_role || '_width_mm'))::numeric, 0);
                        IF v_panel_cut_mm <= 0 THEN CONTINUE; END IF;
                        v_pc_seen := v_pc_seen + 1; v_qty := ROUND(v_panel_cut_mm / 1000.0, 4);
                        IF v_pc_seen = v_pc_count THEN
                            v_panel_cost := ROUND(v_frozen_cost - v_acc_cost, 4); v_panel_msrp := ROUND(v_frozen_msrp - v_acc_msrp, 4);
                        ELSE
                            v_weight := CASE WHEN v_pc_total_mm > 0 THEN v_panel_cut_mm / v_pc_total_mm ELSE 0 END;
                            v_panel_cost := ROUND(v_frozen_cost * v_weight, 4); v_panel_msrp := ROUND(v_frozen_msrp * v_weight, 4);
                            v_acc_cost := v_acc_cost + v_panel_cost; v_acc_msrp := v_acc_msrp + v_panel_msrp;
                        END IF;
                        v_unit_cost_per_m := CASE WHEN v_qty > 0 THEN v_panel_cost / v_qty ELSE 0 END; v_unit_msrp_per_m := CASE WHEN v_qty > 0 THEN v_panel_msrp / v_qty ELSE 0 END;
                        INSERT INTO public."BOMInstanceLines" (organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom, unit_cost_exw, total_cost_exw, unit_msrp, total_msrp, cut_length_mm, cut_height_mm, panel_index, deleted, created_at, updated_at) VALUES (v_src_line.organization_id, v_src_line.bom_instance_id, v_src_line.resolved_part_id, v_src_line.part_role, v_qty, v_src_line.uom, ROUND(v_unit_cost_per_m, 4), v_panel_cost, ROUND(v_unit_msrp_per_m, 4), v_panel_msrp, ROUND(v_panel_cut_mm, 1), NULL, v_panel_idx, false, now(), now());
                        v_tbl := v_tbl + 1;
                    END LOOP;
                END LOOP;
            ELSE
                v_core_mm := (v_dim_outputs->>(v_role || '_width_mm'))::numeric;
                IF v_core_mm IS NOT NULL AND v_core_mm > 0 THEN
                    SELECT count(*) INTO v_line_cnt FROM public."BOMInstanceLines" WHERE bom_instance_id = v_bi_id AND part_role = v_role AND deleted = false AND COALESCE(uom,'') = 'm' AND panel_index IS NULL;
                    IF v_line_cnt = 1 THEN
                        FOR v_src_line IN SELECT * FROM public."BOMInstanceLines" WHERE bom_instance_id = v_bi_id AND part_role = v_role AND deleted = false AND COALESCE(uom,'') = 'm' AND panel_index IS NULL
                        LOOP
                            v_quoted_cut_mm := COALESCE(v_src_line.cut_length_mm, COALESCE(v_src_line.qty, 0) * 1000.0);
                            v_recon_tol := GREATEST(15, ABS(v_quoted_cut_mm) * 0.02);
                            IF ABS(v_core_mm - v_quoted_cut_mm) > v_recon_tol THEN
                                v_recon_skips := v_recon_skips + 1; v_warn := v_warn || format('Role %s single-panel: core cut %smm <> quoted %smm (SOL %s); kept quoted cut', v_role, round(v_core_mm, 1), round(v_quoted_cut_mm, 1), v_sol.id); CONTINUE;
                            END IF;
                            UPDATE public."BOMInstanceLines" SET cut_length_mm = ROUND(v_core_mm, 1), updated_at = now() WHERE id = v_src_line.id;
                        END LOOP;
                    END IF;
                END IF;
            END IF;
        END LOOP;

        v_panel_cuts := v_dim_outputs->'tube_panel_cuts';
        IF v_panel_cuts IS NOT NULL AND jsonb_typeof(v_panel_cuts) = 'array' AND jsonb_array_length(v_panel_cuts) > 1 THEN
            FOR v_src_line IN SELECT * FROM public."BOMInstanceLines" WHERE bom_instance_id = v_bi_id AND part_role = 'fabric' AND deleted = false
            LOOP
                IF COALESCE(v_src_line.uom, '') <> 'm' THEN CONTINUE; END IF;
                v_frozen_cost := COALESCE(v_src_line.total_cost_exw, 0); v_frozen_msrp := COALESCE(v_src_line.total_msrp, 0);
                SELECT COALESCE(SUM((value->>'tube_width_mm')::numeric),0), COUNT(*) INTO v_pc_total_mm, v_pc_count FROM jsonb_array_elements(v_panel_cuts) AS value WHERE COALESCE((value->>'tube_width_mm')::numeric,0) > 0;
                v_acc_cost := 0; v_acc_msrp := 0; v_pc_seen := 0;
                UPDATE public."BOMInstanceLines" SET deleted = true, updated_at = now() WHERE id = v_src_line.id;
                FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
                    v_panel_idx := (v_pc->>'index')::integer; v_panel_cut_mm := GREATEST(0, COALESCE((v_pc->>'tube_width_mm')::numeric, 0) - v_fab_clear_mm);
                    IF v_panel_cut_mm <= 0 THEN CONTINUE; END IF;
                    v_pc_seen := v_pc_seen + 1; v_qty := ROUND(v_panel_cut_mm / 1000.0, 4);
                    IF v_pc_seen = v_pc_count THEN
                        v_panel_cost := ROUND(v_frozen_cost - v_acc_cost, 4); v_panel_msrp := ROUND(v_frozen_msrp - v_acc_msrp, 4);
                    ELSE
                        v_weight := CASE WHEN v_pc_total_mm > 0 THEN COALESCE((v_pc->>'tube_width_mm')::numeric,0) / v_pc_total_mm ELSE 0 END;
                        v_panel_cost := ROUND(v_frozen_cost * v_weight, 4); v_panel_msrp := ROUND(v_frozen_msrp * v_weight, 4);
                        v_acc_cost := v_acc_cost + v_panel_cost; v_acc_msrp := v_acc_msrp + v_panel_msrp;
                    END IF;
                    v_unit_cost_per_m := CASE WHEN v_qty > 0 THEN v_panel_cost / v_qty ELSE 0 END; v_unit_msrp_per_m := CASE WHEN v_qty > 0 THEN v_panel_msrp / v_qty ELSE 0 END;
                    INSERT INTO public."BOMInstanceLines" (organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom, unit_cost_exw, total_cost_exw, unit_msrp, total_msrp, cut_length_mm, cut_height_mm, panel_index, deleted, created_at, updated_at) VALUES (v_src_line.organization_id, v_src_line.bom_instance_id, v_src_line.resolved_part_id, v_src_line.part_role, v_qty, v_src_line.uom, ROUND(v_unit_cost_per_m, 4), v_panel_cost, ROUND(v_unit_msrp_per_m, 4), v_panel_msrp, ROUND(v_panel_cut_mm, 1), v_src_line.cut_height_mm, v_panel_idx, false, now(), now());
                    v_tbl := v_tbl + 1;
                END LOOP;
            END LOOP;
        END IF;
    END LOOP;

    SELECT COUNT(*) INTO v_bia FROM public."BOMInstances" WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;
    SELECT COUNT(*) INTO v_bla FROM public."BOMInstanceLines" bil JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    RETURN jsonb_build_object('ok', array_length(v_err, 1) IS NULL OR array_length(v_err, 1) = 0, 'manufacturing_order_id', p_manufacturing_order_id, 'status', v_mo.status::text, 'mo_lines_before', v_mlb, 'mo_lines_after', v_mla, 'mo_lines_created', v_cml, 'mo_lines_processed', v_mlp, 'supply_only_skipped', v_supply_skipped, 'reconciliation_skips', v_recon_skips, 'bom_instances_before', v_bib, 'bom_instances_after', v_bia, 'bom_instances_created', v_bia - v_bib, 'bom_instance_lines_before', v_blb, 'bom_instance_lines_after', v_bla, 'bom_instance_lines_created', v_bla - v_blb, 'warnings', COALESCE(v_warn, ARRAY[]::text[]), 'errors', COALESCE(v_err, ARRAY[]::text[]));
END;
$function$;
