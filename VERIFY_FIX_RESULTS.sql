-- Verificar si el script FIX_COMPLETE_FLOW_QUOTE_TO_BOM.sql funcionó
SELECT 
    'Después del Fix' as estado,
    COUNT(DISTINCT so.id) as sales_orders,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT qlc.id) as quote_line_components,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_instance_lines
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false;

-- Ver detalles de cada MO
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sol_count,
    COUNT(DISTINCT bi.id) as bi_count,
    COUNT(DISTINCT bil.id) as bil_count,
    CASE 
        WHEN COUNT(DISTINCT sol.id) = 0 THEN '❌ No SalesOrderLines'
        WHEN COUNT(DISTINCT bi.id) = 0 THEN '❌ No BomInstances'
        WHEN COUNT(DISTINCT bil.id) = 0 THEN '❌ No BomInstanceLines'
        ELSE '✅ Completo'
    END as status
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;






