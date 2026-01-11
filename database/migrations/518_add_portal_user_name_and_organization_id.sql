-- ============================================================
-- Migration: Add portal_user_name and organization_id to CompanyPortalUsers
-- ============================================================
-- OBJECTIVE:
-- Add portal_user_name and organization_id columns to CompanyPortalUsers table
-- These columns are needed for proper data display and organization filtering
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Add portal_user_name column if it doesn't exist
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'CompanyPortalUsers' 
    AND column_name = 'portal_user_name'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" 
    ADD COLUMN portal_user_name text NULL;
    
    RAISE NOTICE 'Added portal_user_name column to CompanyPortalUsers';
  ELSE
    RAISE NOTICE 'portal_user_name column already exists in CompanyPortalUsers';
  END IF;
END $$;

-- ============================================================
-- 2) Add organization_id column if it doesn't exist
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'CompanyPortalUsers' 
    AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" 
    ADD COLUMN organization_id uuid NULL REFERENCES public."Organizations"(id) ON DELETE RESTRICT;
    
    -- Create index for better query performance
    CREATE INDEX IF NOT EXISTS idx_companyportalusers_org_id 
    ON public."CompanyPortalUsers"(organization_id) 
    WHERE organization_id IS NOT NULL;
    
    -- Migrate organization_id from Companies table for existing records
    UPDATE public."CompanyPortalUsers" cpu
    SET organization_id = c.organization_id
    FROM public."Companies" c
    WHERE cpu.company_id = c.id
      AND cpu.organization_id IS NULL;
    
    RAISE NOTICE 'Added organization_id column to CompanyPortalUsers and migrated existing data';
  ELSE
    RAISE NOTICE 'organization_id column already exists in CompanyPortalUsers';
  END IF;
END $$;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Added portal_user_name column (text, nullable)
-- 2. Added organization_id column (uuid, nullable, FK to Organizations)
-- 3. Created index on organization_id for better query performance
-- 4. Migrated organization_id from Companies table for existing records
-- ============================================================
