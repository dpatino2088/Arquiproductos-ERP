-- Migration: Add contact_id and customer_id to OrganizationUsers (BOTH REQUIRED)
-- This ensures that every OrganizationUser must be linked to an existing Contact and Customer

-- Step 1: Add contact_id column (NULL initially to allow existing records to be updated)
ALTER TABLE "OrganizationUsers"
  ADD COLUMN IF NOT EXISTS contact_id uuid NULL REFERENCES "DirectoryContacts"(id) ON UPDATE CASCADE ON DELETE RESTRICT;

-- Step 2: Add customer_id column (NULL initially to allow existing records to be updated)
ALTER TABLE "OrganizationUsers"
  ADD COLUMN IF NOT EXISTS customer_id uuid NULL REFERENCES "DirectoryCustomers"(id) ON UPDATE CASCADE ON DELETE RESTRICT;

-- Step 3: Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_organization_users_contact_id ON "OrganizationUsers"(contact_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_organization_users_customer_id ON "OrganizationUsers"(customer_id) WHERE deleted = false;

-- Step 4: Add comments
COMMENT ON COLUMN "OrganizationUsers".contact_id IS 'References DirectoryContacts. Required for new users.';
COMMENT ON COLUMN "OrganizationUsers".customer_id IS 'References DirectoryCustomers. Required for new users. The Contact must belong to this Customer (via DirectoryContacts.customer_id).';

-- Step 5: For existing records, try to auto-link based on email matching
-- This attempts to find Contacts and Customers for existing OrganizationUsers
UPDATE "OrganizationUsers" ou
SET 
  contact_id = subq.contact_id,
  customer_id = subq.customer_id
FROM (
  SELECT 
    ou_inner.id as org_user_id,
    dc.id as contact_id,
    dcu.id as customer_id
  FROM "OrganizationUsers" ou_inner
  LEFT JOIN "DirectoryContacts" dc 
    ON dc.email = ou_inner.email 
    AND dc.organization_id = ou_inner.organization_id
    AND dc.deleted = false
  LEFT JOIN "DirectoryCustomers" dcu 
    ON dcu.primary_contact_id = dc.id 
    AND dcu.organization_id = ou_inner.organization_id
    AND dcu.deleted = false
  WHERE ou_inner.contact_id IS NULL
    AND ou_inner.deleted = false
) subq
WHERE ou.id = subq.org_user_id
  AND subq.contact_id IS NOT NULL
  AND subq.customer_id IS NOT NULL;

-- Step 6: Create a function to validate customer-contact relationship
-- Updated: A Contact belongs to a Customer via customer_id (not primary_contact_id)
CREATE OR REPLACE FUNCTION validate_organization_user_customer_contact()
RETURNS TRIGGER AS $$
BEGIN
  -- If both contact_id and customer_id are provided, validate the relationship
  IF NEW.contact_id IS NOT NULL AND NEW.customer_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 
      FROM "DirectoryContacts" dc
      WHERE dc.id = NEW.contact_id
        AND dc.customer_id = NEW.customer_id
        AND dc.organization_id = NEW.organization_id
        AND dc.deleted = false
    ) THEN
      RAISE EXCEPTION 'The selected Contact must belong to the selected Customer (via customer_id)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create trigger to enforce the validation
DROP TRIGGER IF EXISTS check_organization_user_customer_contact ON "OrganizationUsers";
CREATE TRIGGER check_organization_user_customer_contact
  BEFORE INSERT OR UPDATE ON "OrganizationUsers"
  FOR EACH ROW
  EXECUTE FUNCTION validate_organization_user_customer_contact();

-- Step 8: After updating existing records, make both columns NOT NULL
-- IMPORTANT: Only uncomment these after verifying all records have been updated
-- If some records can't be auto-linked, you'll need to manually link them first

-- ALTER TABLE "OrganizationUsers" ALTER COLUMN contact_id SET NOT NULL;
-- ALTER TABLE "OrganizationUsers" ALTER COLUMN customer_id SET NOT NULL;

