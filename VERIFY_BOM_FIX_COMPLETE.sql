-- ====================================================
-- Verify BOM Fix is Complete
-- ====================================================
-- This script verifies that:
-- 1. All BomInstances have organization_id
-- 2. All BomInstanceLines have organization_id
-- 3. ApprovedBOMList query would return data
-- ====================================================

-- Step 1: Verify BomInstances have organization_id
SELECT 
    'Step 1: BomInstances organization_id Status' as check_type,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE organization_id IS NOT NULL) as with_org_id,
    COUNT(*) FILTER (WHERE organization_id IS NULL) as null_org_id,
    CASE
        WHEN COUNT(*) FILTER (WHERE organization_id IS NULL) = 0 THEN '✅ All have organization_id'
        ELSE '❌ Some have NULL organization_id'
    END as status
FROM "BomInstances"
WHERE deleted = false;

-- Step 2: Verify BomInstanceLines have organization_id
SELECT 
    'Step 2: BomInstanceLines organization_id Status' as check_type,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE organization_id IS NOT NULL) as with_org_id,
    COUNT(*) FILTER (WHERE organization_id IS NULL) as null_org_id,
    CASE
        WHEN COUNT(*) FILTER (WHERE organization_id IS NULL) = 0 THEN '✅ All have organization_id'
        ELSE '❌ Some have NULL organization_id'
    END as status
FROM "BomInstanceLines"
WHERE deleted = false;

-- Step 3: Verify SO-025080 specifically
SELECT 
    'Step 3: SO-025080 Verification' as check_type,
    so.sale_order_no,
    so.organization_id as so_org_id,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id IS NOT NULL) as bom_lines_with_org,
    CASE
        WHEN COUNT(DISTINCT bil.id) > 0 AND COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id IS NOT NULL) = COUNT(DISTINCT bil.id) THEN '✅ All lines have organization_id'
        WHEN COUNT(DISTINCT bil.id) = 0 THEN '⚠️ No BOM lines found'
        ELSE '❌ Some lines missing organization_id'
    END as status
FROM "SalesOrders" so
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.organization_id;

-- Step 4: Simulate ApprovedBOMList query (with organization_id filter)
-- This is what the frontend would execute
SELECT 
    'Step 4: ApprovedBOMList Query Simulation' as check_type,
    mo.manufacturing_order_no,
    so.sale_order_no,
    so.organization_id,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    CASE
        WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅ Would show in ApprovedBOMList'
        ELSE '❌ Would NOT show (no lines)'
    END as status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.deleted = false
    AND bil.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6' -- Frontend filter
WHERE mo.deleted = false
AND mo.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no, so.organization_id
ORDER BY mo.created_at DESC
LIMIT 10;

-- Step 5: Summary for all Manufacturing Orders
SELECT 
    'Step 5: All MOs Summary' as check_type,
    COUNT(DISTINCT mo.id) as total_mos,
    COUNT(DISTINCT bi.id) as total_bom_instances,
    COUNT(DISTINCT bil.id) as total_bom_lines,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6') as bom_lines_for_org,
    CASE
        WHEN COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6') > 0 THEN '✅ ApprovedBOMList will show data'
        ELSE '❌ ApprovedBOMList will be empty'
    END as status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
AND mo.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';






