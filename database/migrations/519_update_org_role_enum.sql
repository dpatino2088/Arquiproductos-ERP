-- ============================================================
-- Migration: Update org_role enum to new role system
-- ============================================================
-- OBJECTIVE:
-- Update the org_role enum to include the new roles:
-- - superadmin (replaces owner)
-- - admin
-- - operator (replaces member/viewer)
-- - procurement
-- - finance
-- 
-- Also migrate existing data to map legacy roles to new roles:
-- - owner -> superadmin
-- - manager -> admin
-- - member/viewer/user -> operator
-- 
-- IMPORTANT: This migration is split into two parts because PostgreSQL
-- requires new enum values to be committed before they can be used.
-- ============================================================

-- ============================================================
-- PART 1: Add new enum values (must be committed separately)
-- ============================================================

BEGIN;

DO $$
DECLARE
  enum_exists boolean;
  current_values text[];
BEGIN
  -- Check if enum exists
  SELECT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'org_role'
  ) INTO enum_exists;

  IF NOT enum_exists THEN
    -- Create enum if it doesn't exist
    CREATE TYPE public.org_role AS ENUM (
      'superadmin',
      'admin',
      'operator',
      'procurement',
      'finance'
    );
    RAISE NOTICE 'Created org_role enum';
  ELSE
    -- Enum exists, check if we need to update it
    SELECT array_agg(enumlabel::text ORDER BY enumsortorder)
    INTO current_values
    FROM pg_enum
    WHERE enumtypid = 'public.org_role'::regtype;

    -- Add new enum values one by one (must be done separately)
    IF NOT ('superadmin' = ANY(current_values)) THEN
      ALTER TYPE public.org_role ADD VALUE IF NOT EXISTS 'superadmin';
      RAISE NOTICE 'Added superadmin to org_role enum';
    END IF;
    
    IF NOT ('admin' = ANY(current_values)) THEN
      ALTER TYPE public.org_role ADD VALUE IF NOT EXISTS 'admin';
      RAISE NOTICE 'Added admin to org_role enum';
    END IF;
    
    IF NOT ('operator' = ANY(current_values)) THEN
      ALTER TYPE public.org_role ADD VALUE IF NOT EXISTS 'operator';
      RAISE NOTICE 'Added operator to org_role enum';
    END IF;
    
    IF NOT ('procurement' = ANY(current_values)) THEN
      ALTER TYPE public.org_role ADD VALUE IF NOT EXISTS 'procurement';
      RAISE NOTICE 'Added procurement to org_role enum';
    END IF;
    
    IF NOT ('finance' = ANY(current_values)) THEN
      ALTER TYPE public.org_role ADD VALUE IF NOT EXISTS 'finance';
      RAISE NOTICE 'Added finance to org_role enum';
    END IF;
  END IF;
END $$;

COMMIT;

-- ============================================================
-- PART 2: Migrate existing data (after enum values are committed)
-- ============================================================

BEGIN;

-- Map legacy roles to new roles
UPDATE public."OrganizationUsers"
SET role = CASE
  WHEN role::text = 'owner' THEN 'superadmin'::public.org_role
  WHEN role::text = 'super_admin' THEN 'superadmin'::public.org_role
  WHEN role::text = 'manager' THEN 'admin'::public.org_role
  WHEN role::text = 'member' THEN 'operator'::public.org_role
  WHEN role::text = 'viewer' THEN 'operator'::public.org_role
  WHEN role::text = 'user' THEN 'operator'::public.org_role
  -- Keep existing valid roles as-is
  WHEN role::text IN ('superadmin', 'admin', 'operator', 'procurement', 'finance') THEN role
  -- Default fallback: operator
  ELSE 'operator'::public.org_role
END
WHERE role::text NOT IN ('superadmin', 'admin', 'operator', 'procurement', 'finance');

-- ============================================================
-- 3) Update constraint to ensure only valid roles
-- ============================================================

-- Note: PostgreSQL enums already enforce valid values, but we can add a check constraint
-- for extra safety (though it's redundant with enum)

DO $$
BEGIN
  -- Drop existing check constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'organizationusers_role_check'
    AND conrelid = 'public."OrganizationUsers"'::regclass
  ) THEN
    ALTER TABLE public."OrganizationUsers" 
    DROP CONSTRAINT organizationusers_role_check;
  END IF;

  -- Add new check constraint (redundant but explicit)
  ALTER TABLE public."OrganizationUsers"
  ADD CONSTRAINT organizationusers_role_check 
  CHECK (role::text IN ('superadmin', 'admin', 'operator', 'procurement', 'finance'));
  
  RAISE NOTICE 'Updated role constraint';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Constraint already exists';
END $$;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Created or updated org_role enum with new values
-- 2. Migrated existing data from legacy roles to new roles
-- 3. Added check constraint for extra safety
-- 
-- Role mappings:
-- - owner/super_admin -> superadmin
-- - manager -> admin
-- - member/viewer/user -> operator
-- ============================================================
