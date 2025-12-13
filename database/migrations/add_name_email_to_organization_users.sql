-- Migration: Add name and email columns to OrganizationUsers
-- This migration adds name and email fields to OrganizationUsers table
-- for easier access without needing to join with auth.users

-- Step 1: Add name column if it doesn't exist
ALTER TABLE "OrganizationUsers"
ADD COLUMN IF NOT EXISTS name text;

-- Step 2: Add email column if it doesn't exist
ALTER TABLE "OrganizationUsers"
ADD COLUMN IF NOT EXISTS email text;

-- Step 3: Create index for email for faster lookups
CREATE INDEX IF NOT EXISTS idx_organization_users_email 
ON "OrganizationUsers"(email) 
WHERE deleted = false AND email IS NOT NULL;

-- Step 4: Add comments
COMMENT ON COLUMN "OrganizationUsers".name IS 'User name (cached from auth.users for performance)';
COMMENT ON COLUMN "OrganizationUsers".email IS 'User email (cached from auth.users for performance)';

-- Step 5: Optional - Backfill existing data from auth.users
-- Note: This requires service_role permissions, so it's better to do it via Edge Function
-- or manually update records when they are accessed

-- Example query to backfill (run manually with service_role if needed):
-- UPDATE "OrganizationUsers" ou
-- SET 
--   email = (SELECT email FROM auth.users WHERE id = ou.user_id),
--   name = (SELECT COALESCE(raw_user_meta_data->>'name', email) FROM auth.users WHERE id = ou.user_id)
-- WHERE ou.email IS NULL OR ou.name IS NULL;

