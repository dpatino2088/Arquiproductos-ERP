-- ====================================================
-- Migration 337: Verify BOM Creation Trigger
-- ====================================================
-- Verification script to check if the trigger and function are working correctly
-- ====================================================

-- Step 1: Check if the function exists
SELECT 
    'Function exists' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
            AND p.proname = 'create_bom_instances_for_manufacturing_order'
        ) THEN '✅ Function exists'
        ELSE '❌ Function NOT found'
    END as status;

-- Step 2: Check if the trigger exists
SELECT 
    'Trigger exists' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
            AND c.relname = 'ManufacturingOrders'
            AND t.tgname = 'trg_manufacturing_order_created_create_bom'
            AND t.tgenabled = 'O' -- 'O' = enabled
        ) THEN '✅ Trigger exists and enabled'
        ELSE '❌ Trigger NOT found or disabled'
    END as status;

-- Step 3: Check current state of ManufacturingOrders and BOMs
SELECT 
    'Current State' as check_type,
    COUNT(DISTINCT mo.id) as total_mos,
    COUNT(DISTINCT CASE WHEN bi.id IS NOT NULL THEN mo.id END) as mos_with_bom_instances,
    COUNT(DISTINCT CASE WHEN bi.id IS NULL THEN mo.id END) as mos_without_bom_instances,
    COUNT(DISTINCT bi.id) as total_bom_instances,
    COUNT(DISTINCT bil.id) as total_bom_instance_lines
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false;

-- Step 4: Detailed breakdown by ManufacturingOrder
SELECT 
    mo.manufacturing_order_no,
    mo.id as mo_id,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_instance_lines,
    CASE 
        WHEN COUNT(DISTINCT bi.id) = 0 THEN '❌ No BOM'
        WHEN COUNT(DISTINCT bil.id) = 0 THEN '⚠️ BOM Instances but no Lines'
        ELSE '✅ Complete BOM'
    END as status
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC
LIMIT 10;


