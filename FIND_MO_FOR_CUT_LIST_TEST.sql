-- ====================================================
-- FIND: ManufacturingOrder with status = 'planned' for testing
-- ====================================================
-- This query finds MOs that are ready for cut list generation
-- ====================================================

-- Find all ManufacturingOrders with status = 'planned'
SELECT 
    mo.id as manufacturing_order_id,
    mo.manufacturing_order_no,
    mo.status,
    mo.organization_id,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.status = 'planned'
AND mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, mo.status, mo.organization_id, so.sale_order_no
HAVING COUNT(DISTINCT bil.id) > 0  -- Only MOs with BOM lines
ORDER BY mo.created_at DESC
LIMIT 5;

-- ====================================================
-- ALTERNATIVE: Find any MO with BOM lines (even if status != 'planned')
-- ====================================================
/*
SELECT 
    mo.id as manufacturing_order_id,
    mo.manufacturing_order_no,
    mo.status,
    COUNT(DISTINCT bil.id) as bom_lines_count
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, mo.status
HAVING COUNT(DISTINCT bil.id) > 0
ORDER BY mo.created_at DESC
LIMIT 10;
*/






