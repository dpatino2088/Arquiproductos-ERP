-- ====================================================
-- Migration: Fix UOM normalization, Cut fields, and Formula
-- ====================================================
-- Problem 1: UOM comes from CatalogItems.uom instead of BOMComponents.uom
-- Problem 2: cut_l_mm is not populated for linear components
-- Problem 3: CHAIN_HEIGHT_FACTOR formula needs verification
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Add cut fields to BomInstanceLines (if they don't exist)
-- ====================================================
DO $$
BEGIN
    -- Add cut_l_mm (cut length in millimeters)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_l_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_l_mm numeric(10,2);
        RAISE NOTICE '✅ Added column cut_l_mm to BomInstanceLines';
    ELSE
        RAISE NOTICE '⚠️  Column cut_l_mm already exists';
    END IF;
    
    -- Add cut_w_mm (cut width in millimeters)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_w_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_w_mm numeric(10,2);
        RAISE NOTICE '✅ Added column cut_w_mm to BomInstanceLines';
    ELSE
        RAISE NOTICE '⚠️  Column cut_w_mm already exists';
    END IF;
    
    -- Add cut_h_mm (cut height in millimeters)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_h_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_h_mm numeric(10,2);
        RAISE NOTICE '✅ Added column cut_h_mm to BomInstanceLines';
    ELSE
        RAISE NOTICE '⚠️  Column cut_h_mm already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Update generate_bom_for_manufacturing_order function
-- ====================================================
-- This will be done in a separate step after verifying the function structure
-- For now, we'll create a helper comment

COMMENT ON COLUMN "BomInstanceLines".cut_l_mm IS 
    'Cut length in millimeters. Populated for linear components (qty_type=per_width) based on configured width_mm.';

COMMENT ON COLUMN "BomInstanceLines".cut_w_mm IS 
    'Cut width in millimeters. Populated for area-based components if applicable.';

COMMENT ON COLUMN "BomInstanceLines".cut_h_mm IS 
    'Cut height in millimeters. Populated for area-based components if applicable.';


