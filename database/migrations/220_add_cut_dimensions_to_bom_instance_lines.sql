-- ====================================================
-- Migration 220: Add cut dimensions columns to BomInstanceLines
-- ====================================================
-- La función apply_engineering_rules_to_bom_instance necesita estas columnas
-- pero no estaban creadas en la tabla
-- ====================================================

BEGIN;

DO $$
BEGIN
    -- Add cut_length_mm column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_length_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN cut_length_mm numeric(10,2);
        
        COMMENT ON COLUMN "BomInstanceLines".cut_length_mm IS 
            'Calculated cut length in millimeters. Computed by apply_engineering_rules_to_bom_instance based on quote dimensions and engineering rules.';
        
        RAISE NOTICE '✅ Added cut_length_mm to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  cut_length_mm already exists in BomInstanceLines';
    END IF;
    
    -- Add cut_width_mm column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_width_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN cut_width_mm numeric(10,2);
        
        COMMENT ON COLUMN "BomInstanceLines".cut_width_mm IS 
            'Calculated cut width in millimeters. Computed by apply_engineering_rules_to_bom_instance based on quote dimensions and engineering rules.';
        
        RAISE NOTICE '✅ Added cut_width_mm to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  cut_width_mm already exists in BomInstanceLines';
    END IF;
    
    -- Add cut_height_mm column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_height_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN cut_height_mm numeric(10,2);
        
        COMMENT ON COLUMN "BomInstanceLines".cut_height_mm IS 
            'Calculated cut height in millimeters. Computed by apply_engineering_rules_to_bom_instance based on quote dimensions and engineering rules.';
        
        RAISE NOTICE '✅ Added cut_height_mm to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  cut_height_mm already exists in BomInstanceLines';
    END IF;
    
    -- Verify calc_notes exists (should already exist from migration 200)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'calc_notes'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN calc_notes text;
        
        COMMENT ON COLUMN "BomInstanceLines".calc_notes IS 
            'Calculation notes explaining how cut dimensions were derived.';
        
        RAISE NOTICE '✅ Added calc_notes to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  calc_notes already exists in BomInstanceLines';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 220 completed: Cut dimensions columns added';
END $$;

COMMIT;




