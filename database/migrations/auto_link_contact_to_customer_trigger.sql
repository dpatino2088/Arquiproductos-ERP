-- ====================================================
-- Migration: Auto-link Contact to Customer when Customer uses it as primary_contact
-- ====================================================
-- This trigger automatically updates the Contact's customer_id 
-- when a Customer is created or updated with that Contact as primary_contact_id

-- Function to sync customer_id in DirectoryContacts
CREATE OR REPLACE FUNCTION sync_contact_customer_id()
RETURNS TRIGGER AS $$
BEGIN
  -- When a Customer is created or updated with a primary_contact_id,
  -- automatically update that Contact's customer_id to point to this Customer
  IF NEW.primary_contact_id IS NOT NULL THEN
    UPDATE "DirectoryContacts"
    SET customer_id = NEW.id,
        updated_at = now()
    WHERE id = NEW.primary_contact_id
      AND organization_id = NEW.organization_id
      AND (customer_id IS NULL OR customer_id != NEW.id)
      AND deleted = false;
  END IF;
  
  -- If primary_contact_id was changed, we keep the old contact's customer_id
  -- (it might still be valid if the contact is used elsewhere)
  -- This is a design decision: we don't automatically unlink old contacts
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for INSERT
DROP TRIGGER IF EXISTS trigger_sync_contact_customer_on_insert ON "DirectoryCustomers";
CREATE TRIGGER trigger_sync_contact_customer_on_insert
  AFTER INSERT ON "DirectoryCustomers"
  FOR EACH ROW
  EXECUTE FUNCTION sync_contact_customer_id();

-- Create trigger for UPDATE
DROP TRIGGER IF EXISTS trigger_sync_contact_customer_on_update ON "DirectoryCustomers";
CREATE TRIGGER trigger_sync_contact_customer_on_update
  AFTER UPDATE ON "DirectoryCustomers"
  FOR EACH ROW
  WHEN (OLD.primary_contact_id IS DISTINCT FROM NEW.primary_contact_id)
  EXECUTE FUNCTION sync_contact_customer_id();

-- ====================================================
-- Backfill: Update existing Contacts that are primary_contact of Customers
-- ====================================================
UPDATE "DirectoryContacts" dc
SET customer_id = dcu.id,
    updated_at = now()
FROM "DirectoryCustomers" dcu
WHERE dcu.primary_contact_id = dc.id
  AND dc.organization_id = dcu.organization_id
  AND (dc.customer_id IS NULL OR dc.customer_id != dcu.id)
  AND dc.deleted = false
  AND dcu.deleted = false;

-- ====================================================
-- Verification
-- ====================================================
-- Run this query to verify contacts are linked:
-- SELECT 
--   dc.id as contact_id,
--   dc.contact_name,
--   dc.customer_id,
--   dcu.id as customer_id_from_primary,
--   dcu.customer_name
-- FROM "DirectoryContacts" dc
-- LEFT JOIN "DirectoryCustomers" dcu ON dcu.primary_contact_id = dc.id
-- WHERE dcu.id IS NOT NULL
-- ORDER BY dc.created_at DESC;
--
-- Expected: All contacts that are primary_contact of a customer should have customer_id set













