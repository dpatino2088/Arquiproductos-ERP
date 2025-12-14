-- ====================================================
-- Migration: Populate customer_id in existing DirectoryContacts
-- ====================================================
-- This migration updates existing contacts to link them to customers
-- ====================================================

-- Step 1: Link primary contacts to their customers
-- (Already done in add_customer_id_to_directory_contacts.sql but we repeat for safety)
UPDATE "DirectoryContacts" dc
SET customer_id = dcu.id
FROM "DirectoryCustomers" dcu
WHERE dcu.primary_contact_id = dc.id
  AND dcu.deleted = false
  AND dc.deleted = false
  AND dc.customer_id IS NULL;

-- Step 2: Report statistics
DO $$
DECLARE
  total_contacts INTEGER;
  contacts_with_customer INTEGER;
  contacts_without_customer INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_contacts FROM "DirectoryContacts" WHERE deleted = false;
  SELECT COUNT(*) INTO contacts_with_customer FROM "DirectoryContacts" WHERE deleted = false AND customer_id IS NOT NULL;
  SELECT COUNT(*) INTO contacts_without_customer FROM "DirectoryContacts" WHERE deleted = false AND customer_id IS NULL;
  
  RAISE NOTICE '==============================================';
  RAISE NOTICE 'DirectoryContacts Statistics:';
  RAISE NOTICE 'Total active contacts: %', total_contacts;
  RAISE NOTICE 'Contacts with customer_id: %', contacts_with_customer;
  RAISE NOTICE 'Contacts without customer_id: %', contacts_without_customer;
  RAISE NOTICE '==============================================';
  RAISE NOTICE 'NOTE: Contacts without customer_id need to be manually assigned to a customer';
  RAISE NOTICE 'Use the Contact edit form to select "Customer Related" for each contact';
  RAISE NOTICE '==============================================';
END $$;

-- Step 3: List contacts that need customer_id assignment (for reference)
-- Uncomment to see which contacts need to be updated:
-- SELECT id, customer_name, email, created_at 
-- FROM "DirectoryContacts" 
-- WHERE deleted = false 
--   AND customer_id IS NULL
-- ORDER BY created_at DESC;

