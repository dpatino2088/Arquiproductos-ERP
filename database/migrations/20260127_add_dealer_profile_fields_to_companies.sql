-- Migration: Add Dealer Profile fields to Companies table
-- Based on DirectoryCustomer schema to unify design patterns
-- Date: 2026-01-27

-- Add missing fields to Companies table for Dealer Profile functionality
-- These fields match the DirectoryCustomer schema for consistency

-- Contact and identification fields
ALTER TABLE "public"."Companies"
  ADD COLUMN IF NOT EXISTS "identification_number" text,
  ADD COLUMN IF NOT EXISTS "website" text,
  ADD COLUMN IF NOT EXISTS "alt_phone" text,
  ADD COLUMN IF NOT EXISTS "primary_contact_id" uuid;

-- Location address fields
ALTER TABLE "public"."Companies"
  ADD COLUMN IF NOT EXISTS "street_address_line_1" text,
  ADD COLUMN IF NOT EXISTS "street_address_line_2" text,
  ADD COLUMN IF NOT EXISTS "city" text,
  ADD COLUMN IF NOT EXISTS "state" text,
  ADD COLUMN IF NOT EXISTS "zip_code" text,
  ADD COLUMN IF NOT EXISTS "country" text;

-- Billing address fields
ALTER TABLE "public"."Companies"
  ADD COLUMN IF NOT EXISTS "billing_same_as_location" boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS "billing_street_address_line_1" text,
  ADD COLUMN IF NOT EXISTS "billing_street_address_line_2" text,
  ADD COLUMN IF NOT EXISTS "billing_city" text,
  ADD COLUMN IF NOT EXISTS "billing_state" text,
  ADD COLUMN IF NOT EXISTS "billing_zip_code" text,
  ADD COLUMN IF NOT EXISTS "billing_country" text;

-- Notes field (similar to DirectoryCustomers)
ALTER TABLE "public"."Companies"
  ADD COLUMN IF NOT EXISTS "notes" text;

-- Add foreign key constraint for primary_contact_id if DirectoryContacts table exists
-- Note: This is optional and may fail if DirectoryContacts doesn't exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DirectoryContacts') THEN
    ALTER TABLE "public"."Companies"
      ADD CONSTRAINT "companies_primary_contact_id_fkey" 
      FOREIGN KEY ("primary_contact_id") 
      REFERENCES "public"."DirectoryContacts"("id") 
      ON DELETE SET NULL;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN
    -- Constraint already exists, ignore
    NULL;
  WHEN OTHERS THEN
    -- Table might not exist, ignore
    NULL;
END $$;

-- Add comments for documentation
COMMENT ON COLUMN "public"."Companies"."identification_number" IS 'Tax ID or business registration number';
COMMENT ON COLUMN "public"."Companies"."website" IS 'Company website URL';
COMMENT ON COLUMN "public"."Companies"."alt_phone" IS 'Alternative phone number';
COMMENT ON COLUMN "public"."Companies"."primary_contact_id" IS 'Primary contact person from DirectoryContacts';
COMMENT ON COLUMN "public"."Companies"."street_address_line_1" IS 'Primary street address';
COMMENT ON COLUMN "public"."Companies"."street_address_line_2" IS 'Secondary street address (suite, unit, etc.)';
COMMENT ON COLUMN "public"."Companies"."city" IS 'City';
COMMENT ON COLUMN "public"."Companies"."state" IS 'State or province';
COMMENT ON COLUMN "public"."Companies"."zip_code" IS 'ZIP or postal code';
COMMENT ON COLUMN "public"."Companies"."country" IS 'Country';
COMMENT ON COLUMN "public"."Companies"."billing_same_as_location" IS 'If true, billing address is same as location address';
COMMENT ON COLUMN "public"."Companies"."billing_street_address_line_1" IS 'Billing street address line 1';
COMMENT ON COLUMN "public"."Companies"."billing_street_address_line_2" IS 'Billing street address line 2';
COMMENT ON COLUMN "public"."Companies"."billing_city" IS 'Billing city';
COMMENT ON COLUMN "public"."Companies"."billing_state" IS 'Billing state or province';
COMMENT ON COLUMN "public"."Companies"."billing_zip_code" IS 'Billing ZIP or postal code';
COMMENT ON COLUMN "public"."Companies"."billing_country" IS 'Billing country';
COMMENT ON COLUMN "public"."Companies"."notes" IS 'Additional notes about the dealer/company';
