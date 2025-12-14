-- ====================================================
-- SIMPLE FIX: Fix All Column Names Step by Step
-- ====================================================
-- Execute each section one by one and check for errors
-- ====================================================

-- ====================================================
-- STEP 1: Fix Organizations.name → organization_name
-- ====================================================
DO $$ 
BEGIN
    -- Check current state
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations' 
        AND column_name = 'name'
    ) THEN
        -- Rename it
        ALTER TABLE "Organizations" RENAME COLUMN name TO organization_name;
        RAISE NOTICE '✅ STEP 1: Renamed Organizations.name to organization_name';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations' 
        AND column_name = 'organization_name'
    ) THEN
        RAISE NOTICE '✅ STEP 1: organization_name already exists';
    ELSE
        RAISE NOTICE '❌ STEP 1: Organizations table or name column not found';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Fix DirectoryCustomers.company_name → customer_name
-- ====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryCustomers' 
        AND column_name = 'company_name'
    ) THEN
        ALTER TABLE "DirectoryCustomers" RENAME COLUMN company_name TO customer_name;
        RAISE NOTICE '✅ STEP 2: Renamed DirectoryCustomers.company_name to customer_name';
    ELSE
        RAISE NOTICE 'ℹ️ STEP 2: DirectoryCustomers.company_name not found (may already be customer_name)';
    END IF;
END $$;

-- ====================================================
-- STEP 3: Fix DirectoryContacts - ensure contact_name exists
-- ====================================================
DO $$ 
DECLARE
    has_customer_name boolean;
    has_contact_name boolean;
BEGIN
    -- Check if customer_name exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContacts' 
        AND column_name = 'customer_name'
    ) INTO has_customer_name;
    
    -- Check if contact_name exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContacts' 
        AND column_name = 'contact_name'
    ) INTO has_contact_name;
    
    -- If customer_name exists, rename it
    IF has_customer_name AND NOT has_contact_name THEN
        ALTER TABLE "DirectoryContacts" RENAME COLUMN customer_name TO contact_name;
        RAISE NOTICE '✅ STEP 3: Renamed DirectoryContacts.customer_name to contact_name';
    ELSIF has_contact_name THEN
        RAISE NOTICE '✅ STEP 3: contact_name already exists';
    ELSIF NOT has_contact_name THEN
        -- Add contact_name if it doesn't exist
        ALTER TABLE "DirectoryContacts" ADD COLUMN contact_name text;
        UPDATE "DirectoryContacts" SET contact_name = 'Unnamed Contact' WHERE contact_name IS NULL;
        RAISE NOTICE '✅ STEP 3: Added contact_name column';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Fix DirectoryVendors - ensure vendor_name exists
-- ====================================================
DO $$ 
BEGIN
    -- If name exists, migrate to vendor_name and drop name
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'name'
    ) THEN
        -- Migrate data
        UPDATE "DirectoryVendors"
        SET vendor_name = COALESCE(vendor_name, name)
        WHERE vendor_name IS NULL AND name IS NOT NULL;
        
        -- Drop name
        ALTER TABLE "DirectoryVendors" DROP COLUMN name;
        RAISE NOTICE '✅ STEP 4: Removed DirectoryVendors.name, using vendor_name';
    END IF;
    
    -- Ensure vendor_name exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'vendor_name'
    ) THEN
        ALTER TABLE "DirectoryVendors" ADD COLUMN vendor_name text;
        RAISE NOTICE '✅ STEP 4: Added vendor_name column';
    ELSE
        RAISE NOTICE '✅ STEP 4: vendor_name already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 5: Fix OrganizationUsers.name → user_name
-- ====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'OrganizationUsers' 
        AND column_name = 'name'
    ) THEN
        ALTER TABLE "OrganizationUsers" RENAME COLUMN name TO user_name;
        RAISE NOTICE '✅ STEP 5: Renamed OrganizationUsers.name to user_name';
    ELSE
        RAISE NOTICE 'ℹ️ STEP 5: OrganizationUsers.name not found (may already be user_name)';
    END IF;
END $$;

-- ====================================================
-- VERIFICATION: Check all columns
-- ====================================================
SELECT 
  'VERIFICATION' as check_type,
  table_name,
  column_name,
  'EXISTS' as status
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND (
    (table_name = 'Organizations' AND column_name = 'organization_name') OR
    (table_name = 'DirectoryCustomers' AND column_name = 'customer_name') OR
    (table_name = 'DirectoryContacts' AND column_name = 'contact_name') OR
    (table_name = 'DirectoryVendors' AND column_name = 'vendor_name') OR
    (table_name = 'OrganizationUsers' AND column_name = 'user_name')
  )
ORDER BY table_name, column_name;

