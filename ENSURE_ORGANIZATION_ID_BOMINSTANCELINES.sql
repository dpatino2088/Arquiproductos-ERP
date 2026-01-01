-- ====================================================
-- Script: Ensure organization_id in BomInstanceLines
-- ====================================================
-- This script ensures that BomInstanceLines has organization_id
-- and that it's properly set for all existing records
-- ====================================================

-- Step 1: Check if organization_id column exists
SELECT 
    'Step 1: Check organization_id Column' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'BomInstanceLines' 
            AND column_name = 'organization_id'
        ) THEN '✅ Column exists'
        ELSE '❌ Column does NOT exist - will add it'
    END as status;

-- Step 2: Add organization_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'organization_id'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN organization_id uuid;
        
        RAISE NOTICE '✅ Added organization_id column to BomInstanceLines';
        
        -- Add index for better performance
        CREATE INDEX IF NOT EXISTS idx_bom_instance_lines_organization_id 
        ON "BomInstanceLines"(organization_id);
        
        RAISE NOTICE '✅ Created index on organization_id';
    ELSE
        RAISE NOTICE '⏭️  organization_id column already exists in BomInstanceLines';
    END IF;
END $$;

-- Step 3: Update existing BomInstanceLines with organization_id from BomInstances
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    RAISE NOTICE 'Step 3: Updating existing BomInstanceLines with organization_id...';
    
    UPDATE "BomInstanceLines" bil
    SET organization_id = bi.organization_id,
        updated_at = NOW()
    FROM "BomInstances" bi
    WHERE bil.bom_instance_id = bi.id
    AND bil.organization_id IS NULL;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Updated % BomInstanceLines with organization_id', v_updated_count;
END $$;

-- Step 4: Verify organization_id is set for all BomInstanceLines
SELECT 
    'Step 4: Verification - organization_id in BomInstanceLines' as check_type,
    COUNT(*) as total_rows,
    COUNT(organization_id) as rows_with_org_id,
    COUNT(*) - COUNT(organization_id) as rows_missing_org_id,
    CASE 
        WHEN COUNT(*) = COUNT(organization_id) THEN '✅ All rows have organization_id'
        ELSE '❌ Some rows are missing organization_id'
    END as status
FROM "BomInstanceLines"
WHERE deleted = false;

-- Step 5: Show sample of BomInstanceLines with organization_id
SELECT 
    'Step 5: Sample BomInstanceLines' as check_type,
    bil.id,
    bil.organization_id,
    bil.category_code,
    bil.part_role,
    bil.qty,
    bil.uom,
    ci.sku,
    bi.organization_id as bom_instance_org_id,
    CASE 
        WHEN bil.organization_id = bi.organization_id THEN '✅ Match'
        WHEN bil.organization_id IS NULL THEN '❌ Missing'
        ELSE '⚠️ Mismatch'
    END as org_id_status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.deleted = false
ORDER BY bil.created_at DESC
LIMIT 10;

-- Step 6: Check for any orphaned BomInstanceLines (without matching BomInstance)
SELECT 
    'Step 6: Orphaned BomInstanceLines Check' as check_type,
    COUNT(*) as orphaned_count
FROM "BomInstanceLines" bil
LEFT JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
AND bi.id IS NULL;








