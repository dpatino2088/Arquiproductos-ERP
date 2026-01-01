-- ====================================================
-- STEP 2: Create/Adjust EngineeringRules table
-- ====================================================
-- This script creates EngineeringRules table if it doesn't exist
-- or adds missing columns if it exists
-- ====================================================

-- Check if EngineeringRules table exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules'
    ) THEN
        -- Create table
        CREATE TABLE "EngineeringRules" (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            organization_id uuid NOT NULL,
            product_type_id uuid NOT NULL,
            source_component_id uuid NOT NULL REFERENCES "CatalogItems"(id),
            target_role text NOT NULL,
            dimension text NOT NULL CHECK (dimension IN ('WIDTH', 'HEIGHT', 'LENGTH')),
            operation text NOT NULL CHECK (operation IN ('ADD', 'SUBTRACT')),
            value_mm integer NOT NULL DEFAULT 0,
            per_unit boolean NOT NULL DEFAULT true,
            multiplier numeric NOT NULL DEFAULT 1,
            active boolean NOT NULL DEFAULT true,
            deleted boolean NOT NULL DEFAULT false,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            created_by uuid,
            updated_by uuid
        );
        
        RAISE NOTICE '✅ Created EngineeringRules table';
    ELSE
        RAISE NOTICE '⏭️  EngineeringRules table already exists, checking for missing columns...';
    END IF;
END;
$$;

-- Add missing columns if they don't exist
DO $$
BEGIN
    -- organization_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'organization_id'
    ) THEN
        -- First add as nullable
        ALTER TABLE "EngineeringRules" ADD COLUMN organization_id uuid;
        
        -- Check if there are existing rows
        DECLARE
            v_existing_count integer;
        BEGIN
            SELECT COUNT(*) INTO v_existing_count FROM "EngineeringRules";
            
            IF v_existing_count > 0 THEN
                RAISE WARNING '⚠️ EngineeringRules table has % existing rows. organization_id will be NULL. You must update them manually.';
            END IF;
        END;
        
        -- Make it NOT NULL only if table is empty or after manual update
        -- For now, leave it nullable to avoid constraint violation
        -- User can manually update existing rows and then run: ALTER TABLE "EngineeringRules" ALTER COLUMN organization_id SET NOT NULL;
        
        RAISE NOTICE '✅ Added organization_id column (nullable - update existing rows and then set NOT NULL)';
    END IF;
    
    -- product_type_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'product_type_id'
    ) THEN
        -- First add as nullable
        ALTER TABLE "EngineeringRules" ADD COLUMN product_type_id uuid;
        
        -- Check if there are existing rows
        DECLARE
            v_existing_count integer;
        BEGIN
            SELECT COUNT(*) INTO v_existing_count FROM "EngineeringRules";
            
            IF v_existing_count > 0 THEN
                RAISE WARNING '⚠️ EngineeringRules table has % existing rows. product_type_id will be NULL. You must update them manually.';
            END IF;
        END;
        
        -- Make it NOT NULL only if table is empty or after manual update
        -- For now, leave it nullable to avoid constraint violation
        -- User can manually update existing rows and then run: ALTER TABLE "EngineeringRules" ALTER COLUMN product_type_id SET NOT NULL;
        
        RAISE NOTICE '✅ Added product_type_id column (nullable - update existing rows and then set NOT NULL)';
    END IF;
    
    -- source_component_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'source_component_id'
    ) THEN
        -- First add as nullable
        ALTER TABLE "EngineeringRules" ADD COLUMN source_component_id uuid;
        
        -- Add foreign key constraint separately (nullable FK is allowed)
        ALTER TABLE "EngineeringRules" 
        ADD CONSTRAINT fk_engineering_rules_source_component 
        FOREIGN KEY (source_component_id) REFERENCES "CatalogItems"(id);
        
        -- Check if there are existing rows
        DECLARE
            v_existing_count integer;
        BEGIN
            SELECT COUNT(*) INTO v_existing_count FROM "EngineeringRules";
            
            IF v_existing_count > 0 THEN
                RAISE WARNING '⚠️ EngineeringRules table has % existing rows. source_component_id will be NULL. You must update them manually.';
            END IF;
        END;
        
        RAISE NOTICE '✅ Added source_component_id column (nullable - update existing rows and then set NOT NULL)';
    END IF;
    
    -- target_role
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'target_role'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN target_role text NOT NULL;
        RAISE NOTICE '✅ Added target_role column';
    END IF;
    
    -- dimension
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'dimension'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN dimension text NOT NULL CHECK (dimension IN ('WIDTH', 'HEIGHT', 'LENGTH'));
        RAISE NOTICE '✅ Added dimension column';
    END IF;
    
    -- operation
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'operation'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN operation text NOT NULL CHECK (operation IN ('ADD', 'SUBTRACT'));
        RAISE NOTICE '✅ Added operation column';
    END IF;
    
    -- value_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'value_mm'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN value_mm integer NOT NULL DEFAULT 0;
        RAISE NOTICE '✅ Added value_mm column';
    END IF;
    
    -- per_unit
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'per_unit'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN per_unit boolean NOT NULL DEFAULT true;
        RAISE NOTICE '✅ Added per_unit column';
    END IF;
    
    -- multiplier
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'multiplier'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN multiplier numeric NOT NULL DEFAULT 1;
        RAISE NOTICE '✅ Added multiplier column';
    END IF;
    
    -- active
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'active'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN active boolean NOT NULL DEFAULT true;
        RAISE NOTICE '✅ Added active column';
    END IF;
    
    -- deleted
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN deleted boolean NOT NULL DEFAULT false;
        RAISE NOTICE '✅ Added deleted column';
    END IF;
    
    -- timestamps
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
        RAISE NOTICE '✅ Added created_at column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'EngineeringRules' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE "EngineeringRules" ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
        RAISE NOTICE '✅ Added updated_at column';
    END IF;
END;
$$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_engineering_rules_org_product 
ON "EngineeringRules"(organization_id, product_type_id) 
WHERE deleted = false AND active = true;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_source_component 
ON "EngineeringRules"(source_component_id) 
WHERE deleted = false AND active = true;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_target 
ON "EngineeringRules"(target_role, dimension) 
WHERE deleted = false AND active = true;

-- Enable RLS
ALTER TABLE "EngineeringRules" ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (basic - adjust as needed)
DO $$
BEGIN
    -- Drop existing policies if any
    DROP POLICY IF EXISTS "Users can view EngineeringRules for their organization" ON "EngineeringRules";
    DROP POLICY IF EXISTS "Users can insert EngineeringRules for their organization" ON "EngineeringRules";
    DROP POLICY IF EXISTS "Users can update EngineeringRules for their organization" ON "EngineeringRules";
    
    -- Create policies
    CREATE POLICY "Users can view EngineeringRules for their organization"
    ON "EngineeringRules" FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );
    
    CREATE POLICY "Users can insert EngineeringRules for their organization"
    ON "EngineeringRules" FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );
    
    CREATE POLICY "Users can update EngineeringRules for their organization"
    ON "EngineeringRules" FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );
    
    RAISE NOTICE '✅ RLS policies created for EngineeringRules';
END;
$$;

COMMENT ON TABLE "EngineeringRules" IS 
'Stores dimensional adjustment rules by ProductType and component.
Rules define how unit components (brackets, drives, endcaps) adjust linear parts (tubes, rails) and fabric dimensions.';

