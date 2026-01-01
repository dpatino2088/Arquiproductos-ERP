-- ====================================================
-- Migration: Add UOM to BOM Components and Quote Line Components
-- ====================================================
-- Ensures UOM is pre-established at BOM creation time
-- Valid UOMs: m, y, m2, y2, und, pcs, ea, set, pack
-- ====================================================

-- Step 1: Add constraint to BOMComponents.uom to validate allowed UOMs
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_bomcomponents_uom_valid'
        AND conrelid = 'public."BOMComponents"'::regclass
    ) THEN
        ALTER TABLE "BOMComponents" DROP CONSTRAINT check_bomcomponents_uom_valid;
    END IF;
    
    -- Add constraint for valid UOMs
    ALTER TABLE "BOMComponents"
    ADD CONSTRAINT check_bomcomponents_uom_valid 
    CHECK (uom IN ('mts', 'yd', 'ft', 'und', 'pcs', 'ea', 'set', 'pack', 'm2', 'yd2'));
    
    RAISE NOTICE '✅ Added UOM validation constraint to BOMComponents';
END $$;

-- Step 2: Add uom column to QuoteLineComponents if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'uom'
    ) THEN
        ALTER TABLE "QuoteLineComponents"
        ADD COLUMN uom text;
        
        RAISE NOTICE '✅ Added uom column to QuoteLineComponents';
    ELSE
        RAISE NOTICE '⏭️  uom column already exists in QuoteLineComponents';
    END IF;
END $$;

-- Step 3: Add constraint to QuoteLineComponents.uom to validate allowed UOMs
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_quote_line_components_uom_valid'
        AND conrelid = 'public."QuoteLineComponents"'::regclass
    ) THEN
        ALTER TABLE "QuoteLineComponents" DROP CONSTRAINT check_quote_line_components_uom_valid;
    END IF;
    
    -- Add constraint for valid UOMs (allows NULL for backward compatibility)
    ALTER TABLE "QuoteLineComponents"
    ADD CONSTRAINT check_quote_line_components_uom_valid 
    CHECK (uom IS NULL OR uom IN ('mts', 'yd', 'ft', 'und', 'pcs', 'ea', 'set', 'pack', 'm2', 'yd2'));
    
    RAISE NOTICE '✅ Added UOM validation constraint to QuoteLineComponents';
END $$;

-- Step 4: Update existing QuoteLineComponents to set UOM based on component_role (for backward compatibility)
-- This sets UOM for existing records, but new records should use UOM from BOMComponents
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    UPDATE "QuoteLineComponents" qlc
    SET uom = CASE
        WHEN qlc.component_role LIKE '%tube%' OR 
             qlc.component_role LIKE '%rail%' OR 
             qlc.component_role LIKE '%profile%' OR 
             qlc.component_role LIKE '%cassette%' OR
             qlc.component_role LIKE '%channel%' THEN 'mts'
        WHEN qlc.component_role LIKE '%fabric%' THEN 'm2'
        ELSE 'ea'
    END
    WHERE qlc.uom IS NULL
    AND qlc.deleted = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % existing QuoteLineComponents records with inferred UOM', v_updated_count;
END $$;

-- Step 5: Add comment explaining UOM usage
COMMENT ON COLUMN "QuoteLineComponents".uom IS 
    'Unit of Measure for the component quantity. Must match the UOM from BOMComponents. Valid values: mts (meters), yd (yards), ft (feet), m2 (square meters), yd2 (square yards), und (unit), pcs (pieces), ea (each), set, pack';

COMMENT ON COLUMN "BOMComponents".uom IS 
    'Unit of Measure for qty_per_unit. Must be one of: mts, yd, ft, m2, yd2, und, pcs, ea, set, pack. This UOM is copied to QuoteLineComponents when BOM is generated.';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration complete: UOM validation and QuoteLineComponents.uom column added';
    RAISE NOTICE '   Valid UOMs: mts, yd, ft, und, pcs, ea, set, pack, m2, yd2';
    RAISE NOTICE '   Next: Update generate_configured_bom_for_quote_line to use BOMComponents.uom';
END $$;

