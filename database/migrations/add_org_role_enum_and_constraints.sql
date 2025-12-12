-- Migration: Add org_role enum and constraints to OrganizationUsers
-- This migration creates an enum type for organization roles and adds constraints
-- to ensure data integrity

-- Step 1: Create enum type for organization roles
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_role') THEN
    CREATE TYPE org_role AS ENUM ('owner', 'admin', 'member', 'viewer');
  END IF;
END $$;

-- Step 2: Add CHECK constraint to OrganizationUsers.role if it doesn't exist
-- First, check if the constraint already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'organizationusers_role_check'
  ) THEN
    -- Add CHECK constraint
    ALTER TABLE "OrganizationUsers"
    ADD CONSTRAINT organizationusers_role_check 
    CHECK (role IN ('owner', 'admin', 'member', 'viewer'));
  END IF;
END $$;

-- Step 3: Optional - Convert column to use enum type (commented out for safety)
-- Uncomment this if you want to use the enum type instead of text
-- Note: This requires all existing data to be valid enum values
/*
DO $$
BEGIN
  -- First ensure all existing values are valid
  UPDATE "OrganizationUsers" 
  SET role = 'member' 
  WHERE role NOT IN ('owner', 'admin', 'member', 'viewer');
  
  -- Then alter the column type
  ALTER TABLE "OrganizationUsers"
  ALTER COLUMN role TYPE org_role USING role::org_role;
END $$;
*/

-- Step 4: Add comment to document the constraint
COMMENT ON CONSTRAINT organizationusers_role_check ON "OrganizationUsers" IS 
  'Ensures role is one of: owner, admin, member, viewer';
