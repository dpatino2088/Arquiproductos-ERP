-- ====================================================
-- ADD: unit_kind column to CatalogItems
-- ====================================================
-- This splits measure_basis='unit' into two behaviors:
-- A) Dimensional Unit: affects dimensions via EngineeringRules
-- B) Consumable Unit: does NOT affect dimensions, only adds BOM lines
-- ====================================================

-- Step 1: Add unit_kind column (nullable first for existing data)
ALTER TABLE "CatalogItems"
ADD COLUMN IF NOT EXISTS unit_kind text;

-- Step 2: Set default value for existing rows
-- All existing unit items default to 'consumable' (safe default)
UPDATE "CatalogItems"
SET unit_kind = 'consumable'
WHERE measure_basis = 'unit'
AND unit_kind IS NULL;

-- Step 3: Set unit_kind for non-unit items (for clarity, though not strictly needed)
UPDATE "CatalogItems"
SET unit_kind = NULL
WHERE measure_basis != 'unit'
AND unit_kind IS NULL;

-- Step 4: Add CHECK constraint
ALTER TABLE "CatalogItems"
DROP CONSTRAINT IF EXISTS chk_catalogitems_unit_kind;

ALTER TABLE "CatalogItems"
ADD CONSTRAINT chk_catalogitems_unit_kind 
    CHECK (
        (measure_basis != 'unit' AND unit_kind IS NULL) OR
        (measure_basis = 'unit' AND unit_kind IN ('dimensional', 'consumable'))
    );

-- Step 5: Set NOT NULL with default (after data is populated)
ALTER TABLE "CatalogItems"
ALTER COLUMN unit_kind SET DEFAULT 'consumable';

-- Note: We keep it nullable for non-unit items to avoid confusion
-- Only unit items require unit_kind

-- Step 6: Add comment
COMMENT ON COLUMN "CatalogItems".unit_kind IS 
'For measure_basis=''unit'' items only. 
- ''dimensional'': affects dimensions of other roles via EngineeringRules
- ''consumable'': does NOT affect dimensions, only adds BOM lines (qty).
NULL for non-unit items.';

-- Step 7: Create index for performance (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_catalogitems_unit_kind 
ON "CatalogItems"(unit_kind) 
WHERE measure_basis = 'unit' AND deleted = false;

-- Step 8: Verification query
DO $$
DECLARE
    v_unit_count integer;
    v_dimensional_count integer;
    v_consumable_count integer;
    v_null_unit_kind_count integer;
BEGIN
    SELECT COUNT(*) INTO v_unit_count
    FROM "CatalogItems"
    WHERE measure_basis = 'unit' AND deleted = false;
    
    SELECT COUNT(*) INTO v_dimensional_count
    FROM "CatalogItems"
    WHERE measure_basis = 'unit' AND unit_kind = 'dimensional' AND deleted = false;
    
    SELECT COUNT(*) INTO v_consumable_count
    FROM "CatalogItems"
    WHERE measure_basis = 'unit' AND unit_kind = 'consumable' AND deleted = false;
    
    SELECT COUNT(*) INTO v_null_unit_kind_count
    FROM "CatalogItems"
    WHERE measure_basis = 'unit' AND unit_kind IS NULL AND deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ unit_kind column added successfully!';
    RAISE NOTICE '📊 Statistics:';
    RAISE NOTICE '   - Total unit items: %', v_unit_count;
    RAISE NOTICE '   - Dimensional units: %', v_dimensional_count;
    RAISE NOTICE '   - Consumable units: %', v_consumable_count;
    RAISE NOTICE '   - NULL unit_kind (should be 0): %', v_null_unit_kind_count;
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Next steps:';
    RAISE NOTICE '   1. Review unit items and set unit_kind = ''dimensional'' for items that affect dimensions';
    RAISE NOTICE '   2. Keep unit_kind = ''consumable'' for items that only add BOM lines';
    RAISE NOTICE '   3. Update resolve_dimensional_adjustments() to filter by unit_kind';
    RAISE NOTICE '';
END $$;






