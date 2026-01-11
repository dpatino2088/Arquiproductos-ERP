-- ============================================================
-- Migration: Add missing columns to DirectoryCustomers
-- ============================================================
-- This migration adds all the columns that the CustomerNew form expects
-- but are missing from the DirectoryCustomers table

DO $$
BEGIN
  -- Add identification_number (ID Number)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'identification_number'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN identification_number text;
  END IF;

  -- Add customer_type_name (Customer Type: contractor, architecture_studio, design_studio, end_user)
  -- Primero crear el enum si no existe
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'directory_customer_type_name') THEN
    CREATE TYPE directory_customer_type_name AS ENUM ('contractor', 'architecture_studio', 'design_studio', 'end_user');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'customer_type_name'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN customer_type_name directory_customer_type_name;
  END IF;

  -- Add website
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'website'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN website text;
  END IF;

  -- NOTA: company_phone pertenece a Companies, NO a DirectoryCustomers
  -- DirectoryCustomers usa customer_phone (ya existe)

  -- Add alt_phone (Alt Phone)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'alt_phone'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN alt_phone text;
  END IF;

  -- Add primary_contact_id (FK to DirectoryContacts)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'primary_contact_id'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN primary_contact_id uuid 
      REFERENCES public."DirectoryContacts"(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_dircustomers_primary_contact 
      ON public."DirectoryCustomers"(primary_contact_id) 
      WHERE primary_contact_id IS NOT NULL;
  END IF;

  -- Add location/address fields
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'street_address_line_1'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN street_address_line_1 text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'street_address_line_2'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN street_address_line_2 text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'city'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN city text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'state'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN state text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'zip_code'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN zip_code text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'country'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN country text;
  END IF;

  -- Add billing address fields
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'billing_street_address_line_1'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN billing_street_address_line_1 text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'billing_street_address_line_2'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN billing_street_address_line_2 text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'billing_city'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN billing_city text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'billing_state'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN billing_state text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'billing_zip_code'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN billing_zip_code text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'billing_country'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN billing_country text;
  END IF;

  -- Add notes field (if needed)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'notes'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN notes text;
  END IF;
END $$;

-- Create indexes for commonly queried fields
CREATE INDEX IF NOT EXISTS idx_dircustomers_customer_type 
  ON public."DirectoryCustomers"(customer_type_name) 
  WHERE customer_type_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dircustomers_country 
  ON public."DirectoryCustomers"(country) 
  WHERE country IS NOT NULL;

-- Comments for documentation
COMMENT ON COLUMN public."DirectoryCustomers".identification_number IS 'Customer identification number (tax ID, etc.)';
COMMENT ON COLUMN public."DirectoryCustomers".customer_type_name IS 'Customer type: contractor, architecture_studio, design_studio, end_user';
COMMENT ON COLUMN public."DirectoryCustomers".primary_contact_id IS 'Primary contact person (FK to DirectoryContacts)';
COMMENT ON COLUMN public."DirectoryCustomers".alt_phone IS 'Alternative phone number';
COMMENT ON COLUMN public."DirectoryCustomers".customer_phone IS 'Customer phone number (main contact phone)';
