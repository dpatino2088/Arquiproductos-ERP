-- ====================================================
-- Migration: Add company_id to DirectoryContacts
-- ====================================================
-- This migration adds the company_id column to link contacts
-- to their parent company (DirectoryCustomers) within an organization.

-- Add company_id column if it doesn't exist
ALTER TABLE "DirectoryContacts"
ADD COLUMN IF NOT EXISTS company_id uuid;

-- Add foreign key constraint
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorycontacts_company_id_fkey'
    ) THEN
        ALTER TABLE "DirectoryContacts"
        ADD CONSTRAINT directorycontacts_company_id_fkey
            FOREIGN KEY (company_id) 
            REFERENCES "DirectoryCustomers"(id) 
            ON UPDATE CASCADE 
            ON DELETE SET NULL;
    END IF;
END $$;

-- Create index for company_id
CREATE INDEX IF NOT EXISTS idx_directory_contacts_company_id 
ON "DirectoryContacts"(company_id);

-- Create composite index for organization_id and company_id
CREATE INDEX IF NOT EXISTS idx_directory_contacts_org_company 
ON "DirectoryContacts"(organization_id, company_id);

