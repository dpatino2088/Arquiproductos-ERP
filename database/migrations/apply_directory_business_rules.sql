-- ====================================================
-- Migration: Apply Directory Business Rules (Simpro Model)
-- ====================================================
-- This migration applies business rules consistently across the Directory module:
-- 1. Contacts: company_id is OPTIONAL
-- 2. Customers: primary_contact_id is REQUIRED
-- 3. Sites: customer_id, contact_id, contractor_id are OPTIONAL

-- ====================================================
-- 1) CONTACTS: Make company_id optional
-- ====================================================
-- Ensure company_id can be NULL (it should already be nullable, but verify)
ALTER TABLE "DirectoryContacts"
ALTER COLUMN company_id DROP NOT NULL;

-- ====================================================
-- 2) CUSTOMERS: Make primary_contact_id required
-- ====================================================
-- First, ensure the column exists
ALTER TABLE "DirectoryCustomers"
ADD COLUMN IF NOT EXISTS primary_contact_id uuid;

-- Add foreign key if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorycustomers_primary_contact_id_fkey'
    ) THEN
        ALTER TABLE "DirectoryCustomers"
        ADD CONSTRAINT directorycustomers_primary_contact_id_fkey
            FOREIGN KEY (primary_contact_id)
            REFERENCES "DirectoryContacts"(id)
            ON UPDATE CASCADE
            ON DELETE RESTRICT;
    END IF;
END $$;

-- Make primary_contact_id NOT NULL
-- Note: This will fail if there are existing rows with NULL primary_contact_id
-- You may need to set a default contact for existing customers first
DO $$ 
BEGIN
    -- Check if there are any NULL values
    IF EXISTS (SELECT 1 FROM "DirectoryCustomers" WHERE primary_contact_id IS NULL) THEN
        RAISE NOTICE 'Warning: There are existing customers with NULL primary_contact_id. Please update them before making this column NOT NULL.';
    ELSE
        -- Only make NOT NULL if no NULL values exist
        ALTER TABLE "DirectoryCustomers"
        ALTER COLUMN primary_contact_id SET NOT NULL;
    END IF;
END $$;

-- Create index for primary_contact_id
CREATE INDEX IF NOT EXISTS idx_directory_customers_primary_contact_id 
ON "DirectoryCustomers"(primary_contact_id);

-- ====================================================
-- 3) SITES: Ensure related fields are optional
-- ====================================================
-- Ensure customer_id exists and is nullable
ALTER TABLE "DirectorySites"
ADD COLUMN IF NOT EXISTS customer_id uuid;

-- Ensure contact_id exists and is nullable
ALTER TABLE "DirectorySites"
ADD COLUMN IF NOT EXISTS contact_id uuid;

-- Ensure contractor_id exists and is nullable
ALTER TABLE "DirectorySites"
ADD COLUMN IF NOT EXISTS contractor_id uuid;

-- Add foreign keys if they don't exist
DO $$ 
BEGIN
    -- customer_id FK
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorysites_customer_id_fkey'
    ) THEN
        ALTER TABLE "DirectorySites"
        ADD CONSTRAINT directorysites_customer_id_fkey
            FOREIGN KEY (customer_id)
            REFERENCES "DirectoryCustomers"(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    -- contact_id FK
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorysites_contact_id_fkey'
    ) THEN
        ALTER TABLE "DirectorySites"
        ADD CONSTRAINT directorysites_contact_id_fkey
            FOREIGN KEY (contact_id)
            REFERENCES "DirectoryContacts"(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    -- contractor_id FK (assuming DirectoryContractors table exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'DirectoryContractors') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'directorysites_contractor_id_fkey'
        ) THEN
            ALTER TABLE "DirectorySites"
            ADD CONSTRAINT directorysites_contractor_id_fkey
                FOREIGN KEY (contractor_id)
                REFERENCES "DirectoryContractors"(id)
                ON UPDATE CASCADE
                ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- Ensure all are nullable (they should be by default, but verify)
ALTER TABLE "DirectorySites"
ALTER COLUMN customer_id DROP NOT NULL;

ALTER TABLE "DirectorySites"
ALTER COLUMN contact_id DROP NOT NULL;

ALTER TABLE "DirectorySites"
ALTER COLUMN contractor_id DROP NOT NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_directory_sites_customer_id 
ON "DirectorySites"(customer_id);

CREATE INDEX IF NOT EXISTS idx_directory_sites_contact_id 
ON "DirectorySites"(contact_id);

CREATE INDEX IF NOT EXISTS idx_directory_sites_contractor_id 
ON "DirectorySites"(contractor_id);

