-- Per-Panel BOM Calculation Engine
-- Adds per_panel boolean to BOMComponents so tube, bottom_bar and their children
-- auto-replicate per panel. Fixes per_joint qty. Adds headbox dimension support.

-- 1. Add per_panel column
ALTER TABLE "BOMComponents"
  ADD COLUMN IF NOT EXISTS per_panel boolean NOT NULL DEFAULT false;

-- 2. Update save_bom_template_batch to persist per_panel
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
      manufacturer, product_line, system_size,
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

  -- First pass: parents
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
        sort_order          = COALESCE((v_comp ->> 'sort_order')::int, 0),
        is_required         = COALESCE((v_comp ->> 'is_required')::boolean, false),
        per_panel           = COALESCE((v_comp ->> 'per_panel')::boolean, false),
        auto_select         = false,
        parent_component_id = NULL,
        updated_at          = v_now
      WHERE id = v_comp_id
        AND organization_id = p_organization_id
        AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id,
        component_item_id, component_role, qty_type, qty_value,
        qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, depends_on_role, affects_role, cut_axis,
        cut_delta_mm, sort_order, is_required, per_panel, auto_select,
        deleted, archived, created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id, NULL,
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
        COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, false),
        COALESCE((v_comp ->> 'per_panel')::boolean, false),
        false,
        false, false, v_now, v_now
      )
      RETURNING id INTO v_comp_id;
    END IF;

    IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN
      v_id_map := v_id_map || jsonb_build_object(v_temp_id, v_comp_id::text);
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
    v_real_parent_id := NULL;

    IF v_parent_temp_id IS NOT NULL AND v_parent_temp_id != '' THEN
      v_real_parent_id := (v_id_map ->> v_parent_temp_id)::uuid;
      IF v_real_parent_id IS NULL THEN CONTINUE; END IF;
    ELSIF (v_comp ->> 'parent_component_id') IS NOT NULL
          AND (v_comp ->> 'parent_component_id') != ''
          AND (v_comp ->> 'parent_component_id') NOT LIKE 'temp-%' THEN
      v_real_parent_id := (v_comp ->> 'parent_component_id')::uuid;
    ELSE
      CONTINUE;
    END IF;

    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        parent_component_id = v_real_parent_id,
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
        sort_order          = COALESCE((v_comp ->> 'sort_order')::int, 0),
        is_required         = COALESCE((v_comp ->> 'is_required')::boolean, false),
        per_panel           = COALESCE((v_comp ->> 'per_panel')::boolean, false),
        auto_select         = false,
        updated_at          = v_now
      WHERE id = v_comp_id
        AND organization_id = p_organization_id
        AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id,
        component_item_id, component_role, qty_type, qty_value,
        qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, depends_on_role, affects_role, cut_axis,
        cut_delta_mm, sort_order, is_required, per_panel, auto_select,
        deleted, archived, created_at, updated_at
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
        COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, false),
        COALESCE((v_comp ->> 'per_panel')::boolean, false),
        false,
        false, false, v_now, v_now
      )
      RETURNING id INTO v_comp_id;
    END IF;

    IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN
      v_id_map := v_id_map || jsonb_build_object(v_temp_id, v_comp_id::text);
    END IF;
  END LOOP;

  SELECT jsonb_agg(row_to_json(c.*)::jsonb ORDER BY c.parent_component_id NULLS FIRST, c.sort_order, c.created_at)
  INTO v_result_components
  FROM "BOMComponents" c
  WHERE c.bom_template_id = v_template_id
    AND c.organization_id = p_organization_id
    AND c.deleted = false
    AND c.archived = false;

  RETURN jsonb_build_object(
    'template_id', v_template_id,
    'is_new', v_is_new_template,
    'id_map', v_id_map,
    'components', COALESCE(v_result_components, '[]'::jsonb)
  );
END;
$$;

-- 3. Update compute_system_dimensions to include headbox
DROP FUNCTION IF EXISTS public.compute_system_dimensions(uuid);

