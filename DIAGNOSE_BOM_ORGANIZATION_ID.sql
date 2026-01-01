-- ====================================================
-- Diagnose BOM Organization ID Issues
-- ====================================================
-- This script checks for NULL organization_id in BomInstances and BomInstanceLines
-- ====================================================

-- Step 1: Check BomInstances with NULL organization_id
SELECT 
    'Step 1: BomInstances with NULL organization_id' as check_type,
    COUNT(*) as count_with_null_org,
    COUNT(*) FILTER (WHERE organization_id IS NULL) as null_count,
    COUNT(*) FILTER (WHERE organization_id IS NOT NULL) as has_org_count
FROM "BomInstances"
WHERE deleted = false;

-- Step 2: Check BomInstanceLines with NULL organization_id
SELECT 
    'Step 2: BomInstanceLines with NULL organization_id' as check_type,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE organization_id IS NULL) as null_count,
    COUNT(*) FILTER (WHERE organization_id IS NOT NULL) as has_org_count
FROM "BomInstanceLines"
WHERE deleted = false;

-- Step 3: Check specific SO-025080 data
SELECT 
    'Step 3: SO-025080 Data Check' as check_type,
    so.sale_order_no,
    so.organization_id as so_org_id,
    sol.id as sol_id,
    sol.organization_id as sol_org_id,
    bi.id as bi_id,
    bi.organization_id as bi_org_id,
    bi.quote_line_id,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.organization_id IS NULL) as bom_lines_null_org
FROM "SalesOrders" so
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.organization_id, sol.id, sol.organization_id, bi.id, bi.organization_id, bi.quote_line_id;

-- Step 4: Check RLS Policies on BomInstanceLines
SELECT 
    'Step 4: RLS Policies on BomInstanceLines' as check_type,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'BomInstanceLines'
ORDER BY policyname;

-- Step 5: Check if organization_id column exists in BomInstanceLines
SELECT 
    'Step 5: BomInstanceLines Schema' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN ('organization_id', 'bom_instance_id', 'deleted')
ORDER BY ordinal_position;

-- Step 6: Sample data - Show BomInstanceLines for SO-025080
SELECT 
    'Step 6: Sample BomInstanceLines for SO-025080' as check_type,
    bil.id,
    bil.bom_instance_id,
    bil.organization_id,
    bil.resolved_sku,
    bil.description,
    bil.qty,
    bil.deleted,
    bi.organization_id as bi_org_id,
    so.organization_id as so_org_id
FROM "SalesOrders" so
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND so.deleted = false
LIMIT 10;






