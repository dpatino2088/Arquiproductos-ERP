-- ====================================================
-- Migration: Add customer_id to DirectoryContacts
-- ====================================================
-- This allows a Contact to belong to a Customer
-- Relationship: A Contact belongs to ONE Customer
-- A Customer can have MANY Contacts

-- Step 1: Add customer_id column to DirectoryContacts
ALTER TABLE "DirectoryContacts"
  ADD COLUMN IF NOT EXISTS customer_id uuid NULL REFERENCES "DirectoryCustomers"(id) ON UPDATE CASCADE ON DELETE RESTRICT;

-- Step 2: Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_directory_contacts_customer_id ON "DirectoryContacts"(customer_id) WHERE deleted = false;

-- Step 3: Add comment
COMMENT ON COLUMN "DirectoryContacts".customer_id IS 'References DirectoryCustomers. A Contact belongs to one Customer. A Customer can have many Contacts.';

-- Step 4: Update existing contacts to link them to customers based on primary_contact_id
-- For contacts that are primary_contact of a customer, set their customer_id
UPDATE "DirectoryContacts" dc
SET customer_id = dcu.id
FROM "DirectoryCustomers" dcu
WHERE dcu.primary_contact_id = dc.id
  AND dcu.deleted = false
  AND dc.deleted = false
  AND dc.customer_id IS NULL;

-- Step 5: Optional - Make customer_id NOT NULL after data migration
-- Uncomment this after verifying all contacts have a customer_id
-- ALTER TABLE "DirectoryContacts" ALTER COLUMN customer_id SET NOT NULL;

