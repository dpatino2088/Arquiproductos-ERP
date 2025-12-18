-- ====================================================
-- Migration: Add Operating System Drive FK to QuoteLines
-- ====================================================
-- Adds a foreign key relationship for operating system drives
-- to enable automatic JOINs and ensure referential integrity
-- ====================================================

-- STEP 1: Add the new FK column (nullable to allow migration)
ALTER TABLE "QuoteLines" 
ADD COLUMN IF NOT EXISTS operating_system_drive_id uuid;

-- STEP 2: Migrate existing data (only valid UUIDs)
-- NOTE: This step is skipped if operating_system_variant column was already removed
-- If you need to migrate data, you'll need to do it manually or restore the column temporarily
-- UPDATE "QuoteLines"
-- SET operating_system_drive_id = operating_system_variant::uuid
-- WHERE operating_system_variant IS NOT NULL
--   AND operating_system_variant ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
--   AND EXISTS (
--     SELECT 1 FROM "CatalogItems" 
--     WHERE "CatalogItems".id = operating_system_variant::uuid
--     AND "CatalogItems".deleted = false
--   );

-- STEP 3: Add the foreign key constraint
DO $$ 
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'quote_lines_operating_system_drive_id_fkey'
    ) THEN
        ALTER TABLE "QuoteLines"
        ADD CONSTRAINT quote_lines_operating_system_drive_id_fkey
        FOREIGN KEY (operating_system_drive_id)
        REFERENCES "CatalogItems"(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE;
        
        RAISE NOTICE '✅ Foreign key constraint added';
    ELSE
        RAISE NOTICE '⏭️  Foreign key constraint already exists';
    END IF;
END $$;

-- STEP 4: Add index for performance
CREATE INDEX IF NOT EXISTS idx_quote_lines_operating_system_drive_id 
    ON "QuoteLines"(operating_system_drive_id) 
    WHERE operating_system_drive_id IS NOT NULL;

-- STEP 5: Add comment for documentation
COMMENT ON COLUMN "QuoteLines".operating_system_drive_id IS 
    'Foreign key to CatalogItems table for operating system drives. 
     This enables automatic JOINs to get drive names.';

-- ====================================================
-- Verification
-- ====================================================
DO $$ 
DECLARE
    migrated_count integer;
BEGIN
    SELECT COUNT(*) INTO migrated_count
    FROM "QuoteLines"
    WHERE operating_system_drive_id IS NOT NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════';
    RAISE NOTICE '✅ MIGRATION COMPLETED';
    RAISE NOTICE '════════════════════════════════════════════════';
    RAISE NOTICE '📊 Migration Statistics:';
    RAISE NOTICE '   Rows with operating_system_drive_id: %', migrated_count;
    RAISE NOTICE '';
END $$;

