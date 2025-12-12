-- ====================================================
-- Migration: Add owner_user_id to Organizations table
-- ====================================================
-- This migration adds a column to store the auth user ID of the organization owner

-- Add owner_user_id column if it doesn't exist
ALTER TABLE "Organizations"
ADD COLUMN IF NOT EXISTS owner_user_id uuid;

-- Add foreign key constraint to auth.users (if needed)
-- Note: We can't directly reference auth.users from public schema in some setups
-- So we'll just ensure the column exists and handle the relationship in application code

-- Create index for owner_user_id
CREATE INDEX IF NOT EXISTS idx_organizations_owner_user_id 
ON "Organizations"(owner_user_id);

-- Add comment
COMMENT ON COLUMN "Organizations".owner_user_id IS 'UUID of the auth.users record for the organization owner';

