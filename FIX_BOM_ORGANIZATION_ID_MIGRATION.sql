-- ====================================================
-- Fix BOM Organization ID - Complete Migration
-- ====================================================
-- This script:
-- 1. Ensures organization_id column exists in BomInstanceLines
-- 2. Backfills organization_id in BomInstances from SalesOrders
-- 3. Backfills organization_id in BomInstanceLines from BomInstances
-- 4. Backfills quote_line_id in BomInstances from SalesOrderLines
-- 5. Sets deleted=false where NULL
-- 6. Verifies RLS policies
-- ====================================================

-- ====================================================
-- STEP 1: Ensure organization_id column exists in BomInstanceLines
-- ====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'organization_id'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN organization_id uuid;
        
        RAISE NOTICE '✅ Added organization_id column to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️ organization_id column already exists in BomInstanceLines';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Backfill organization_id in BomInstances from SalesOrders
-- ====================================================

UPDATE "BomInstances" bi
SET organization_id = so.organization_id
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id AND so.deleted = false
WHERE bi.sale_order_line_id = sol.id
AND sol.deleted = false
AND bi.deleted = false
AND bi.organization_id IS NULL;

DO $$
DECLARE
    v_updated_count integer;
BEGIN
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % BomInstances with organization_id from SalesOrders', v_updated_count;
END;
$$;

-- ====================================================
-- STEP 3: Backfill quote_line_id in BomInstances from SalesOrderLines
-- ====================================================

UPDATE "BomInstances" bi
SET quote_line_id = sol.quote_line_id
FROM "SalesOrderLines" sol
WHERE bi.sale_order_line_id = sol.id
AND sol.deleted = false
AND bi.deleted = false
AND bi.quote_line_id IS NULL
AND sol.quote_line_id IS NOT NULL;

DO $$
DECLARE
    v_updated_count integer;
BEGIN
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % BomInstances with quote_line_id from SalesOrderLines', v_updated_count;
END;
$$;

-- ====================================================
-- STEP 4: Backfill organization_id in BomInstanceLines from BomInstances
-- ====================================================

UPDATE "BomInstanceLines" bil
SET organization_id = bi.organization_id
FROM "BomInstances" bi
WHERE bil.bom_instance_id = bi.id
AND bi.deleted = false
AND bil.deleted = false
AND bil.organization_id IS NULL
AND bi.organization_id IS NOT NULL;

DO $$
DECLARE
    v_updated_count integer;
BEGIN
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % BomInstanceLines with organization_id from BomInstances', v_updated_count;
END;
$$;

-- ====================================================
-- STEP 5: Set deleted=false where NULL
-- ====================================================

UPDATE "BomInstances"
SET deleted = false
WHERE deleted IS NULL;

UPDATE "BomInstanceLines"
SET deleted = false
WHERE deleted IS NULL;

DO $$
DECLARE
    v_bi_count integer;
    v_bil_count integer;
BEGIN
    SELECT COUNT(*) INTO v_bi_count
    FROM "BomInstances"
    WHERE deleted IS NULL;
    
    SELECT COUNT(*) INTO v_bil_count
    FROM "BomInstanceLines"
    WHERE deleted IS NULL;
    
    IF v_bi_count > 0 OR v_bil_count > 0 THEN
        RAISE NOTICE '✅ Set deleted=false for % BomInstances and % BomInstanceLines', v_bi_count, v_bil_count;
    ELSE
        RAISE NOTICE '⏭️ No NULL deleted values found';
    END IF;
END;
$$;

-- ====================================================
-- STEP 6: Verify RLS Policies
-- ====================================================

DO $$
DECLARE
    v_rls_enabled boolean;
    v_policy_name text;
BEGIN
    -- Check if RLS is enabled
    SELECT relrowsecurity INTO v_rls_enabled
    FROM pg_class
    WHERE relname = 'BomInstanceLines';
    
    IF v_rls_enabled THEN
        RAISE NOTICE '✅ RLS is enabled on BomInstanceLines';
    ELSE
        RAISE WARNING '⚠️ RLS is NOT enabled on BomInstanceLines';
    END IF;
    
    -- List existing policies
    RAISE NOTICE 'Existing RLS policies on BomInstanceLines:';
    FOR v_policy_name IN
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'BomInstanceLines'
    LOOP
        RAISE NOTICE '  - %', v_policy_name;
    END LOOP;
    
    -- If no policies found
    IF NOT FOUND THEN
        RAISE NOTICE '  (No policies found)';
    END IF;
END;
$$;

-- ====================================================
-- STEP 7: Verification Queries
-- ====================================================

-- Check for remaining NULL organization_id
SELECT 
    'Verification: BomInstances with NULL organization_id' as check_type,
    COUNT(*) as count
FROM "BomInstances"
WHERE deleted = false
AND organization_id IS NULL;

SELECT 
    'Verification: BomInstanceLines with NULL organization_id' as check_type,
    COUNT(*) as count
FROM "BomInstanceLines"
WHERE deleted = false
AND organization_id IS NULL;

-- Check specific SO-025080
SELECT 
    'Verification: SO-025080 Data' as check_type,
    so.sale_order_no,
    so.organization_id as so_org_id,
    bi.id as bi_id,
    bi.organization_id as bi_org_id,
    bi.quote_line_id,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id IS NOT NULL) as bom_lines_with_org
FROM "SalesOrders" so
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.organization_id, bi.id, bi.organization_id, bi.quote_line_id;

-- Final verification: Count all BOMs with lines
SELECT 
    'Final Verification: All BOMs' as check_type,
    COUNT(DISTINCT mo.id) as total_mos,
    COUNT(DISTINCT bi.id) as total_bom_instances,
    COUNT(DISTINCT bil.id) as total_bom_lines,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id IS NOT NULL) as bom_lines_with_org,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id IS NULL) as bom_lines_null_org
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
AND mo.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';

