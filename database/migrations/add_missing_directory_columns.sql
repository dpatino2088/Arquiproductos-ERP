-- ====================================================
-- Migration: Add Missing Columns to Directory Tables
-- ====================================================
-- This migration adds all columns that are used in the application code
-- but may be missing from the database schema.
-- 
-- Based on code analysis of:
-- - src/pages/directory/VendorNew.tsx
-- - src/pages/directory/ContractorNew.tsx
-- - src/pages/directory/SiteNew.tsx
-- - src/hooks/useDirectory.ts
-- ====================================================

-- ====================================================
-- DirectorySites - Add missing columns
-- ====================================================
-- Columns used in code:
-- - site_name (text) - used in insert/update/select
-- - zone (text) - used in insert/update/select
-- - customer_id (uuid) - FK, already added in apply_directory_business_rules.sql
-- - contact_id (uuid) - FK, already added in apply_directory_business_rules.sql
-- - contractor_id (uuid) - FK, already added in apply_directory_business_rules.sql
-- - street_address_line_1 (text) - used in insert/update/select
-- - street_address_line_2 (text) - used in insert/update/select
-- - city (text) - used in insert/update/select
-- - state (text) - used in insert/update/select
-- - zip_code (text) - used in insert/update/select
-- - country (text) - used in insert/update/select
-- - deleted (boolean) - used in insert
-- - archived (boolean) - used in insert/select
-- - created_at (timestamptz) - used in select/order
-- - updated_at (timestamptz) - standard field

ALTER TABLE public."DirectorySites"
  ADD COLUMN IF NOT EXISTS site_name text,
  ADD COLUMN IF NOT EXISTS zone text,
  ADD COLUMN IF NOT EXISTS street_address_line_1 text,
  ADD COLUMN IF NOT EXISTS street_address_line_2 text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS zip_code text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ====================================================
-- DirectoryVendors - Add missing columns
-- ====================================================
-- Columns used in code:
-- - All columns from create_directory_vendors_contractors.sql should exist
-- - Verify all billing columns exist (they should from the CREATE TABLE)
-- - All address columns should exist
-- - deleted, archived, created_at, updated_at should exist

-- Note: Based on create_directory_vendors_contractors.sql, all columns should already exist.
-- This is a safety check to ensure nothing is missing.
ALTER TABLE public."DirectoryVendors"
  ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ====================================================
-- DirectoryContractors - Add missing columns
-- ====================================================
-- Columns used in code:
-- - contractor_company_name (text) - used in insert/update/select
-- - contact_name (text) - used in insert/update/select
-- - position (text) - used in insert/update/select
-- - street_address_line_1 (text) - used in insert/update/select
-- - street_address_line_2 (text) - used in insert/update/select
-- - city (text) - used in insert/update/select
-- - state (text) - used in insert/update/select
-- - zip_code (text) - used in insert/update/select
-- - country (text) - used in insert/update/select
-- - deleted (boolean) - used in insert
-- - archived (boolean) - used in insert/select
-- - created_at (timestamptz) - used in select/order
-- - updated_at (timestamptz) - standard field
--
-- Note: Based on create_directory_vendors_contractors.sql, most columns should already exist.
-- This ensures all required columns are present.

ALTER TABLE public."DirectoryContractors"
  ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ====================================================
-- Verification queries (optional - comment out in production)
-- ====================================================
-- Uncomment to verify columns exist:
/*
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('DirectorySites', 'DirectoryVendors', 'DirectoryContractors')
ORDER BY table_name, ordinal_position;
*/
