-- Comprehensive BOM deduction fix: affects_role across ALL templates,
-- compute_system_dimensions uses catalog deltas, generate_bom_for_manufacturing_order
-- applies deductions for both single-panel and multi-panel products.
-- ============================================================================
-- 1. Fix intermediate bracket qty_type across ALL templates
-- ============================================================================

UPDATE "BOMComponents"
SET qty_type = 'per_joint'
WHERE component_role = 'intermediate_bracket'
  AND deleted = false
  AND qty_type != 'per_joint';

-- ============================================================================
-- 1b. Set affects_role = 'tube' for ALL parent components with catalog delta_x_mm
--     (bracket, motor, drive, idler, intermediate_bracket)
-- ============================================================================

UPDATE "BOMComponents" bc
SET affects_role = 'tube'
FROM "CatalogItems" ci
WHERE ci.id = bc.component_item_id
  AND bc.deleted = false
  AND bc.parent_component_id IS NULL
  AND (bc.affects_role IS NULL OR bc.affects_role = '')
  AND ci.delta_x_mm IS NOT NULL
  AND ci.delta_x_mm > 0
  AND bc.component_role IN ('bracket', 'motor', 'drive', 'idler', 'intermediate_bracket');

-- ============================================================================
-- 1c. Propagate affects_role to children of affecting parents with delta_x_mm > 0
--     so the cascade in build_bom_preview_snapshot includes their deductions.
-- ============================================================================

UPDATE "BOMComponents" child
SET affects_role = parent.affects_role
FROM "BOMComponents" parent
WHERE child.parent_component_id = parent.id
  AND child.deleted = false
  AND parent.deleted = false
  AND parent.affects_role IS NOT NULL AND parent.affects_role != ''
  AND (child.affects_role IS NULL OR child.affects_role = '')
  AND EXISTS (
    SELECT 1 FROM "CatalogItems" ci
    WHERE ci.id = child.component_item_id
      AND ci.delta_x_mm IS NOT NULL AND ci.delta_x_mm > 0
  );

-- ============================================================================
-- 2. Rewrite compute_system_dimensions() to use CatalogItems.delta_x_mm
--    (parent + children group deltas, split endpoint vs joint)
-- ============================================================================

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
  v_target_comp_id uuid;
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
  SELECT bc.id INTO v_target_comp_id
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false
    AND bc.component_role = 'tube'
    AND bc.parent_component_id IS NULL
  LIMIT 1;

  -- Endpoint delta: affecting parents (not per_joint) + own children of tube
  SELECT -1.0 * COALESCE(SUM(delta_val), 0)
  INTO v_endpoint_delta
  FROM (
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1)
      + COALESCE((
        SELECT SUM(COALESCE(cci.delta_x_mm, 0) * COALESCE(cbc.qty_value, 1))
        FROM "BOMComponents" cbc
        JOIN "CatalogItems" cci ON cci.id = cbc.component_item_id
        WHERE cbc.parent_component_id = bc.id AND cbc.deleted = false
      ), 0) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.bom_template_id = v_cp.bt_id
      AND bc.deleted = false
      AND bc.affects_role = 'tube'
      AND bc.parent_component_id IS NULL
      AND COALESCE(bc.qty_type::text, 'fixed') != 'per_joint'
    UNION ALL
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE v_target_comp_id IS NOT NULL
      AND bc.parent_component_id = v_target_comp_id
      AND bc.deleted = false
  ) ed;

  -- Joint delta: affecting parents with per_joint + their children
  SELECT -1.0 * COALESCE(SUM(delta_val), 0)
  INTO v_joint_delta
  FROM (
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1)
      + COALESCE((
        SELECT SUM(COALESCE(cci.delta_x_mm, 0) * COALESCE(cbc.qty_value, 1))
        FROM "BOMComponents" cbc
        JOIN "CatalogItems" cci ON cci.id = cbc.component_item_id
        WHERE cbc.parent_component_id = bc.id AND cbc.deleted = false
      ), 0) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.bom_template_id = v_cp.bt_id
      AND bc.deleted = false
      AND bc.affects_role = 'tube'
      AND bc.parent_component_id IS NULL
      AND bc.qty_type::text = 'per_joint'
  ) jd;

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
  SELECT bc.id INTO v_target_comp_id
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false
    AND bc.component_role = 'bottom_bar'
    AND bc.parent_component_id IS NULL
  LIMIT 1;

  SELECT -1.0 * COALESCE(SUM(delta_val), 0)
  INTO v_endpoint_delta
  FROM (
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1)
      + COALESCE((
        SELECT SUM(COALESCE(cci.delta_x_mm, 0) * COALESCE(cbc.qty_value, 1))
        FROM "BOMComponents" cbc
        JOIN "CatalogItems" cci ON cci.id = cbc.component_item_id
        WHERE cbc.parent_component_id = bc.id AND cbc.deleted = false
      ), 0) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.bom_template_id = v_cp.bt_id
      AND bc.deleted = false
      AND bc.affects_role = 'bottom_bar'
      AND bc.parent_component_id IS NULL
      AND COALESCE(bc.qty_type::text, 'fixed') != 'per_joint'
    UNION ALL
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE v_target_comp_id IS NOT NULL
      AND bc.parent_component_id = v_target_comp_id
      AND bc.deleted = false
  ) ed;

  SELECT -1.0 * COALESCE(SUM(delta_val), 0)
  INTO v_joint_delta
  FROM (
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1)
      + COALESCE((
        SELECT SUM(COALESCE(cci.delta_x_mm, 0) * COALESCE(cbc.qty_value, 1))
        FROM "BOMComponents" cbc
        JOIN "CatalogItems" cci ON cci.id = cbc.component_item_id
        WHERE cbc.parent_component_id = bc.id AND cbc.deleted = false
      ), 0) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.bom_template_id = v_cp.bt_id
      AND bc.deleted = false
      AND bc.affects_role = 'bottom_bar'
      AND bc.parent_component_id IS NULL
      AND bc.qty_type::text = 'per_joint'
  ) jd;

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
  SELECT -1.0 * COALESCE(SUM(delta_val), 0)
  INTO v_delta_sum
  FROM (
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1)
      + COALESCE((
        SELECT SUM(COALESCE(cci.delta_x_mm, 0) * COALESCE(cbc.qty_value, 1))
        FROM "BOMComponents" cbc
        JOIN "CatalogItems" cci ON cci.id = cbc.component_item_id
        WHERE cbc.parent_component_id = bc.id AND cbc.deleted = false
      ), 0) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.bom_template_id = v_cp.bt_id
      AND bc.deleted = false
      AND bc.affects_role = 'track'
      AND bc.parent_component_id IS NULL
  ) td;

  v_result := v_result || jsonb_build_object(
    'track_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
  );

  -- ===== HEADBOX / FASCIA =====
  SELECT -1.0 * COALESCE(SUM(delta_val), 0)
  INTO v_delta_sum
  FROM (
    SELECT
      COALESCE(ci.delta_x_mm, 0) * COALESCE(bc.qty_value, 1)
      + COALESCE((
        SELECT SUM(COALESCE(cci.delta_x_mm, 0) * COALESCE(cbc.qty_value, 1))
        FROM "BOMComponents" cbc
        JOIN "CatalogItems" cci ON cci.id = cbc.component_item_id
        WHERE cbc.parent_component_id = bc.id AND cbc.deleted = false
      ), 0) as delta_val
    FROM "BOMComponents" bc
    JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.bom_template_id = v_cp.bt_id
      AND bc.deleted = false
      AND bc.affects_role = 'headbox'
      AND bc.parent_component_id IS NULL
  ) hd;

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
