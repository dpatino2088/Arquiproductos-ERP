-- ====================================================
-- Migration: Unify Column Names Across All Tables
-- ====================================================
-- This migration renames columns to follow a consistent naming convention:
-- - Organizations.organization_name (from name)
-- - DirectoryCustomers.customer_name (from company_name)
-- - DirectoryContacts.contact_name (from customer_name)
-- - DirectoryVendors.vendor_name (remove name, keep vendor_name)
-- - CustomerTypes.customer_type_name (from name)
-- - VendorTypes.vendor_type_name (from name)
-- - OrganizationUsers.user_name (from name)
-- ====================================================

-- ====================================================
-- STEP 0: Rename Organizations.name to organization_name
-- ====================================================
DO $$ 
BEGIN
    -- Check if table exists first
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations'
    ) THEN
        -- Check if name column exists and organization_name doesn't
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'name'
        ) AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'organization_name'
        ) THEN
            ALTER TABLE "Organizations" 
            RENAME COLUMN name TO organization_name;
            
            -- Update index if it exists
            DROP INDEX IF EXISTS idx_organizations_name;
            CREATE INDEX IF NOT EXISTS idx_organizations_organization_name 
            ON "Organizations"(organization_name) 
            WHERE deleted = false;
            
            RAISE NOTICE 'Renamed Organizations.name to organization_name';
        ELSIF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'organization_name'
        ) THEN
            RAISE NOTICE 'Organizations.organization_name already exists, skipping rename';
        ELSE
            RAISE NOTICE 'Organizations.name column not found, skipping rename';
        END IF;
    ELSE
        RAISE NOTICE 'Skipping Organizations - table does not exist';
    END IF;
END $$;

-- ====================================================
-- STEP 1: Ensure contact_name exists in DirectoryContacts
-- ====================================================
-- First check if customer_name exists (from previous migration attempt) and rename it
-- Otherwise, create contact_name directly
DO $$ 
DECLARE
    has_customer_name boolean;
    has_contact_name boolean;
    has_company_name boolean;
BEGIN
    -- Check if customer_name exists (from previous failed migration)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContacts' 
        AND column_name = 'customer_name'
    ) INTO has_customer_name;
    
    -- Check if contact_name already exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContacts' 
        AND column_name = 'contact_name'
    ) INTO has_contact_name;
    
    -- Check if company_name exists (for populating contact_name)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContacts' 
        AND column_name = 'company_name'
    ) INTO has_company_name;
    
    -- If customer_name exists, rename it to contact_name
    IF has_customer_name AND NOT has_contact_name THEN
        ALTER TABLE "DirectoryContacts" 
        RENAME COLUMN customer_name TO contact_name;
        RAISE NOTICE 'Renamed DirectoryContacts.customer_name to contact_name';
    ELSIF NOT has_contact_name THEN
        -- If contact_name doesn't exist, add it
        ALTER TABLE "DirectoryContacts"
        ADD COLUMN contact_name text;
        
        -- Populate contact_name from company_name if it exists
        IF has_company_name THEN
            UPDATE "DirectoryContacts"
            SET contact_name = COALESCE(company_name, 'Unnamed Contact')
            WHERE contact_name IS NULL;
        ELSE
            -- Default value if no name columns exist
            UPDATE "DirectoryContacts"
            SET contact_name = 'Unnamed Contact'
            WHERE contact_name IS NULL;
        END IF;
        
        RAISE NOTICE 'Added contact_name column to DirectoryContacts';
    ELSE
        RAISE NOTICE 'contact_name column already exists in DirectoryContacts';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Rename DirectoryCustomers.company_name to customer_name
-- ====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryCustomers' 
        AND column_name = 'company_name'
    ) THEN
        ALTER TABLE "DirectoryCustomers" 
        RENAME COLUMN company_name TO customer_name;
        
        -- Update index if it exists
        DROP INDEX IF EXISTS idx_directory_customers_company_name;
        CREATE INDEX IF NOT EXISTS idx_directory_customers_customer_name 
        ON "DirectoryCustomers"(customer_name) 
        WHERE deleted = false;
        
        RAISE NOTICE 'Renamed DirectoryCustomers.company_name to customer_name';
    END IF;
END $$;

-- ====================================================
-- STEP 3: Ensure DirectoryContacts has contact_name (already handled in STEP 1)
-- ====================================================
-- This step is now handled in STEP 1, but we ensure the index exists
DO $$ 
BEGIN
    -- Just ensure the index exists for contact_name
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryContacts' 
        AND column_name = 'contact_name'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_directory_contacts_contact_name 
        ON "DirectoryContacts"(contact_name) 
        WHERE deleted = false;
        
        RAISE NOTICE 'Ensured index exists for DirectoryContacts.contact_name';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Ensure DirectoryVendors uses only vendor_name
