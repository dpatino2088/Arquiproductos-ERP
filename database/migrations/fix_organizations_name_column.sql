-- ====================================================
-- Fix: Rename Organizations.name to organization_name
-- ====================================================
-- This script fixes the Organizations table to use organization_name
-- instead of name, to match the unified naming convention
-- ====================================================

DO $$ 
BEGIN
    -- Check if table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations'
    ) THEN
        -- Check if name column exists and organization_name doesn't
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'name'
        ) AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'organization_name'
        ) THEN
            -- Rename the column
            ALTER TABLE "Organizations" 
            RENAME COLUMN name TO organization_name;
            
            -- Update index if it exists
            DROP INDEX IF EXISTS idx_organizations_name;
            CREATE INDEX IF NOT EXISTS idx_organizations_organization_name 
            ON "Organizations"(organization_name) 
            WHERE deleted = false;
            
            -- Add comment
            COMMENT ON COLUMN "Organizations".organization_name IS 'Name of the organization';
            
            RAISE NOTICE '✅ Successfully renamed Organizations.name to organization_name';
        ELSIF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'organization_name'
        ) THEN
            RAISE NOTICE 'ℹ️ Organizations.organization_name already exists, no changes needed';
        ELSE
            RAISE NOTICE '⚠️ Organizations.name column not found. Please check the table structure.';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Organizations table does not exist';
    END IF;
END $$;

-- Verification query
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'Organizations' 
      AND column_name = 'organization_name'
    ) THEN '✅ organization_name column exists'
    ELSE '❌ organization_name column NOT found'
  END as status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'Organizations' 
      AND column_name = 'name'
    ) THEN '⚠️ OLD name column still exists - migration may have failed'
    ELSE '✅ No old name column found'
  END as old_column_status;

















