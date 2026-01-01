-- Ver organization_id y estado de los 3 SOs
SELECT 
    so.sale_order_no,
    so.organization_id,
    COUNT(DISTINCT sol.id) as lines,
    COUNT(DISTINCT mo.id) as mos,
    COUNT(DISTINCT bi.id) as boms,
    COUNT(DISTINCT bil.id) as components
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-090022', 'SO-011555', 'SO-000001')
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.organization_id
ORDER BY so.sale_order_no;






