-- Verificación rápida del último MO
SELECT 
    mo.manufacturing_order_no,
    mo.created_at,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT ql.id) as quote_lines,
    COUNT(DISTINCT qlc.id) as quote_line_components,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_instance_lines,
    CASE 
        WHEN COUNT(DISTINCT qlc.id) = 0 THEN '❌ NO HAY QuoteLineComponents'
        WHEN COUNT(DISTINCT bi.id) = 0 THEN '❌ NO HAY BomInstances'
        WHEN COUNT(DISTINCT bil.id) = 0 THEN '❌ NO HAY BomInstanceLines'
        ELSE '✅ TODO OK'
    END as diagnostico
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, mo.created_at, so.sale_order_no
ORDER BY mo.created_at DESC
LIMIT 1;






