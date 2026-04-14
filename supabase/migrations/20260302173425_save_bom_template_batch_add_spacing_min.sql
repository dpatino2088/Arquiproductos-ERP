CREATE OR REPLACE FUNCTION public.save_bom_template_batch(
  p_organization_id uuid,
  p_template jsonb,
  p_components_upsert jsonb DEFAULT '[]'::jsonb,
  p_component_ids_delete uuid[] DEFAULT '{}'::uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_template_id uuid;
  v_is_new_template boolean := false;
  v_comp jsonb;
  v_comp_id uuid;
  v_temp_id text;
  v_parent_temp_id text;
  v_real_parent_id uuid;
  v_id_map jsonb := '{}'::jsonb;
  v_result_components jsonb;
  v_now timestamptz := now();
BEGIN
  v_template_id := (p_template ->> 'id')::uuid;
  IF v_template_id IS NOT NULL THEN
    UPDATE "BOMTemplates" SET
      product_type_id  = (p_template ->> 'product_type_id')::uuid,
      code             = p_template ->> 'code',
      name             = COALESCE(p_template ->> 'name', p_template ->> 'code'),
      description      = p_template ->> 'description',
      hardware_color   = p_template ->> 'hardware_color',
      panel_count_min  = COALESCE((p_template ->> 'panel_count_min')::int, 1),
      panel_count_max  = COALESCE((p_template ->> 'panel_count_max')::int, 1),
      metadata         = COALESCE((p_template -> 'metadata')::jsonb, '{}'::jsonb),
      is_active        = COALESCE((p_template ->> 'is_active')::boolean, true),
      updated_at       = v_now
    WHERE id = v_template_id AND organization_id = p_organization_id;
  ELSE
    v_is_new_template := true;
    INSERT INTO "BOMTemplates" (
      organization_id, product_type_id, code, name, description,
      hardware_color, panel_count_min, panel_count_max, metadata,
      is_active, archived, created_at, updated_at
    ) VALUES (
      p_organization_id, (p_template ->> 'product_type_id')::uuid,
      p_template ->> 'code', COALESCE(p_template ->> 'name', p_template ->> 'code'),
      p_template ->> 'description', p_template ->> 'hardware_color',
      COALESCE((p_template ->> 'panel_count_min')::int, 1),
      COALESCE((p_template ->> 'panel_count_max')::int, 1),
      COALESCE((p_template -> 'metadata')::jsonb, '{}'::jsonb),
      true, false, v_now, v_now
    ) RETURNING id INTO v_template_id;
  END IF;
  IF array_length(p_component_ids_delete, 1) > 0 THEN
    UPDATE "BOMComponents" SET deleted = true, updated_at = v_now
    WHERE id = ANY(p_component_ids_delete) AND organization_id = p_organization_id AND bom_template_id = v_template_id;
  END IF;
  FOR v_comp IN SELECT jsonb_array_elements(p_components_upsert)
  LOOP
    v_temp_id := v_comp ->> 'temp_id';
    v_comp_id := CASE WHEN (v_comp ->> 'id') IS NOT NULL AND (v_comp ->> 'id') NOT LIKE 'temp-%' THEN (v_comp ->> 'id')::uuid ELSE NULL END;
    v_parent_temp_id := v_comp ->> 'parent_temp_id';
    IF v_parent_temp_id IS NOT NULL AND v_parent_temp_id != '' THEN CONTINUE; END IF;
    IF (v_comp ->> 'parent_component_id') IS NOT NULL AND (v_comp ->> 'parent_component_id') != '' AND (v_comp ->> 'parent_component_id') NOT LIKE 'temp-%' THEN CONTINUE; END IF;
    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        component_item_id = (v_comp ->> 'component_item_id')::uuid, component_role = COALESCE(v_comp ->> 'component_role', 'hardware'),
        qty_type = COALESCE(v_comp ->> 'qty_type', 'fixed'), qty_value = COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        qty_delta_mm = COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        qty_spacing_mm = (v_comp ->> 'qty_spacing_mm')::integer, qty_min = (v_comp ->> 'qty_min')::numeric,
        uom = COALESCE(v_comp ->> 'uom', 'ea'), waste_pct = COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        depends_on_role = v_comp ->> 'depends_on_role', cut_axis = v_comp ->> 'cut_axis',
        cut_delta_mm = COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        sort_order = COALESCE((v_comp ->> 'sort_order')::int, 0), is_required = COALESCE((v_comp ->> 'is_required')::boolean, false),
        auto_select = false, parent_component_id = NULL, updated_at = v_now
      WHERE id = v_comp_id AND organization_id = p_organization_id AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id, component_item_id, component_role,
        qty_type, qty_value, qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, depends_on_role, cut_axis, cut_delta_mm, sort_order, is_required, auto_select,
        deleted, archived, created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id, NULL, (v_comp ->> 'component_item_id')::uuid,
        COALESCE(v_comp ->> 'component_role', 'hardware'), COALESCE(v_comp ->> 'qty_type', 'fixed'),
        COALESCE((v_comp ->> 'qty_value')::numeric, 1), COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        (v_comp ->> 'qty_spacing_mm')::integer, (v_comp ->> 'qty_min')::numeric,
        COALESCE(v_comp ->> 'uom', 'ea'), COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        v_comp ->> 'depends_on_role', v_comp ->> 'cut_axis',
        COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0), COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, false), false, false, false, v_now, v_now
      ) RETURNING id INTO v_comp_id;
    END IF;
    IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN v_id_map := v_id_map || jsonb_build_object(v_temp_id, v_comp_id::text); END IF;
  END LOOP;
  FOR v_comp IN SELECT jsonb_array_elements(p_components_upsert)
  LOOP
    v_temp_id := v_comp ->> 'temp_id';
    v_comp_id := CASE WHEN (v_comp ->> 'id') IS NOT NULL AND (v_comp ->> 'id') NOT LIKE 'temp-%' THEN (v_comp ->> 'id')::uuid ELSE NULL END;
    v_parent_temp_id := v_comp ->> 'parent_temp_id';
    v_real_parent_id := NULL;
    IF v_parent_temp_id IS NOT NULL AND v_parent_temp_id != '' THEN
      v_real_parent_id := (v_id_map ->> v_parent_temp_id)::uuid;
      IF v_real_parent_id IS NULL THEN CONTINUE; END IF;
    ELSIF (v_comp ->> 'parent_component_id') IS NOT NULL AND (v_comp ->> 'parent_component_id') != '' AND (v_comp ->> 'parent_component_id') NOT LIKE 'temp-%' THEN
      v_real_parent_id := (v_comp ->> 'parent_component_id')::uuid;
    ELSE CONTINUE; END IF;
    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        parent_component_id = v_real_parent_id, component_item_id = (v_comp ->> 'component_item_id')::uuid,
        component_role = COALESCE(v_comp ->> 'component_role', 'hardware'),
        qty_type = COALESCE(v_comp ->> 'qty_type', 'fixed'), qty_value = COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        qty_delta_mm = COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        qty_spacing_mm = (v_comp ->> 'qty_spacing_mm')::integer, qty_min = (v_comp ->> 'qty_min')::numeric,
        uom = COALESCE(v_comp ->> 'uom', 'ea'), waste_pct = COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        depends_on_role = v_comp ->> 'depends_on_role', cut_axis = v_comp ->> 'cut_axis',
        cut_delta_mm = COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        sort_order = COALESCE((v_comp ->> 'sort_order')::int, 0), is_required = COALESCE((v_comp ->> 'is_required')::boolean, false),
        auto_select = false, updated_at = v_now
      WHERE id = v_comp_id AND organization_id = p_organization_id AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id, component_item_id, component_role,
        qty_type, qty_value, qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, depends_on_role, cut_axis, cut_delta_mm, sort_order, is_required, auto_select,
        deleted, archived, created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id, v_real_parent_id, (v_comp ->> 'component_item_id')::uuid,
        COALESCE(v_comp ->> 'component_role', 'hardware'), COALESCE(v_comp ->> 'qty_type', 'fixed'),
        COALESCE((v_comp ->> 'qty_value')::numeric, 1), COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        (v_comp ->> 'qty_spacing_mm')::integer, (v_comp ->> 'qty_min')::numeric,
        COALESCE(v_comp ->> 'uom', 'ea'), COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        v_comp ->> 'depends_on_role', v_comp ->> 'cut_axis',
        COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0), COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, false), false, false, false, v_now, v_now
      ) RETURNING id INTO v_comp_id;
    END IF;
    IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN v_id_map := v_id_map || jsonb_build_object(v_temp_id, v_comp_id::text); END IF;
  END LOOP;
  SELECT jsonb_agg(row_to_json(c.*)::jsonb ORDER BY c.parent_component_id NULLS FIRST, c.sort_order, c.created_at)
  INTO v_result_components FROM "BOMComponents" c
  WHERE c.bom_template_id = v_template_id AND c.organization_id = p_organization_id AND c.deleted = false AND c.archived = false;
  RETURN jsonb_build_object('template_id', v_template_id, 'is_new', v_is_new_template, 'id_map', v_id_map, 'components', COALESCE(v_result_components, '[]'::jsonb));
END;
$function$;;
