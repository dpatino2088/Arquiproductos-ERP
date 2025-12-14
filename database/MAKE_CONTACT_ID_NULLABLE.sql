-- ====================================================
-- OPTIONAL: Make contact_id and customer_id NULLABLE
-- ====================================================
-- This makes contact_id and customer_id nullable in OrganizationUsers
-- so users can be created without requiring a contact first
-- ====================================================

-- Check current constraint
SELECT 
  'Current constraints' as info,
  column_name,
  is_nullable,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'OrganizationUsers'
  AND column_name IN ('contact_id', 'customer_id')
ORDER BY column_name;

-- Make columns nullable
DO $$ 
BEGIN
    ALTER TABLE "OrganizationUsers" 
    ALTER COLUMN contact_id DROP NOT NULL;

    ALTER TABLE "OrganizationUsers" 
    ALTER COLUMN customer_id DROP NOT NULL;

    RAISE NOTICE '✅ contact_id and customer_id are now NULLABLE';
END $$;

-- Verify change
SELECT 
  'After change' as info,
  column_name,
  is_nullable,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'OrganizationUsers'
  AND column_name IN ('contact_id', 'customer_id')
ORDER BY column_name;

