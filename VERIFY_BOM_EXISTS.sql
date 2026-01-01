-- ====================================================
-- Verificar si existen BOMs para los Sales Orders
-- ====================================================

-- 1. Verificar si existe la vista SalesOrderMaterialList
SELECT 
    'SalesOrderMaterialList View' as check_item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.views 
            WHERE table_schema = 'public' 
            AND table_name = 'SalesOrderMaterialList'
        ) THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status;

-- 2. Verificar BomInstances para SO-000023
SELECT 
    'BomInstances for SO-000023' as check_item,
    COUNT(*) as total
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000023'
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false;

-- 3. Verificar BomInstanceLines
SELECT 
    'BomInstanceLines for SO-000023' as check_item,
    COUNT(*) as total
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000023'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false;

-- 4. Lista completa de Sales Orders con sus BOMs
SELECT 
    so.sale_order_no,
    so.status as so_status,
    mo.manufacturing_order_no,
    mo.status as mo_status,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    CASE 
        WHEN COUNT(DISTINCT bi.id) > 0 THEN '✅ Has BOM'
        ELSE '❌ No BOM'
    END as bom_status
FROM "SalesOrders" so
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no, so.status, mo.manufacturing_order_no, mo.status
ORDER BY so.created_at DESC;






