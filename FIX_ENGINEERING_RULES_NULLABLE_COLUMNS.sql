-- ====================================================
-- FIX: EngineeringRules nullable columns
-- ====================================================
-- This script fixes the issue where columns cannot be added as NOT NULL
-- when the table already has rows
-- ====================================================

-- Check if EngineeringRules table exists and has rows
DO $$
DECLARE
    v_table_exists boolean;
    v_row_count integer;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        SELECT COUNT(*) INTO v_row_count FROM "EngineeringRules";
        
        IF v_row_count > 0 THEN
            RAISE NOTICE '⚠️ EngineeringRules has % existing rows', v_row_count;
            RAISE NOTICE '   Columns will be added as nullable first';
            RAISE NOTICE '   After updating existing rows, run: ALTER TABLE "EngineeringRules" ALTER COLUMN <column> SET NOT NULL;';
        ELSE
            RAISE NOTICE '✅ EngineeringRules table is empty - can add NOT NULL columns';
        END IF;
    END IF;
END;
$$;

-- Add columns as nullable first (if they don't exist)
ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS organization_id uuid;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS product_type_id uuid;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS source_component_id uuid;

-- Add foreign key constraint (if column exists and constraint doesn't)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'source_component_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND constraint_name = 'fk_engineering_rules_source_component'
    ) THEN
        ALTER TABLE "EngineeringRules" 
        ADD CONSTRAINT fk_engineering_rules_source_component 
        FOREIGN KEY (source_component_id) REFERENCES "CatalogItems"(id);
        
        RAISE NOTICE '✅ Added foreign key constraint for source_component_id';
    END IF;
END;
$$;

-- Add other required columns (these can be NOT NULL if table is empty)
ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS target_role text;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS dimension text;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS operation text;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS value_mm integer DEFAULT 0;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS per_unit boolean DEFAULT true;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS multiplier numeric DEFAULT 1;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS active boolean DEFAULT true;

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false;

-- Add timestamps if missing
ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

ALTER TABLE "EngineeringRules" 
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Add CHECK constraints (if columns exist)
DO $$
BEGIN
    -- dimension CHECK
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'dimension'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND constraint_name = 'engineering_rules_dimension_check'
    ) THEN
        ALTER TABLE "EngineeringRules" 
        ADD CONSTRAINT engineering_rules_dimension_check 
        CHECK (dimension IS NULL OR dimension IN ('WIDTH', 'HEIGHT', 'LENGTH'));
        
        RAISE NOTICE '✅ Added dimension CHECK constraint';
    END IF;
    
    -- operation CHECK
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'operation'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND constraint_name = 'engineering_rules_operation_check'
    ) THEN
        ALTER TABLE "EngineeringRules" 
        ADD CONSTRAINT engineering_rules_operation_check 
        CHECK (operation IS NULL OR operation IN ('ADD', 'SUBTRACT'));
        
        RAISE NOTICE '✅ Added operation CHECK constraint';
    END IF;
END;
$$;

-- Final instructions
DO $$
DECLARE
    v_row_count integer;
BEGIN
    SELECT COUNT(*) INTO v_row_count FROM "EngineeringRules";
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Columns Added Successfully';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    IF v_row_count > 0 THEN
        RAISE NOTICE '⚠️ IMPORTANT: EngineeringRules has % existing rows', v_row_count;
        RAISE NOTICE '';
        RAISE NOTICE 'Next steps:';
        RAISE NOTICE '1. Update existing rows to set organization_id, product_type_id, source_component_id';
        RAISE NOTICE '2. Then run these commands to make columns NOT NULL:';
        RAISE NOTICE '';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN organization_id SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN product_type_id SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN source_component_id SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN target_role SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN dimension SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN operation SET NOT NULL;';
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '✅ Table is empty - you can now set columns to NOT NULL:';
        RAISE NOTICE '';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN organization_id SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN product_type_id SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN source_component_id SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN target_role SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN dimension SET NOT NULL;';
        RAISE NOTICE '   ALTER TABLE "EngineeringRules" ALTER COLUMN operation SET NOT NULL;';
        RAISE NOTICE '';
    END IF;
END;
$$;






