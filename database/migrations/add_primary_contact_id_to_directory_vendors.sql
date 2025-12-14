-- ====================================================
-- Migration: Add primary_contact_id to DirectoryVendors
-- ====================================================
-- This migration adds a required primary_contact_id field to DirectoryVendors
-- to establish a relationship with DirectoryContacts, similar to DirectoryCustomers
-- ====================================================

-- Step 1: Add primary_contact_id column (nullable initially)
ALTER TABLE public."DirectoryVendors"
  ADD COLUMN IF NOT EXISTS primary_contact_id uuid;

-- Step 2: Add foreign key constraint
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'directoryvendors_primary_contact_id_fkey'
  ) THEN
    ALTER TABLE public."DirectoryVendors"
      DROP CONSTRAINT directoryvendors_primary_contact_id_fkey;
  END IF;

  -- Add foreign key constraint
  ALTER TABLE public."DirectoryVendors"
    ADD CONSTRAINT directoryvendors_primary_contact_id_fkey
      FOREIGN KEY (primary_contact_id)
      REFERENCES public."DirectoryContacts"(id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT;
END $$;

-- Step 3: Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_directory_vendors_primary_contact_id 
ON public."DirectoryVendors"(primary_contact_id);

-- Step 4: Add comment
COMMENT ON COLUMN public."DirectoryVendors".primary_contact_id IS 
  'References DirectoryContacts. Required for all vendors. Each vendor must have a primary contact.';

-- Note: We do NOT make this column NOT NULL in this migration
-- because existing vendors may not have contacts yet.
-- The application layer will enforce this requirement for new vendors.
-- To make it NOT NULL in the future, first ensure all existing vendors have a primary_contact_id:
-- UPDATE public."DirectoryVendors" SET primary_contact_id = (SELECT id FROM public."DirectoryContacts" LIMIT 1) WHERE primary_contact_id IS NULL;
-- Then: ALTER TABLE public."DirectoryVendors" ALTER COLUMN primary_contact_id SET NOT NULL;

