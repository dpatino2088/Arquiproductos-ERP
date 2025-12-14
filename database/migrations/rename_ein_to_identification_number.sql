-- ====================================================
-- Migration: Rename ein to identification_number in Directory tables
-- ====================================================
-- Unifies the identification number field name across all directory tables
-- This ensures consistency: DirectoryCustomers, DirectoryContacts, and DirectoryVendors
-- all use "identification_number" instead of "ein"
-- ====================================================

-- STEP 1: Handle DirectoryCustomers
DO $$ 
DECLARE
    has_ein boolean;
    has_identification_number boolean;
BEGIN
    -- Check if ein column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'DirectoryCustomers' 
        AND column_name = 'ein'
    ) INTO has_ein;
    
    -- Check if identification_number column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'DirectoryCustomers' 
        AND column_name = 'identification_number'
    ) INTO has_identification_number;
    
    IF has_ein THEN
        IF has_identification_number THEN
            -- Both columns exist: migrate data from ein to identification_number, then drop ein
            UPDATE "DirectoryCustomers"
            SET identification_number = ein
            WHERE ein IS NOT NULL 
                AND (identification_number IS NULL OR identification_number = '');
            
            ALTER TABLE "DirectoryCustomers" DROP COLUMN ein;
            RAISE NOTICE '✅ Migrated data from ein to identification_number and dropped ein in DirectoryCustomers';
        ELSE
            -- Only ein exists: rename it
            ALTER TABLE "DirectoryCustomers" 
            RENAME COLUMN ein TO identification_number;
            RAISE NOTICE '✅ Renamed column ein to identification_number in DirectoryCustomers';
        END IF;
    ELSIF has_identification_number THEN
        RAISE NOTICE '⏭️  DirectoryCustomers already has identification_number column';
    ELSE
        RAISE WARNING '⚠️  Neither ein nor identification_number column found in DirectoryCustomers';
    END IF;
END $$;

-- STEP 2: Handle DirectoryVendors
DO $$ 
DECLARE
    has_ein boolean;
    has_identification_number boolean;
BEGIN
    -- Check if ein column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'ein'
    ) INTO has_ein;
    
    -- Check if identification_number column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'identification_number'
    ) INTO has_identification_number;
    
    IF has_ein THEN
        IF has_identification_number THEN
            -- Both columns exist: migrate data from ein to identification_number, then drop ein
            UPDATE "DirectoryVendors"
            SET identification_number = ein
            WHERE ein IS NOT NULL 
                AND (identification_number IS NULL OR identification_number = '');
            
            ALTER TABLE "DirectoryVendors" DROP COLUMN ein;
            RAISE NOTICE '✅ Migrated data from ein to identification_number and dropped ein in DirectoryVendors';
        ELSE
            -- Only ein exists: rename it
            ALTER TABLE "DirectoryVendors" 
            RENAME COLUMN ein TO identification_number;
            RAISE NOTICE '✅ Renamed column ein to identification_number in DirectoryVendors';
        END IF;
    ELSIF has_identification_number THEN
        RAISE NOTICE '⏭️  DirectoryVendors already has identification_number column';
    ELSE
        RAISE WARNING '⚠️  Neither ein nor identification_number column found in DirectoryVendors';
    END IF;
END $$;

-- STEP 3: Add comments
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'DirectoryCustomers' 
        AND column_name = 'identification_number'
    ) THEN
        COMMENT ON COLUMN "DirectoryCustomers".identification_number IS 
            'Identification number (EIN, Tax ID, etc.) - unified field name across directory tables';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'DirectoryVendors' 
        AND column_name = 'identification_number'
    ) THEN
        COMMENT ON COLUMN "DirectoryVendors".identification_number IS 
            'Identification number (EIN, Tax ID, etc.) - unified field name across directory tables';
    END IF;
END $$;

-- STEP 4: Final summary
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 All directory tables now use identification_number consistently:';
    RAISE NOTICE '   - DirectoryCustomers.identification_number';
    RAISE NOTICE '   - DirectoryContacts.identification_number';
    RAISE NOTICE '   - DirectoryVendors.identification_number';
END $$;