CREATE OR REPLACE FUNCTION public.compute_system_dimensions(
  p_configured_product_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_cp RECORD;
  v_width_mm numeric;
  v_height_mm numeric;
  v_result jsonb := '{}'::jsonb;
  v_config jsonb;
  v_panels jsonb;
  v_panel_count integer;
  v_endpoint_delta numeric;
  v_joint_delta numeric;
  v_endpoint_share numeric;
  v_joint_share numeric;
  v_panel_width numeric;
  v_panel_cut numeric;
  v_panel_cuts jsonb;
  v_total_cut numeric;
  v_i integer;
  v_position text;
  v_delta_sum numeric;
BEGIN
  SELECT cp.*, bt.id AS bt_id
  INTO v_cp
  FROM "ConfiguredProducts" cp
  LEFT JOIN "BOMTemplates" bt ON bt.id = cp.bom_template_id
  WHERE cp.id = p_configured_product_id AND cp.deleted = false;

  IF NOT FOUND OR v_cp.bt_id IS NULL THEN
    RETURN v_result;
  END IF;

  v_width_mm := COALESCE(v_cp.width_mm, 0);
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  v_panels := COALESCE(
    v_config->'measurements'->'panels',
    v_config->'panels'
  );
  v_panel_count := CASE
    WHEN v_panels IS NOT NULL
         AND jsonb_typeof(v_panels) = 'array'
         AND jsonb_array_length(v_panels) > 1
    THEN jsonb_array_length(v_panels)
    ELSE 1
  END;

  -- ===== TUBE =====
  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_endpoint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'tube'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND COALESCE(bc.qty_type::text, 'fixed') != 'per_joint';

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_joint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'tube'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND bc.qty_type::text = 'per_joint';

  IF v_panel_count > 1 THEN
    v_endpoint_share := v_endpoint_delta / 2.0;
    v_joint_share := v_joint_delta / 2.0;
    v_panel_cuts := '[]'::jsonb;
    v_total_cut := 0;

    FOR v_i IN 0..(v_panel_count - 1) LOOP
      v_panel_width := COALESCE((v_panels->v_i->>'width_mm')::numeric, 0);

      IF v_i = 0 THEN
        v_position := 'left';
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSIF v_i = v_panel_count - 1 THEN
        v_position := 'right';
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSE
        v_position := 'center';
        v_panel_cut := GREATEST(0, v_panel_width + v_joint_delta);
      END IF;

      v_total_cut := v_total_cut + v_panel_cut;
      v_panel_cuts := v_panel_cuts || jsonb_build_object(
        'index', v_i + 1,
        'position', v_position,
        'panel_width_mm', v_panel_width,
        'tube_width_mm', ROUND(v_panel_cut, 1)
      );
    END LOOP;

    v_result := v_result || jsonb_build_object(
      'tube_width_mm', ROUND(v_total_cut, 1),
      'tube_panel_cuts', v_panel_cuts,
      'panel_count', v_panel_count,
      'tube_endpoint_delta_mm', v_endpoint_delta,
      'tube_joint_delta_mm', v_joint_delta
    );
  ELSE
    v_delta_sum := v_endpoint_delta + v_joint_delta;
    v_result := v_result || jsonb_build_object(
      'tube_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
    );
  END IF;

  -- ===== BOTTOM BAR =====
  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_endpoint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'bottom_bar'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND COALESCE(bc.qty_type::text, 'fixed') != 'per_joint';

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_joint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'bottom_bar'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND bc.qty_type::text = 'per_joint';

  IF v_panel_count > 1 THEN
    v_endpoint_share := v_endpoint_delta / 2.0;
    v_joint_share := v_joint_delta / 2.0;
    v_panel_cuts := '[]'::jsonb;
    v_total_cut := 0;

    FOR v_i IN 0..(v_panel_count - 1) LOOP
      v_panel_width := COALESCE((v_panels->v_i->>'width_mm')::numeric, 0);

      IF v_i = 0 THEN
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSIF v_i = v_panel_count - 1 THEN
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSE
        v_panel_cut := GREATEST(0, v_panel_width + v_joint_delta);
      END IF;

      v_total_cut := v_total_cut + v_panel_cut;
      v_panel_cuts := v_panel_cuts || jsonb_build_object(
        'index', v_i + 1,
        'bottom_bar_width_mm', ROUND(v_panel_cut, 1)
      );
    END LOOP;

    v_result := v_result || jsonb_build_object(
      'bottom_bar_width_mm', ROUND(v_total_cut, 1),
      'bottom_bar_panel_cuts', v_panel_cuts
    );
  ELSE
    v_delta_sum := v_endpoint_delta + v_joint_delta;
    v_result := v_result || jsonb_build_object(
      'bottom_bar_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
    );
  END IF;

  -- ===== TRACK =====
  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_delta_sum
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'track'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0;

  v_result := v_result || jsonb_build_object(
    'track_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
  );

  -- ===== HEADBOX / FASCIA =====
  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_delta_sum
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'headbox'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0;

  v_result := v_result || jsonb_build_object(
    'headbox_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
  );

  -- ===== COMMON =====
  v_result := v_result || jsonb_build_object(
    'finished_width_mm', v_width_mm,
    'finished_height_mm', v_height_mm
  );

  RETURN v_result;
END;
$$;

-- 4. build_bom_preview_snapshot is updated live (too large for migration).
-- See the CREATE OR REPLACE in the application deployment.
