-- Role-Based Cut Deductions: add affected_by_roles to BOMComponents,
-- populate from existing affects_role data, and update save_bom_template_batch.

-- ============================================================================
-- 1. Add affected_by_roles column
-- ============================================================================

ALTER TABLE "BOMComponents"
  ADD COLUMN IF NOT EXISTS affected_by_roles text[] DEFAULT '{}';

COMMENT ON COLUMN "BOMComponents".affected_by_roles IS
  'Array of component_role values whose deltas affect this cuttable component''s cut dimension';

-- ============================================================================
-- 2. Data migration: populate affected_by_roles from existing affects_role
--    For each cuttable parent, collect the distinct component_role values
--    of all parents that have affects_role pointing to it.
-- ============================================================================

UPDATE "BOMComponents" target
SET affected_by_roles = sub.roles
FROM (
    SELECT bc_target.id,
           ARRAY_AGG(DISTINCT bc_src.component_role) as roles
    FROM "BOMComponents" bc_target
    JOIN "BOMComponents" bc_src
      ON bc_src.bom_template_id = bc_target.bom_template_id
      AND bc_src.affects_role = bc_target.component_role
      AND bc_src.parent_component_id IS NULL
      AND bc_src.deleted = false
    WHERE bc_target.parent_component_id IS NULL
      AND bc_target.deleted = false
      AND bc_target.uom IN ('m','m2')
    GROUP BY bc_target.id
) sub
WHERE target.id = sub.id;

-- ============================================================================
-- 3. Update save_bom_template_batch to persist affected_by_roles
-- ============================================================================

DROP FUNCTION IF EXISTS public.save_bom_template_batch(uuid, jsonb, jsonb, uuid[]);