-- ====================================================
-- If name column exists, migrate data to vendor_name and drop name
DO $$ 
BEGIN
    -- Check if name column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'name'
    ) THEN
        -- Migrate data from name to vendor_name if vendor_name is null
        UPDATE "DirectoryVendors"
        SET vendor_name = COALESCE(vendor_name, name)
        WHERE vendor_name IS NULL AND name IS NOT NULL;
        
        -- Drop the name column
        ALTER TABLE "DirectoryVendors" 
        DROP COLUMN IF EXISTS name;
        
        RAISE NOTICE 'Removed DirectoryVendors.name column, using only vendor_name';
    END IF;
    
    -- Ensure vendor_name column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'vendor_name'
    ) THEN
        ALTER TABLE "DirectoryVendors"
        ADD COLUMN vendor_name text;
        
        RAISE NOTICE 'Added vendor_name column to DirectoryVendors';
    END IF;
    
    -- Update index
    DROP INDEX IF EXISTS idx_directory_vendors_name;
    CREATE INDEX IF NOT EXISTS idx_directory_vendors_vendor_name 
    ON "DirectoryVendors"(vendor_name) 
    WHERE deleted = false;
END $$;

-- ====================================================
-- STEP 5: Rename CustomerTypes.name to customer_type_name
-- ====================================================
DO $$ 
BEGIN
    -- Check if table exists first
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CustomerTypes'
    ) THEN
        -- Then check if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'CustomerTypes' 
            AND column_name = 'name'
        ) THEN
            ALTER TABLE "CustomerTypes" 
            RENAME COLUMN name TO customer_type_name;
            
            -- Update index if it exists
            DROP INDEX IF EXISTS idx_customer_types_name;
            CREATE INDEX IF NOT EXISTS idx_customer_types_customer_type_name 
            ON "CustomerTypes"(customer_type_name) 
            WHERE deleted = false;
            
            RAISE NOTICE 'Renamed CustomerTypes.name to customer_type_name';
        END IF;
    ELSE
        RAISE NOTICE 'Skipping CustomerTypes - table does not exist';
    END IF;
END $$;

-- ====================================================
-- STEP 6: Rename VendorTypes.name to vendor_type_name
-- ====================================================
DO $$ 
BEGIN
    -- Check if table exists first
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'VendorTypes'
    ) THEN
        -- Then check if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'VendorTypes' 
            AND column_name = 'name'
        ) THEN
            ALTER TABLE "VendorTypes" 
            RENAME COLUMN name TO vendor_type_name;
            
            -- Update index if it exists
            DROP INDEX IF EXISTS idx_vendor_types_name;
            CREATE INDEX IF NOT EXISTS idx_vendor_types_vendor_type_name 
            ON "VendorTypes"(vendor_type_name) 
            WHERE deleted = false;
            
            RAISE NOTICE 'Renamed VendorTypes.name to vendor_type_name';
        END IF;
    ELSE
        RAISE NOTICE 'Skipping VendorTypes - table does not exist';
    END IF;
END $$;

-- ====================================================
-- STEP 7: Rename OrganizationUsers.name to user_name
-- ====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'OrganizationUsers' 
        AND column_name = 'name'
    ) THEN
        ALTER TABLE "OrganizationUsers" 
        RENAME COLUMN name TO user_name;
        
        -- Update index if it exists
        DROP INDEX IF EXISTS idx_organization_users_name;
        CREATE INDEX IF NOT EXISTS idx_organization_users_user_name 
        ON "OrganizationUsers"(user_name) 
        WHERE deleted = false AND user_name IS NOT NULL;
        
        -- Update comment
        COMMENT ON COLUMN "OrganizationUsers".user_name IS 'User name (cached from auth.users for performance)';
        
        RAISE NOTICE 'Renamed OrganizationUsers.name to user_name';
    END IF;
END $$;

-- ====================================================
-- STEP 8: Update Comments for Documentation
-- ====================================================
DO $$ 
BEGIN
    -- Organizations
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'Organizations') THEN
        COMMENT ON COLUMN "Organizations".organization_name IS 'Name of the organization';
    END IF;
    
    -- DirectoryCustomers
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers') THEN
        COMMENT ON COLUMN "DirectoryCustomers".customer_name IS 'Name of the customer/company';
    END IF;
    
    -- DirectoryContacts
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DirectoryContacts') THEN
        COMMENT ON COLUMN "DirectoryContacts".contact_name IS 'Name of the contact (unified field)';
    END IF;
    
    -- DirectoryVendors
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'DirectoryVendors') THEN
        COMMENT ON COLUMN "DirectoryVendors".vendor_name IS 'Name of the vendor';
    END IF;
    
    -- CustomerTypes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'CustomerTypes') THEN
        COMMENT ON COLUMN "CustomerTypes".customer_type_name IS 'Name of the customer type';
    END IF;
    
    -- VendorTypes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'VendorTypes') THEN
        COMMENT ON COLUMN "VendorTypes".vendor_type_name IS 'Name of the vendor type';
    END IF;
    
    -- OrganizationUsers
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'OrganizationUsers') THEN
        COMMENT ON COLUMN "OrganizationUsers".user_name IS 'User name (cached from auth.users for performance)';
    END IF;
END $$;

-- ====================================================
-- Verification Query (run manually to verify)
-- ====================================================
/*
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'Organizations', 
    'DirectoryCustomers', 
    'DirectoryContacts', 
    'DirectoryVendors',
    'CustomerTypes',
    'VendorTypes',
    'OrganizationUsers'
  )
  AND column_name IN (
    'organization_name',
    'customer_name',
    'contact_name',
    'vendor_name',
    'customer_type_name',
    'vendor_type_name',
    'user_name'
  )
ORDER BY table_name, column_name;
*/

