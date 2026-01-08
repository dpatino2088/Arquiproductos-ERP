-- ====================================================
-- Migration: Fix qty_type and Required Fields for Auto-Select Components
-- ====================================================
-- Template: 184658a6-f6af-4199-bea2-44d29e6a88dc
-- ====================================================
-- Objectives:
-- 1) Fix qty_type to valid enum values (lowercase only)
-- 2) Ensure sku_resolution_rule is NOT NULL for auto-select
-- 3) Ensure uom is NOT NULL for auto-select
-- 4) Apply role-based defaults
-- ====================================================

DO $$
DECLARE
  v_template_id uuid := '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid;
  v_updated_count int := 0;
BEGIN
  -- 0) Confirmación rápida del template
  IF NOT EXISTS (
    SELECT 1 FROM "BOMTemplates"
    WHERE id = v_template_id
    AND deleted = false
  ) THEN
    RAISE EXCEPTION 'BOMTemplate % not found or deleted', v_template_id;
  END IF;
  
  RAISE NOTICE '✅ Fixing auto-select components for template: %', v_template_id;
  
  -- 1) tube -> qty_type='per_width', sku_resolution_rule='CATEGORY_FIRST_MATCH', uom='m'
  UPDATE "BOMComponents"
  SET 
    qty_type = 'per_width'::bom_qty_type,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = COALESCE(NULLIF(uom, ''), NULLIF(uom, 'ft'), 'm'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'tube'
    AND (auto_select = true OR component_item_id IS NULL)
    AND (
      qty_type IS NULL 
      OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area')
      OR sku_resolution_rule IS NULL
      OR uom IS NULL
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % tube components: qty_type=per_width, sku_resolution_rule=CATEGORY_FIRST_MATCH, uom=m', v_updated_count;
  END IF;
  
  -- 2) fabric -> sku_resolution_rule='CATEGORY_FIRST_MATCH' (if null), qty_type='per_area', uom='m2'
  UPDATE "BOMComponents"
  SET 
    qty_type = 'per_area'::bom_qty_type,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = COALESCE(NULLIF(uom, ''), NULLIF(uom, 'ft'), 'm2'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'fabric'
    AND (auto_select = true OR component_item_id IS NULL)
    AND (
      qty_type IS NULL 
      OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area')
      OR sku_resolution_rule IS NULL
      OR uom IS NULL
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % fabric components: qty_type=per_area, sku_resolution_rule=CATEGORY_FIRST_MATCH, uom=m2', v_updated_count;
  END IF;
  
  -- 3) end_cap, drive_manual, bracket -> sku_resolution_rule='ROLE_AND_COLOR' (if null), qty_type='fixed', uom='ea'
  UPDATE "BOMComponents"
  SET 
    qty_type = 'fixed'::bom_qty_type,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'ROLE_AND_COLOR'
    ),
    uom = COALESCE(NULLIF(uom, ''), NULLIF(uom, 'ft'), 'ea'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role IN ('end_cap', 'drive_manual', 'bracket')
    AND (auto_select = true OR component_item_id IS NULL)
    AND (
      qty_type IS NULL 
      OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area')
      OR sku_resolution_rule IS NULL
      OR uom IS NULL
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % components (end_cap/drive_manual/bracket): qty_type=fixed, sku_resolution_rule=ROLE_AND_COLOR, uom=ea', v_updated_count;
  END IF;
  
  -- 4) Other auto-select roles: default to fixed
  UPDATE "BOMComponents"
  SET 
    qty_type = COALESCE(
      CASE 
        WHEN qty_type::text IN ('fixed', 'per_width', 'per_area') THEN qty_type::bom_qty_type
        ELSE 'fixed'::bom_qty_type
      END,
      'fixed'::bom_qty_type
    ),
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = COALESCE(NULLIF(uom, ''), NULLIF(uom, 'ft'), 'ea'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND (auto_select = true OR component_item_id IS NULL)
    AND component_role NOT IN ('tube', 'fabric', 'end_cap', 'drive_manual', 'bracket')
    AND (
      qty_type IS NULL 
      OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area')
      OR sku_resolution_rule IS NULL
      OR uom IS NULL
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % other auto-select components: defaults applied', v_updated_count;
  END IF;
  
  RAISE NOTICE '✅ Data fix completed for template: %', v_template_id;
  
END $$;

-- ====================================================
-- Verification Query
-- ====================================================
SELECT 
  component_role, 
  auto_select, 
  sku_resolution_rule, 
  qty_type, 
  uom,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
GROUP BY component_role, auto_select, sku_resolution_rule, qty_type, uom
ORDER BY component_role, auto_select DESC;

-- ====================================================
-- Blocker Query: Check for Invalid Auto-Select Components
-- ====================================================
SELECT COUNT(*) as invalid_autoselect
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
  AND auto_select = true
  AND (sku_resolution_rule IS NULL OR qty_type IS NULL OR uom IS NULL);

-- Expected result: 0 (all auto-select components should have required fields)


