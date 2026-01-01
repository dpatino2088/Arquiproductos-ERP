-- Verificar SO-090022 y SO-011555
SELECT 
    'SO Details' as tipo,
    so.sale_order_no,
    so.quote_id,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT mo.id) as manufacturing_orders,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_instance_lines
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-090022', 'SO-011555', 'SO-000001')
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.quote_id
ORDER BY so.sale_order_no;

-- Ver qué Manufacturing Orders tienen
SELECT 
    'Manufacturing Orders' as tipo,
    mo.manufacturing_order_no,
    mo.sale_order_id,
    so.sale_order_no,
    mo.deleted as mo_deleted
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE so.sale_order_no IN ('SO-090022', 'SO-011555', 'SO-000001')
ORDER BY mo.created_at DESC;






