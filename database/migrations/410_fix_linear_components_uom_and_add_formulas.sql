-- ====================================================
-- Migration: Fix Linear Components UOM + Add Formula Support
-- ====================================================
-- Template: 184658a6-f6af-4199-bea2-44d29e6a88dc
-- ====================================================
-- Objectives:
-- 1) Fix bottom_bar + bottom_rail: auto_select=true, qty_type='per_width', uom='m'
-- 2) Ensure tube: auto_select=true, qty_type='per_width', uom='m'
-- 3) Ensure fabric: auto_select=true, qty_type='per_area', uom='m2'
-- 4) Add formula support columns (qty_formula_code, qty_formula_params)
-- 5) Set chain formula: CHAIN_HEIGHT_FACTOR
-- 6) Update constraint to allow qty_formula_code as alternative to qty_type
-- ====================================================

-- ====================================================
-- STEP 0: Drop existing constraint (will be recreated with formula support)
-- ====================================================
ALTER TABLE "BOMComponents"
DROP CONSTRAINT IF EXISTS bomcomponents_autoselect_required_fields;

-- ====================================================
-- STEP 1: Add Formula Support Columns
-- ====================================================

-- Add qty_formula_code column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'qty_formula_code'
    ) THEN
        ALTER TABLE "BOMComponents"
        ADD COLUMN qty_formula_code text;
        
        COMMENT ON COLUMN "BOMComponents".qty_formula_code IS 
            'Formula code for calculating quantity (e.g., CHAIN_HEIGHT_FACTOR). If NULL, use qty_type logic.';
    END IF;
END $$;

-- Add qty_formula_params column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'qty_formula_params'
    ) THEN
        ALTER TABLE "BOMComponents"
        ADD COLUMN qty_formula_params jsonb;
        
        COMMENT ON COLUMN "BOMComponents".qty_formula_params IS 
            'JSON parameters for qty_formula_code (e.g., {"height_factor":0.75,"mult":2} for CHAIN_HEIGHT_FACTOR).';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Data Fix for Template 184658a6-f6af-4199-bea2-44d29e6a88dc
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
  
  RAISE NOTICE '✅ Fixing linear components UOM for template: %', v_template_id;
  
  -- 1) bottom_bar + bottom_rail: auto_select=true, qty_type='per_width', uom='m', sku_resolution_rule='CATEGORY_FIRST_MATCH', component_item_id=NULL
  UPDATE "BOMComponents"
  SET 
    auto_select = true,
    component_item_id = NULL,
    qty_type = 'per_width'::bom_qty_type,
    qty_formula_code = NULL, -- Clear formula if exists (use qty_type instead)
    qty_formula_params = NULL,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = 'm',
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role IN ('bottom_bar', 'bottom_rail')
    AND (
      auto_select != true
      OR component_item_id IS NOT NULL
      OR qty_type::text != 'per_width'
      OR uom != 'm'
      OR sku_resolution_rule IS NULL
      OR TRIM(sku_resolution_rule) = ''
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % bottom_bar/bottom_rail components: auto_select=true, qty_type=per_width, uom=m', v_updated_count;
  END IF;
  
  -- 2) tube: auto_select=true, qty_type='per_width', uom='m'
  UPDATE "BOMComponents"
  SET 
    auto_select = true,
    component_item_id = NULL,
    qty_type = 'per_width'::bom_qty_type,
    qty_formula_code = NULL, -- Clear formula if exists (use qty_type instead)
    qty_formula_params = NULL,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = 'm',
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'tube'
    AND (
      auto_select != true
      OR component_item_id IS NOT NULL
      OR qty_type::text != 'per_width'
      OR uom != 'm'
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % tube components: auto_select=true, qty_type=per_width, uom=m', v_updated_count;
  END IF;
  
  -- 3) fabric: auto_select=true, qty_type='per_area', uom='m2'
  UPDATE "BOMComponents"
  SET 
    auto_select = true,
    component_item_id = NULL,
    qty_type = 'per_area'::bom_qty_type,
    qty_formula_code = NULL, -- Clear formula if exists (use qty_type instead)
    qty_formula_params = NULL,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = 'm2',
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'fabric'
    AND (
      auto_select != true
      OR component_item_id IS NOT NULL
      OR qty_type::text != 'per_area'
      OR uom != 'm2'
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % fabric components: auto_select=true, qty_type=per_area, uom=m2', v_updated_count;
  END IF;
  
  -- 4) chain: Set formula CHAIN_HEIGHT_FACTOR
  UPDATE "BOMComponents"
  SET 
    auto_select = true,
    component_item_id = NULL,
    qty_type = NULL, -- Formula overrides qty_type
    qty_formula_code = 'CHAIN_HEIGHT_FACTOR',
    qty_formula_params = '{"height_factor":0.75,"mult":2}'::jsonb,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH'
    ),
    uom = 'm',
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'chain'
    AND (
      qty_formula_code IS NULL
      OR qty_formula_code != 'CHAIN_HEIGHT_FACTOR'
      OR qty_formula_params IS NULL
      OR uom != 'm'
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed % chain components: formula=CHAIN_HEIGHT_FACTOR, uom=m', v_updated_count;
  END IF;
  
  -- 5) Ensure auto_select never uses qty_type='fixed' (convert to per_width or per_area based on role)
  UPDATE "BOMComponents"
  SET 
    qty_type = CASE 
      WHEN component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'chain') THEN 'per_width'::bom_qty_type
      WHEN component_role = 'fabric' THEN 'per_area'::bom_qty_type
      ELSE qty_type -- Keep existing for other roles
    END,
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND auto_select = true
    AND qty_type::text = 'fixed'
    AND qty_formula_code IS NULL; -- Only if no formula is set
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Converted % auto_select components from fixed to per_width/per_area', v_updated_count;
  END IF;
  
  RAISE NOTICE '✅ Data fix completed for template: %', v_template_id;
  
