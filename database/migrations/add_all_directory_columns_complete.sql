-- ====================================================
-- Migration: Add ALL Required Columns to Directory Tables
-- ====================================================
-- This migration adds all columns that are used in the application code
-- for DirectoryVendors, DirectoryCustomers, and DirectorySites tables.
-- 
-- Based on code analysis of:
-- - src/pages/directory/VendorNew.tsx
-- - src/pages/directory/CustomerNew.tsx
-- - src/pages/directory/SiteNew.tsx
-- - src/hooks/useDirectory.ts
-- ====================================================

-- ====================================================
-- DirectoryVendors - Add all required columns
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
-- DirectoryCustomers - Add all required columns
-- ====================================================
ALTER TABLE public."DirectoryCustomers"
  ADD COLUMN IF NOT EXISTS customer_type_id uuid,
  ADD COLUMN IF NOT EXISTS company_name text,
  ADD COLUMN IF NOT EXISTS identification_number text,
  ADD COLUMN IF NOT EXISTS website text,
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS company_phone text,
  ADD COLUMN IF NOT EXISTS alt_phone text,
  ADD COLUMN IF NOT EXISTS primary_contact_id uuid,
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
-- DirectorySites - Add all required columns
-- ====================================================
ALTER TABLE public."DirectorySites"
  ADD COLUMN IF NOT EXISTS site_name text,
  ADD COLUMN IF NOT EXISTS zone text,
  ADD COLUMN IF NOT EXISTS customer_id uuid,
  ADD COLUMN IF NOT EXISTS contact_id uuid,
  ADD COLUMN IF NOT EXISTS contractor_id uuid,
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
-- Add Foreign Key Constraints (if they don't exist)
-- ====================================================

-- DirectoryCustomers foreign keys
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorycustomers_customer_type_id_fkey'
    ) THEN
        ALTER TABLE public."DirectoryCustomers"
        ADD CONSTRAINT directorycustomers_customer_type_id_fkey
            FOREIGN KEY (customer_type_id)
            REFERENCES public."CustomerTypes"(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorycustomers_primary_contact_id_fkey'
    ) THEN
        ALTER TABLE public."DirectoryCustomers"
        ADD CONSTRAINT directorycustomers_primary_contact_id_fkey
            FOREIGN KEY (primary_contact_id)
            REFERENCES public."DirectoryContacts"(id)
            ON UPDATE CASCADE
            ON DELETE RESTRICT;
    END IF;
END $$;

-- DirectorySites foreign keys
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorysites_customer_id_fkey'
    ) THEN
        ALTER TABLE public."DirectorySites"
        ADD CONSTRAINT directorysites_customer_id_fkey
            FOREIGN KEY (customer_id)
            REFERENCES public."DirectoryCustomers"(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorysites_contact_id_fkey'
    ) THEN
        ALTER TABLE public."DirectorySites"
        ADD CONSTRAINT directorysites_contact_id_fkey
            FOREIGN KEY (contact_id)
            REFERENCES public."DirectoryContacts"(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'DirectoryContractors') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'directorysites_contractor_id_fkey'
        ) THEN
            ALTER TABLE public."DirectorySites"
            ADD CONSTRAINT directorysites_contractor_id_fkey
                FOREIGN KEY (contractor_id)
                REFERENCES public."DirectoryContractors"(id)
                ON UPDATE CASCADE
                ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- ====================================================
-- Create Indexes for better query performance
-- ====================================================

-- DirectoryVendors indexes
CREATE INDEX IF NOT EXISTS idx_directory_vendors_organization_id ON public."DirectoryVendors"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_vendor_name ON public."DirectoryVendors"(vendor_name);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_deleted ON public."DirectoryVendors"(deleted) WHERE deleted = false;

-- DirectoryCustomers indexes
CREATE INDEX IF NOT EXISTS idx_directory_customers_organization_id ON public."DirectoryCustomers"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_customers_company_name ON public."DirectoryCustomers"(company_name);
CREATE INDEX IF NOT EXISTS idx_directory_customers_customer_type_id ON public."DirectoryCustomers"(customer_type_id);
CREATE INDEX IF NOT EXISTS idx_directory_customers_primary_contact_id ON public."DirectoryCustomers"(primary_contact_id);
CREATE INDEX IF NOT EXISTS idx_directory_customers_deleted ON public."DirectoryCustomers"(deleted) WHERE deleted = false;

-- DirectorySites indexes
CREATE INDEX IF NOT EXISTS idx_directory_sites_organization_id ON public."DirectorySites"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_sites_site_name ON public."DirectorySites"(site_name);
CREATE INDEX IF NOT EXISTS idx_directory_sites_customer_id ON public."DirectorySites"(customer_id);
CREATE INDEX IF NOT EXISTS idx_directory_sites_contact_id ON public."DirectorySites"(contact_id);
CREATE INDEX IF NOT EXISTS idx_directory_sites_contractor_id ON public."DirectorySites"(contractor_id);
CREATE INDEX IF NOT EXISTS idx_directory_sites_deleted ON public."DirectorySites"(deleted) WHERE deleted = false;

-- ====================================================
-- Verification Query (optional - uncomment to run)
-- ====================================================
/*
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('DirectoryVendors', 'DirectoryCustomers', 'DirectorySites')
ORDER BY table_name, ordinal_position;
*/
