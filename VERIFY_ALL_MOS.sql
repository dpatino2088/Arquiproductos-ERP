-- Verificar TODOS los MOs
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as lines,
    COUNT(DISTINCT bi.id) as boms,
    COUNT(DISTINCT bil.id) as components,
    CASE 
        WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅ Completo'
        WHEN COUNT(DISTINCT sol.id) = 0 THEN '❌ No lines'
        ELSE '⚠️ No BOMs'
    END as status
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;