END $$;

-- ====================================================
-- STEP 3: Create CatalogItemBOMLines Table (Assemblies)
-- ====================================================
-- ✅ FIX: Check if table already exists before creating

DO $$
BEGIN
    -- Check if CatalogItemBOMLines already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'CatalogItemBOMLines'
    ) THEN
        -- Check if CatalogItemChildrenBOM exists (alternative name)
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'CatalogItemChildrenBOM'
        ) THEN
            RAISE NOTICE '⚠️  CatalogItemChildrenBOM exists. Please rename to CatalogItemBOMLines or update code to use CatalogItemChildrenBOM.';
        ELSE
            -- Create CatalogItemBOMLines
            CREATE TABLE "CatalogItemBOMLines" (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                parent_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
                child_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
                qty numeric(12,4) NOT NULL DEFAULT 1,
                uom text NOT NULL DEFAULT 'ea',
                sequence_order integer DEFAULT 0,
                organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
                deleted boolean NOT NULL DEFAULT false,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now()
            );
            
            -- Create unique index with WHERE clause (partial index)
            CREATE UNIQUE INDEX uq_catalog_item_bom_lines_parent_child 
            ON "CatalogItemBOMLines"(parent_item_id, child_item_id, uom) 
            WHERE deleted = false;

            CREATE INDEX IF NOT EXISTS idx_catalog_item_bom_lines_parent ON "CatalogItemBOMLines"(parent_item_id) WHERE deleted = false;
            CREATE INDEX IF NOT EXISTS idx_catalog_item_bom_lines_child ON "CatalogItemBOMLines"(child_item_id) WHERE deleted = false;
            CREATE INDEX IF NOT EXISTS idx_catalog_item_bom_lines_org ON "CatalogItemBOMLines"(organization_id) WHERE deleted = false;
            
            RAISE NOTICE '✅ Created CatalogItemBOMLines table';
        END IF;
    ELSE
        RAISE NOTICE '✅ CatalogItemBOMLines table already exists, skipping creation';
    END IF;
END $$;

-- Add comments only if table was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'CatalogItemBOMLines'
    ) THEN
        COMMENT ON TABLE "CatalogItemBOMLines" IS 
            'Defines child components (assemblies) for parent CatalogItems. When a BOM line resolves to a parent_item_id, expand its children and insert additional BomInstanceLines.';

        COMMENT ON COLUMN "CatalogItemBOMLines".parent_item_id IS 
            'The parent CatalogItem (assembly) that contains child components.';

        COMMENT ON COLUMN "CatalogItemBOMLines".child_item_id IS 
            'The child CatalogItem that is part of the parent assembly.';

        COMMENT ON COLUMN "CatalogItemBOMLines".qty IS 
            'Quantity of child_item per parent_item (e.g., 2 brackets per assembly).';

        COMMENT ON COLUMN "CatalogItemBOMLines".uom IS 
            'Unit of measure for qty (e.g., ea, m, m2).';
    END IF;