CREATE OR REPLACE FUNCTION public.save_bom_template_batch(
  p_organization_id uuid,
  p_template jsonb,
  p_components_upsert jsonb,
  p_component_ids_delete uuid[] DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
      product_type_id       = (p_template ->> 'product_type_id')::uuid,
      code                  = p_template ->> 'code',
      name                  = COALESCE(p_template ->> 'name', p_template ->> 'code'),
      description           = p_template ->> 'description',
      hardware_color        = p_template ->> 'hardware_color',
      panel_count_min       = COALESCE((p_template ->> 'panel_count_min')::int, 1),
      panel_count_max       = COALESCE((p_template ->> 'panel_count_max')::int, 1),
      drive_type            = p_template ->> 'drive_type',
      drive_side            = p_template ->> 'drive_side',
      opening_direction     = p_template ->> 'opening_direction',
      installation_location = p_template ->> 'installation_location',
      manufacturer          = p_template ->> 'manufacturer',
      product_line          = p_template ->> 'product_line',
      system_size           = p_template ->> 'system_size',
      headbox               = COALESCE((p_template ->> 'headbox')::boolean, false),
      metadata              = COALESCE((p_template -> 'metadata')::jsonb, '{}'::jsonb),
      is_active             = COALESCE((p_template ->> 'is_active')::boolean, true),
      updated_at            = v_now
    WHERE id = v_template_id
      AND organization_id = p_organization_id;
  ELSE
    v_is_new_template := true;
    INSERT INTO "BOMTemplates" (
      organization_id, product_type_id, code, name, description,
      hardware_color, panel_count_min, panel_count_max,
      drive_type, drive_side, opening_direction, installation_location,
      manufacturer, product_line, system_size, headbox,
      metadata, is_active, archived, created_at, updated_at
    ) VALUES (
      p_organization_id,
      (p_template ->> 'product_type_id')::uuid,
      p_template ->> 'code',
      COALESCE(p_template ->> 'name', p_template ->> 'code'),
      p_template ->> 'description',
      p_template ->> 'hardware_color',
      COALESCE((p_template ->> 'panel_count_min')::int, 1),
      COALESCE((p_template ->> 'panel_count_max')::int, 1),
      p_template ->> 'drive_type',
      p_template ->> 'drive_side',
      p_template ->> 'opening_direction',
      p_template ->> 'installation_location',
      p_template ->> 'manufacturer',
      p_template ->> 'product_line',
      p_template ->> 'system_size',
      COALESCE((p_template ->> 'headbox')::boolean, false),
      COALESCE((p_template -> 'metadata')::jsonb, '{}'::jsonb),
      true, false, v_now, v_now
    )
    RETURNING id INTO v_template_id;
  END IF;

  IF array_length(p_component_ids_delete, 1) > 0 THEN
    UPDATE "BOMComponents"
    SET deleted = true, updated_at = v_now
    WHERE id = ANY(p_component_ids_delete)
      AND organization_id = p_organization_id
      AND bom_template_id = v_template_id;
  END IF;

  -- First pass: parents (no parent_temp_id, no parent_component_id)
  FOR v_comp IN SELECT jsonb_array_elements(p_components_upsert)
  LOOP
    v_temp_id := v_comp ->> 'temp_id';
    v_comp_id := CASE
      WHEN (v_comp ->> 'id') IS NOT NULL AND (v_comp ->> 'id') NOT LIKE 'temp-%'
      THEN (v_comp ->> 'id')::uuid
      ELSE NULL
    END;

    v_parent_temp_id := v_comp ->> 'parent_temp_id';
    IF v_parent_temp_id IS NOT NULL AND v_parent_temp_id != '' THEN CONTINUE; END IF;
    IF (v_comp ->> 'parent_component_id') IS NOT NULL
       AND (v_comp ->> 'parent_component_id') != ''
       AND (v_comp ->> 'parent_component_id') NOT LIKE 'temp-%' THEN
      CONTINUE;
    END IF;

    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        component_item_id   = (v_comp ->> 'component_item_id')::uuid,
        component_role      = COALESCE(v_comp ->> 'component_role', 'hardware'),
        qty_type            = COALESCE(v_comp ->> 'qty_type', 'fixed'),
        qty_value           = COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        qty_delta_mm        = COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        qty_spacing_mm      = (v_comp ->> 'qty_spacing_mm')::integer,
        qty_min             = (v_comp ->> 'qty_min')::numeric,
        uom                 = COALESCE(v_comp ->> 'uom', 'ea'),
        waste_pct           = COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        depends_on_role     = v_comp ->> 'depends_on_role',
        affects_role        = v_comp ->> 'affects_role',
        cut_axis            = v_comp ->> 'cut_axis',
        cut_delta_mm        = COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        delta_mode          = COALESCE(v_comp ->> 'delta_mode', 'subtract'),
        affected_by_roles   = COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_comp->'affected_by_roles')), '{}'),
        sort_order          = COALESCE((v_comp ->> 'sort_order')::int, 0),
        is_required         = COALESCE((v_comp ->> 'is_required')::boolean, true),
        per_panel           = COALESCE((v_comp ->> 'per_panel')::boolean, false),
        auto_select         = COALESCE((v_comp ->> 'auto_select')::boolean, false),
        condition_key       = NULLIF(TRIM(COALESCE(v_comp ->> 'condition_key', '')), ''),
        condition_value     = NULLIF(TRIM(COALESCE(v_comp ->> 'condition_value', '')), ''),
        deleted             = COALESCE((v_comp ->> 'deleted')::boolean, false),
        updated_at          = v_now
      WHERE id = v_comp_id
        AND organization_id = p_organization_id
        AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id,
        component_item_id, component_role,
        qty_type, qty_value, qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct,
        depends_on_role, affects_role,
        cut_axis, cut_delta_mm, delta_mode,
        affected_by_roles,
        sort_order,
        is_required, per_panel, auto_select,
        condition_key, condition_value,
        deleted, archived,
        created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id,
        (v_comp ->> 'component_item_id')::uuid,
        COALESCE(v_comp ->> 'component_role', 'hardware'),
        COALESCE(v_comp ->> 'qty_type', 'fixed'),
        COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        (v_comp ->> 'qty_spacing_mm')::integer,
        (v_comp ->> 'qty_min')::numeric,
        COALESCE(v_comp ->> 'uom', 'ea'),
        COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        v_comp ->> 'depends_on_role',
        v_comp ->> 'affects_role',
        v_comp ->> 'cut_axis',
        COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        COALESCE(v_comp ->> 'delta_mode', 'subtract'),
        COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_comp->'affected_by_roles')), '{}'),
        COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, true),
        COALESCE((v_comp ->> 'per_panel')::boolean, false),
        COALESCE((v_comp ->> 'auto_select')::boolean, false),
        NULLIF(TRIM(COALESCE(v_comp ->> 'condition_key', '')), ''),
        NULLIF(TRIM(COALESCE(v_comp ->> 'condition_value', '')), ''),
        false, false,
        v_now, v_now
      )
      RETURNING id INTO v_comp_id;

      IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN
        v_id_map := jsonb_set(v_id_map, ARRAY[v_temp_id], to_jsonb(v_comp_id::text));
      END IF;
    END IF;
  END LOOP;

  -- Second pass: children
  FOR v_comp IN SELECT jsonb_array_elements(p_components_upsert)
  LOOP
    v_temp_id := v_comp ->> 'temp_id';
    v_comp_id := CASE
      WHEN (v_comp ->> 'id') IS NOT NULL AND (v_comp ->> 'id') NOT LIKE 'temp-%'
      THEN (v_comp ->> 'id')::uuid
      ELSE NULL
    END;

    v_parent_temp_id := v_comp ->> 'parent_temp_id';
    IF v_parent_temp_id IS NULL OR v_parent_temp_id = '' THEN
      IF (v_comp ->> 'parent_component_id') IS NULL
         OR (v_comp ->> 'parent_component_id') = ''
         OR (v_comp ->> 'parent_component_id') LIKE 'temp-%' THEN
        CONTINUE;
      END IF;
    END IF;

    v_real_parent_id := CASE
      WHEN v_parent_temp_id IS NOT NULL AND v_parent_temp_id != ''
      THEN (v_id_map ->> v_parent_temp_id)::uuid
      ELSE (v_comp ->> 'parent_component_id')::uuid
    END;

    IF v_real_parent_id IS NULL THEN CONTINUE; END IF;

    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        component_item_id   = (v_comp ->> 'component_item_id')::uuid,
        component_role      = COALESCE(v_comp ->> 'component_role', 'hardware'),
        parent_component_id = v_real_parent_id,
        qty_type            = COALESCE(v_comp ->> 'qty_type', 'fixed'),
        qty_value           = COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        qty_delta_mm        = COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        qty_spacing_mm      = (v_comp ->> 'qty_spacing_mm')::integer,
        qty_min             = (v_comp ->> 'qty_min')::numeric,
        uom                 = COALESCE(v_comp ->> 'uom', 'ea'),
        waste_pct           = COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        depends_on_role     = v_comp ->> 'depends_on_role',
        affects_role        = v_comp ->> 'affects_role',
        cut_axis            = v_comp ->> 'cut_axis',
        cut_delta_mm        = COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        delta_mode          = COALESCE(v_comp ->> 'delta_mode', 'subtract'),
        sort_order          = COALESCE((v_comp ->> 'sort_order')::int, 0),
        is_required         = COALESCE((v_comp ->> 'is_required')::boolean, true),
        per_panel           = COALESCE((v_comp ->> 'per_panel')::boolean, false),
        auto_select         = COALESCE((v_comp ->> 'auto_select')::boolean, false),
        condition_key       = NULLIF(TRIM(COALESCE(v_comp ->> 'condition_key', '')), ''),
        condition_value     = NULLIF(TRIM(COALESCE(v_comp ->> 'condition_value', '')), ''),
        deleted             = COALESCE((v_comp ->> 'deleted')::boolean, false),
        updated_at          = v_now
      WHERE id = v_comp_id
        AND organization_id = p_organization_id
        AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id,
        component_item_id, component_role,
        qty_type, qty_value, qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct,
        depends_on_role, affects_role,
        cut_axis, cut_delta_mm, delta_mode,
        sort_order,
        is_required, per_panel, auto_select,
        condition_key, condition_value,
        deleted, archived,
        created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id, v_real_parent_id,
        (v_comp ->> 'component_item_id')::uuid,
        COALESCE(v_comp ->> 'component_role', 'hardware'),
        COALESCE(v_comp ->> 'qty_type', 'fixed'),
        COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        (v_comp ->> 'qty_spacing_mm')::integer,
        (v_comp ->> 'qty_min')::numeric,
        COALESCE(v_comp ->> 'uom', 'ea'),
        COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        v_comp ->> 'depends_on_role',
        v_comp ->> 'affects_role',
        v_comp ->> 'cut_axis',
        COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        COALESCE(v_comp ->> 'delta_mode', 'subtract'),
        COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, true),
        COALESCE((v_comp ->> 'per_panel')::boolean, false),
        COALESCE((v_comp ->> 'auto_select')::boolean, false),
        NULLIF(TRIM(COALESCE(v_comp ->> 'condition_key', '')), ''),
        NULLIF(TRIM(COALESCE(v_comp ->> 'condition_value', '')), ''),
        false, false,
        v_now, v_now
      );
    END IF;
  END LOOP;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', bc.id,
      'component_item_id', bc.component_item_id,
      'component_role', bc.component_role,
      'qty_type', bc.qty_type,
      'qty_value', bc.qty_value,
      'qty_delta_mm', bc.qty_delta_mm,
      'qty_spacing_mm', bc.qty_spacing_mm,
      'qty_min', bc.qty_min,
      'uom', bc.uom,
      'waste_pct', bc.waste_pct,
      'depends_on_role', bc.depends_on_role,
      'affects_role', bc.affects_role,
      'cut_axis', bc.cut_axis,
      'cut_delta_mm', bc.cut_delta_mm,
      'delta_mode', bc.delta_mode,
      'affected_by_roles', bc.affected_by_roles,
      'sort_order', bc.sort_order,
      'is_required', bc.is_required,
      'per_panel', bc.per_panel,
      'auto_select', bc.auto_select,
      'condition_key', bc.condition_key,
      'condition_value', bc.condition_value,
      'parent_component_id', bc.parent_component_id,
      'deleted', bc.deleted
    )
  )
  INTO v_result_components
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_template_id
    AND bc.organization_id = p_organization_id
    AND bc.deleted = false
    AND bc.archived = false;

  RETURN jsonb_build_object(
    'template_id', v_template_id,
    'is_new', v_is_new_template,
    'components', COALESCE(v_result_components, '[]'::jsonb)
  );
END;
$$;
