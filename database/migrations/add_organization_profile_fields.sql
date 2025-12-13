-- ====================================================
-- Migration: Add fields to Organizations table for profile view
-- ====================================================
-- This migration adds optional fields to Organizations table if they don't exist
-- These fields will be used in the Organization Profile viewer

-- Add legal_name if it doesn't exist (Nombre Legal)
ALTER TABLE "Organizations"
ADD COLUMN IF NOT EXISTS legal_name text;

-- Add main_email if it doesn't exist (Main email)
ALTER TABLE "Organizations"
ADD COLUMN IF NOT EXISTS main_email text;

-- Create index for main_email
CREATE INDEX IF NOT EXISTS idx_organizations_main_email 
ON "Organizations"(main_email) 
WHERE main_email IS NOT NULL;

-- Add comments for documentation
COMMENT ON COLUMN "Organizations".legal_name IS 'Legal name of the organization (Nombre Legal)';
COMMENT ON COLUMN "Organizations".main_email IS 'Main contact email for the organization';