END $$;

-- ====================================================
-- Verification Query
-- ====================================================
SELECT 
  component_role, 
  auto_select, 
  component_item_id IS NOT NULL as is_fixed,
  qty_type, 
  qty_formula_code,
  qty_formula_params,
  sku_resolution_rule, 
  uom,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
GROUP BY component_role, auto_select, component_item_id IS NOT NULL, qty_type, qty_formula_code, qty_formula_params, sku_resolution_rule, uom
ORDER BY component_role, auto_select DESC, is_fixed DESC;

-- ====================================================
-- Blocker Query: Check for Invalid Auto-Select Components
-- ====================================================
SELECT COUNT(*) as invalid_autoselect
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
  AND auto_select = true
  AND (
    sku_resolution_rule IS NULL 
    OR TRIM(sku_resolution_rule) = ''
    OR (qty_type IS NULL AND qty_formula_code IS NULL)
    OR uom IS NULL
    OR TRIM(uom) = ''
  );

-- Expected result: 0 (all auto-select components should have required fields)

-- ====================================================
-- STEP 4: Fix Invalid Auto-Select Components (Before Adding Constraint)
-- ====================================================
-- ✅ FIX: Correct any auto-select components that violate the constraint
-- This ensures the constraint can be added without errors

DO $$
DECLARE
  v_fixed_count int := 0;
BEGIN
  -- Fix auto-select components missing sku_resolution_rule
  UPDATE "BOMComponents"
  SET 
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      'CATEGORY_FIRST_MATCH' -- Default resolution rule
    ),
    updated_at = now()
  WHERE auto_select = true
    AND (sku_resolution_rule IS NULL OR TRIM(sku_resolution_rule) = '');
  
  GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
  IF v_fixed_count > 0 THEN
    RAISE NOTICE '✅ Fixed % auto-select components missing sku_resolution_rule', v_fixed_count;
  END IF;
  
  -- Fix auto-select components missing both qty_type and qty_formula_code
  UPDATE "BOMComponents"
  SET 
    qty_type = CASE 
      WHEN component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'chain') THEN 'per_width'::bom_qty_type
      WHEN component_role = 'fabric' THEN 'per_area'::bom_qty_type
      WHEN component_role IN ('bracket', 'end_cap', 'hardware') THEN 'fixed'::bom_qty_type
      ELSE 'fixed'::bom_qty_type -- Default
    END,
    updated_at = now()
  WHERE auto_select = true
    AND qty_type IS NULL
    AND qty_formula_code IS NULL;
  
  GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
  IF v_fixed_count > 0 THEN
    RAISE NOTICE '✅ Fixed % auto-select components missing qty_type/qty_formula_code', v_fixed_count;
  END IF;
  
  -- Fix auto-select components missing uom
  UPDATE "BOMComponents"
  SET 
    uom = CASE 
      WHEN component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'chain') THEN 'm'
      WHEN component_role = 'fabric' THEN 'm2'
      ELSE 'ea' -- Default
    END,
    updated_at = now()
  WHERE auto_select = true
    AND (uom IS NULL OR TRIM(uom) = '');
  
  GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
  IF v_fixed_count > 0 THEN
    RAISE NOTICE '✅ Fixed % auto-select components missing uom', v_fixed_count;
  END IF;
  
  RAISE NOTICE '✅ Data cleanup completed before adding constraint';
END $$;

-- ====================================================
-- STEP 5: Recreate Constraint with Formula Support
-- ====================================================
-- ✅ FIX: Drop constraint if it exists (in case of re-run)
ALTER TABLE "BOMComponents"
DROP CONSTRAINT IF EXISTS bomcomponents_autoselect_required_fields;

ALTER TABLE "BOMComponents"
ADD CONSTRAINT bomcomponents_autoselect_required_fields
CHECK (
  auto_select IS NOT TRUE
  OR (
    sku_resolution_rule IS NOT NULL
    AND (qty_type IS NOT NULL OR qty_formula_code IS NOT NULL)
    AND uom IS NOT NULL
    AND uom != ''
  )
);

COMMENT ON CONSTRAINT bomcomponents_autoselect_required_fields ON "BOMComponents" IS 
  'Ensures auto-select components have required fields: sku_resolution_rule, (qty_type OR qty_formula_code), and uom must not be NULL or empty.';

