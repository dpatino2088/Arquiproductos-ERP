-- ====================================================
-- Migration 268_fix: Fix MotorTubeCompatibility Table Structure
-- ====================================================
-- Adds missing product_type_id column if table exists without it
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_roller_shade_product_type_id uuid;
    v_null_count integer;
BEGIN
    -- Check if table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'MotorTubeCompatibility'
    ) THEN
        -- Check if product_type_id column exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'product_type_id'
        ) THEN
            RAISE NOTICE '⚠️  Table MotorTubeCompatibility exists but missing product_type_id column. Adding it...';
            
            -- Add product_type_id column as NULL first (to avoid foreign key constraint issues)
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN product_type_id uuid NULL;
            
            -- Find Roller Shade product type to use as default for existing rows
            SELECT id INTO v_roller_shade_product_type_id
            FROM "ProductTypes"
            WHERE (code = 'ROLLER' OR name ILIKE '%roller%shade%')
                AND deleted = false
            LIMIT 1;
            
            -- Update existing NULL rows if we found a valid product_type_id
            IF v_roller_shade_product_type_id IS NOT NULL THEN
                UPDATE public."MotorTubeCompatibility"
                SET product_type_id = v_roller_shade_product_type_id
                WHERE product_type_id IS NULL;
                
                GET DIAGNOSTICS v_null_count = ROW_COUNT;
                IF v_null_count > 0 THEN
                    RAISE NOTICE '  Updated % existing rows with product_type_id: %', v_null_count, v_roller_shade_product_type_id;
                END IF;
            END IF;
            
            -- Check if there are any NULL values remaining
            SELECT COUNT(*) INTO v_null_count
            FROM public."MotorTubeCompatibility"
            WHERE product_type_id IS NULL;
            
            IF v_null_count = 0 THEN
                -- All rows have product_type_id, can add NOT NULL and foreign key
                ALTER TABLE public."MotorTubeCompatibility"
                ALTER COLUMN product_type_id SET NOT NULL;
                
                ALTER TABLE public."MotorTubeCompatibility"
                ADD CONSTRAINT fk_motor_tube_compatibility_product_type
                    FOREIGN KEY (product_type_id) 
                    REFERENCES "ProductTypes"(id) 
                    ON DELETE CASCADE;
                
                RAISE NOTICE '✅ Added product_type_id column with NOT NULL and foreign key constraint';
            ELSE
                -- Some rows are still NULL, add foreign key but keep nullable
                ALTER TABLE public."MotorTubeCompatibility"
                ADD CONSTRAINT fk_motor_tube_compatibility_product_type
                    FOREIGN KEY (product_type_id) 
                    REFERENCES "ProductTypes"(id) 
                    ON DELETE CASCADE;
                
                RAISE NOTICE '⚠️  Added product_type_id column (nullable) with foreign key. % rows have NULL product_type_id.', v_null_count;
                RAISE NOTICE '   You may need to update these rows manually with valid product_type_id values.';
            END IF;
        ELSE
            RAISE NOTICE 'ℹ️  Column product_type_id already exists in MotorTubeCompatibility';
        END IF;
        
        -- Check if organization_id column exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'organization_id'
        ) THEN
            RAISE NOTICE '⚠️  Adding organization_id column...';
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN organization_id uuid;
            
            -- Add foreign key constraint if it doesn't exist
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints
                WHERE table_schema = 'public'
                    AND table_name = 'MotorTubeCompatibility'
                    AND constraint_name = 'fk_motor_tube_compatibility_organization'
            ) THEN
                ALTER TABLE public."MotorTubeCompatibility"
                ADD CONSTRAINT fk_motor_tube_compatibility_organization
                    FOREIGN KEY (organization_id) 
                    REFERENCES "Organizations"(id) 
                    ON DELETE CASCADE;
            END IF;
            RAISE NOTICE '✅ Added organization_id column';
        END IF;
        
        -- Check and add other missing columns (simple additions, no complex logic)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'operating_system_variant'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN operating_system_variant text;
            RAISE NOTICE '✅ Added operating_system_variant column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'tube_type'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN tube_type text;
            RAISE NOTICE '✅ Added tube_type column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'max_width_mm'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN max_width_mm numeric NULL;
            RAISE NOTICE '✅ Added max_width_mm column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'max_drop_mm'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN max_drop_mm numeric NULL;
            RAISE NOTICE '✅ Added max_drop_mm column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'max_area_m2'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN max_area_m2 numeric NULL;
            RAISE NOTICE '✅ Added max_area_m2 column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'active'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN active boolean NOT NULL DEFAULT true;
            RAISE NOTICE '✅ Added active column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'deleted'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN deleted boolean NOT NULL DEFAULT false;
            RAISE NOTICE '✅ Added deleted column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'created_at'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
            RAISE NOTICE '✅ Added created_at column';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'MotorTubeCompatibility'
                AND column_name = 'updated_at'
        ) THEN
            ALTER TABLE public."MotorTubeCompatibility"
            ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
            RAISE NOTICE '✅ Added updated_at column';
        END IF;
        
    ELSE
        RAISE NOTICE 'ℹ️  Table MotorTubeCompatibility does not exist. Run migration 268 first.';
    END IF;
END $$;

COMMIT;
