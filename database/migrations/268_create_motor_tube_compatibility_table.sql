-- ====================================================
-- Migration 268: Create MotorTubeCompatibility Table
-- ====================================================
-- Capacity rules: operating_system_variant + tube_type compatibility
-- Enforces that tube selection is valid for the operating system variant
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Check if table already exists (from previous migrations)
-- ====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'MotorTubeCompatibility'
    ) THEN
        -- ====================================================
        -- STEP 2: Create MotorTubeCompatibility table
        -- ====================================================
        
        CREATE TABLE public."MotorTubeCompatibility" (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            
            -- Organization (optional - null means global rule)
            organization_id uuid REFERENCES "Organizations"(id) ON DELETE CASCADE,
            
            -- Product type context
            product_type_id uuid NOT NULL REFERENCES "ProductTypes"(id) ON DELETE CASCADE,
            
            -- Operating system variant
            operating_system_variant text NOT NULL,  -- e.g. 'standard_m', 'standard_l'
            
            -- Tube type
            tube_type text NOT NULL,                 -- e.g. 'RTU-42', 'RTU-50', 'RTU-65', 'RTU-80'
            
            -- Capacity limits (nullable - NULL means no limit)
            max_width_mm numeric NULL,
            max_drop_mm numeric NULL,
            max_area_m2 numeric NULL,
            
            -- Status
            active boolean NOT NULL DEFAULT true,
            deleted boolean NOT NULL DEFAULT false,
            
            -- Audit
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now()
        );
        
        -- ====================================================
        -- STEP 3: Create indexes
        -- ====================================================
        
        CREATE INDEX IF NOT EXISTS idx_motor_tube_compatibility_lookup 
            ON public."MotorTubeCompatibility"(product_type_id, operating_system_variant, tube_type)
            WHERE deleted = false AND active = true;
        
        CREATE INDEX IF NOT EXISTS idx_motor_tube_compatibility_org 
            ON public."MotorTubeCompatibility"(organization_id, product_type_id, operating_system_variant, tube_type)
            WHERE deleted = false AND active = true AND organization_id IS NOT NULL;
        
        -- ====================================================
        -- STEP 4: Add comments
        -- ====================================================
        -- Note: Function and trigger creation moved outside DO block to avoid delimiter conflict
        
        COMMENT ON TABLE public."MotorTubeCompatibility" IS 
            'Capacity rules: validates that tube_type is compatible with operating_system_variant. Enforces max_width_mm, max_drop_mm, max_area_m2 limits.';
        
        COMMENT ON COLUMN public."MotorTubeCompatibility".max_width_mm IS 
            'Maximum width in millimeters. NULL means no limit.';
        
        COMMENT ON COLUMN public."MotorTubeCompatibility".max_drop_mm IS 
            'Maximum drop/height in millimeters. NULL means no limit.';
        
        COMMENT ON COLUMN public."MotorTubeCompatibility".max_area_m2 IS 
            'Maximum area in square meters. NULL means no limit.';
        
        RAISE NOTICE '✅ Created MotorTubeCompatibility table';
    ELSE
        RAISE NOTICE 'ℹ️  MotorTubeCompatibility table already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Add updated_at trigger (outside DO block)
-- ====================================================

CREATE OR REPLACE FUNCTION set_motor_tube_compatibility_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_motor_tube_compatibility_updated_at ON public."MotorTubeCompatibility";
CREATE TRIGGER set_motor_tube_compatibility_updated_at
    BEFORE UPDATE ON public."MotorTubeCompatibility"
    FOR EACH ROW
    EXECUTE FUNCTION set_motor_tube_compatibility_updated_at();

COMMIT;

