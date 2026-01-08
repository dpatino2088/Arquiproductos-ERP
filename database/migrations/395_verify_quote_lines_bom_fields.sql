-- ====================================================
-- Migration 395: Verify QuoteLines BOM Configuration Fields
-- ====================================================
-- This migration ensures that QuoteLines has all required columns
-- for BOM-driven configurator: hardware_color, cassette, side_channel, 
-- drive_type, bom_template_id
-- ====================================================

DO $$
DECLARE
    v_col_exists boolean;
BEGIN
    RAISE NOTICE '🔧 Verifying QuoteLines BOM configuration fields...';

    -- ====================================================
    -- STEP 1: hardware_color (text, nullable)
    -- ====================================================
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLines'
        AND column_name = 'hardware_color'
    ) INTO v_col_exists;

    IF NOT v_col_exists THEN
        ALTER TABLE public."QuoteLines" 
            ADD COLUMN hardware_color TEXT;
        
        COMMENT ON COLUMN public."QuoteLines".hardware_color IS 
            'Hardware color selected by user: white, black, silver, bronze, grey, beige. Used for BOM auto-select SKU resolution.';
        
        RAISE NOTICE '✅ Added hardware_color column to QuoteLines';
    ELSE
        RAISE NOTICE 'ℹ️  Column hardware_color already exists in QuoteLines';
    END IF;

    -- ====================================================
    -- STEP 2: cassette (boolean, default false)
    -- ====================================================
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLines'
        AND column_name = 'cassette'
    ) INTO v_col_exists;

    IF NOT v_col_exists THEN
        ALTER TABLE public."QuoteLines" 
            ADD COLUMN cassette BOOLEAN DEFAULT false;
        
        COMMENT ON COLUMN public."QuoteLines".cassette IS 
            'Whether cassette is enabled for this quote line. Used for BOM block_condition evaluation.';
        
        RAISE NOTICE '✅ Added cassette column to QuoteLines';
    ELSE
        RAISE NOTICE 'ℹ️  Column cassette already exists in QuoteLines';
    END IF;

    -- ====================================================
    -- STEP 3: side_channel (boolean, default false)
    -- ====================================================
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLines'
        AND column_name = 'side_channel'
    ) INTO v_col_exists;

    IF NOT v_col_exists THEN
        ALTER TABLE public."QuoteLines" 
            ADD COLUMN side_channel BOOLEAN DEFAULT false;
        
        COMMENT ON COLUMN public."QuoteLines".side_channel IS 
            'Whether side channel is enabled for this quote line. Used for BOM block_condition evaluation.';
        
        RAISE NOTICE '✅ Added side_channel column to QuoteLines';
    ELSE
        RAISE NOTICE 'ℹ️  Column side_channel already exists in QuoteLines';
    END IF;

    -- ====================================================
    -- STEP 4: drive_type (text, nullable)
    -- ====================================================
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLines'
        AND column_name = 'drive_type'
    ) INTO v_col_exists;

    IF NOT v_col_exists THEN
        ALTER TABLE public."QuoteLines" 
            ADD COLUMN drive_type TEXT;
        
        COMMENT ON COLUMN public."QuoteLines".drive_type IS 
            'Drive type: manual or motor. Used for BOM block_condition evaluation and auto-select SKU resolution.';
        
        RAISE NOTICE '✅ Added drive_type column to QuoteLines';
    ELSE
        RAISE NOTICE 'ℹ️  Column drive_type already exists in QuoteLines';
    END IF;

    -- ====================================================
    -- STEP 5: bom_template_id (uuid FK to BOMTemplates, nullable)
    -- ====================================================
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLines'
        AND column_name = 'bom_template_id'
    ) INTO v_col_exists;

    IF NOT v_col_exists THEN
        ALTER TABLE public."QuoteLines" 
            ADD COLUMN bom_template_id UUID;
        
        -- Create foreign key if BOMTemplates table exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'BOMTemplates'
        ) THEN
            ALTER TABLE public."QuoteLines"
                ADD CONSTRAINT fk_quote_lines_bom_template
                FOREIGN KEY (bom_template_id)
                REFERENCES public."BOMTemplates"(id)
                ON DELETE SET NULL;
            
            RAISE NOTICE '✅ Created foreign key fk_quote_lines_bom_template';
        ELSE
            RAISE NOTICE '⚠️  BOMTemplates table does not exist, skipping FK constraint';
        END IF;
        
        COMMENT ON COLUMN public."QuoteLines".bom_template_id IS 
            'Foreign key to BOMTemplates. Identifies which BOM template should be used for BOM generation.';
        
        RAISE NOTICE '✅ Added bom_template_id column to QuoteLines';
    ELSE
        RAISE NOTICE 'ℹ️  Column bom_template_id already exists in QuoteLines';
    END IF;

    -- ====================================================
    -- STEP 6: Create indexes for efficient queries
    -- ====================================================
    CREATE INDEX IF NOT EXISTS idx_quote_lines_bom_template_id 
        ON public."QuoteLines"(bom_template_id) 
        WHERE bom_template_id IS NOT NULL;
    
    RAISE NOTICE '✅ Created/verified index idx_quote_lines_bom_template_id';

    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 395 completed successfully!';
    RAISE NOTICE '📝 QuoteLines now has all required BOM configuration fields.';

END $$;


