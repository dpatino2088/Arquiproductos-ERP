-- ====================================================
-- Migration: Replace CustomerTypes table with ENUM
-- ====================================================
-- Eliminates CustomerTypes table and replaces customer_type_id (uuid FK)
-- with customer_type_name (ENUM) in DirectoryCustomers
-- ====================================================

-- STEP 1: Create ENUM for customer types (idempotent)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'directory_customer_type_name') THEN
        CREATE TYPE directory_customer_type_name AS ENUM (
            'VIP',
            'Partner',
            'Reseller',
            'Distributor'
        );
        RAISE NOTICE '✅ Created enum directory_customer_type_name';
    ELSE
        RAISE NOTICE '⏭️  Enum directory_customer_type_name already exists';
    END IF;
END $$;

-- STEP 2: Add new column customer_type_name (ENUM) to DirectoryCustomers
ALTER TABLE "DirectoryCustomers"
ADD COLUMN IF NOT EXISTS customer_type_name directory_customer_type_name NULL;

-- STEP 3: Migrate existing data from CustomerTypes to DirectoryCustomers
-- Map customer_type_name values from CustomerTypes table to ENUM values
DO $$
DECLARE
    v_mapped_count integer := 0;
    v_unmapped_count integer := 0;
BEGIN
    -- Migrate data: map CustomerTypes.customer_type_name to ENUM
    UPDATE "DirectoryCustomers" dc
    SET customer_type_name = CASE 
        WHEN ct.customer_type_name ILIKE 'VIP' THEN 'VIP'::directory_customer_type_name
        WHEN ct.customer_type_name ILIKE 'Partner' THEN 'Partner'::directory_customer_type_name
        WHEN ct.customer_type_name ILIKE 'Reseller' THEN 'Reseller'::directory_customer_type_name
        WHEN ct.customer_type_name ILIKE 'Distributor' THEN 'Distributor'::directory_customer_type_name
        ELSE NULL
    END
    FROM "CustomerTypes" ct
    WHERE dc.customer_type_id = ct.id
        AND ct.customer_type_name IS NOT NULL
        AND ct.deleted = false;
    
    GET DIAGNOSTICS v_mapped_count = ROW_COUNT;
    
    -- Count unmapped records (if any)
    SELECT COUNT(*) INTO v_unmapped_count
    FROM "DirectoryCustomers" dc
    WHERE dc.customer_type_id IS NOT NULL
        AND dc.customer_type_name IS NULL
        AND EXISTS (
            SELECT 1 FROM "CustomerTypes" ct 
            WHERE ct.id = dc.customer_type_id 
            AND ct.customer_type_name NOT IN ('VIP', 'Partner', 'Reseller', 'Distributor')
        );
    
    RAISE NOTICE '✅ Migrated % customer type mappings', v_mapped_count;
    IF v_unmapped_count > 0 THEN
        RAISE WARNING '⚠️  % customers have unmapped customer types (will be set to NULL)', v_unmapped_count;
    END IF;
END $$;

-- STEP 4: Drop foreign key constraint
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorycustomers_customer_type_id_fkey'
    ) THEN
        ALTER TABLE "DirectoryCustomers"
        DROP CONSTRAINT directorycustomers_customer_type_id_fkey;
        RAISE NOTICE '✅ Dropped foreign key constraint directorycustomers_customer_type_id_fkey';
    ELSE
        RAISE NOTICE '⏭️  Foreign key constraint directorycustomers_customer_type_id_fkey does not exist';
    END IF;
END $$;

-- STEP 5: Drop index on customer_type_id (no longer needed)
DROP INDEX IF EXISTS idx_directory_customers_customer_type_id;

-- STEP 6: Drop old customer_type_id column
ALTER TABLE "DirectoryCustomers"
DROP COLUMN IF EXISTS customer_type_id;

-- STEP 7: Create index on new customer_type_name column
CREATE INDEX IF NOT EXISTS idx_directory_customers_customer_type_name 
    ON "DirectoryCustomers"(customer_type_name);

-- STEP 8: Drop CustomerTypes table (CASCADE will drop any remaining dependencies)
DROP TABLE IF EXISTS "CustomerTypes" CASCADE;

-- STEP 9: Add comment
COMMENT ON COLUMN "DirectoryCustomers".customer_type_name IS 
    'Customer type using ENUM: VIP, Partner, Reseller, or Distributor';

-- STEP 10: Final success message
DO $$ 
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Frontend code has been updated to use customer_type_name (ENUM)';
    RAISE NOTICE '   2. CustomerNew.tsx now uses ENUM values directly';
    RAISE NOTICE '   3. useDirectory.ts no longer maps CustomerTypes';
END $$;

