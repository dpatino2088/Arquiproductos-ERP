-- ====================================================
-- Migration: Fix DirectoryVendors and DirectoryContractors Schema
-- ====================================================
-- This migration ensures all columns used in the application code exist
-- and have the correct types and nullability.
-- ====================================================

-- ====================================================
-- DirectoryVendors - Add missing 'name' column (NOT NULL)
-- ====================================================
-- The DB requires 'name' to be NOT NULL, but the code was sending 'vendor_name'
-- We'll add 'name' and ensure it's populated from vendor_name if needed
ALTER TABLE public."DirectoryVendors"
  ADD COLUMN IF NOT EXISTS name text;

-- Update existing rows: set name from vendor_name if name is null
UPDATE public."DirectoryVendors"
SET name = COALESCE(vendor_name, 'Unnamed Vendor')
WHERE name IS NULL;

-- Make name NOT NULL after populating existing rows
ALTER TABLE public."DirectoryVendors"
  ALTER COLUMN name SET NOT NULL;

-- ====================================================
-- DirectoryContractors - Ensure all columns exist
-- ====================================================
-- Based on create_directory_vendors_contractors.sql, most columns should exist
-- This is a safety check to ensure nothing is missing
-- All columns from the CREATE TABLE should already exist, so this is minimal

-- Verify critical columns exist (these should already be there from CREATE TABLE)
ALTER TABLE public."DirectoryContractors"
  ADD COLUMN IF NOT EXISTS contractor_company_name text,
  ADD COLUMN IF NOT EXISTS contact_name text,
  ADD COLUMN IF NOT EXISTS position text,
  ADD COLUMN IF NOT EXISTS street_address_line_1 text,
  ADD COLUMN IF NOT EXISTS street_address_line_2 text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS zip_code text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS primary_email text,
  ADD COLUMN IF NOT EXISTS secondary_email text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS extension text,
  ADD COLUMN IF NOT EXISTS cell_phone text,
  ADD COLUMN IF NOT EXISTS fax text,
  ADD COLUMN IF NOT EXISTS preferred_notification_method text,
  ADD COLUMN IF NOT EXISTS date_of_hire date,
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS ein text,
  ADD COLUMN IF NOT EXISTS company_number text,
  ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ====================================================
-- DirectoryVendors - Ensure all columns exist
-- ====================================================
ALTER TABLE public."DirectoryVendors"
  ADD COLUMN IF NOT EXISTS vendor_name text,
  ADD COLUMN IF NOT EXISTS ein text,
  ADD COLUMN IF NOT EXISTS website text,
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS work_phone text,
  ADD COLUMN IF NOT EXISTS fax text,
  ADD COLUMN IF NOT EXISTS street_address_line_1 text,
  ADD COLUMN IF NOT EXISTS street_address_line_2 text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS zip_code text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS billing_street_address_line_1 text,
  ADD COLUMN IF NOT EXISTS billing_street_address_line_2 text,
  ADD COLUMN IF NOT EXISTS billing_city text,
  ADD COLUMN IF NOT EXISTS billing_state text,
  ADD COLUMN IF NOT EXISTS billing_zip_code text,
  ADD COLUMN IF NOT EXISTS billing_country text,
  ADD COLUMN IF NOT EXISTS deleted boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ====================================================
-- Create/Update Indexes for better query performance
-- ====================================================

-- DirectoryVendors indexes
CREATE INDEX IF NOT EXISTS idx_directory_vendors_organization_id ON public."DirectoryVendors"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_name ON public."DirectoryVendors"(name);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_deleted ON public."DirectoryVendors"(deleted) WHERE deleted = false;

-- DirectoryContractors indexes
CREATE INDEX IF NOT EXISTS idx_directory_contractors_organization_id ON public."DirectoryContractors"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_contractors_company_name ON public."DirectoryContractors"(contractor_company_name);
CREATE INDEX IF NOT EXISTS idx_directory_contractors_deleted ON public."DirectoryContractors"(deleted) WHERE deleted = false;
