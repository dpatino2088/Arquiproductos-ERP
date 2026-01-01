-- Verificar organization_id de los Sales Orders
SELECT 
    'Sales Orders Organization' as tipo,
    so.sale_order_no,
    so.organization_id,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT mo.id) as manufacturing_orders,
    COUNT(DISTINCT bi.id) as bom_instances
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no IN ('SO-090022', 'SO-011555', 'SO-000001')
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.organization_id;

-- Ver todas las organizaciones
SELECT 
    'All Organizations' as tipo,
    id
FROM "Organizations"
WHERE deleted = false;

