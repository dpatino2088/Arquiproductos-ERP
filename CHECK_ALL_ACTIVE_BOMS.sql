-- Ver TODOS los Sales Orders con MOs activos y sus BOMs
SELECT 
    so.sale_order_no,
    mo.manufacturing_order_no,
    mo.deleted as mo_deleted,
    COUNT(DISTINCT sol.id) as lines,
    COUNT(DISTINCT bi.id) as boms,
    COUNT(DISTINCT bil.id) as components
FROM "SalesOrders" so
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
AND mo.id IS NOT NULL
GROUP BY so.id, so.sale_order_no, mo.id, mo.manufacturing_order_no, mo.deleted
ORDER BY mo.deleted ASC, so.created_at DESC;






