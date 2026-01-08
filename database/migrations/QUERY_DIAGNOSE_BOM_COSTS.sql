-- Diagnostic query to check BOM costs
-- Run this after clicking "Generate BOM" to see what was created

SELECT 
    bil.id as bom_line_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    ci.cost_exw as catalog_item_cost_exw,
    ci.msrp as catalog_item_msrp,
    bi.id as bom_instance_id,
    sol.id as sale_order_line_id,
    sol.line_number,
    ql.bom_template_id
FROM "BomInstanceLines" bil
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
LEFT JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE bi.sale_order_line_id IN (
    SELECT id FROM "SalesOrderLines" 
    WHERE sale_order_id IN (
        SELECT id FROM "SalesOrders" 
        WHERE order_number = 'SO-090163'
    )
)
AND bil.deleted = false
ORDER BY bil.created_at DESC
LIMIT 50;

-- Summary: Count lines with/without costs
SELECT 
    COUNT(*) as total_lines,
    COUNT(CASE WHEN unit_cost_exw IS NOT NULL AND unit_cost_exw > 0 THEN 1 END) as lines_with_cost,
    COUNT(CASE WHEN unit_cost_exw IS NULL OR unit_cost_exw = 0 THEN 1 END) as lines_without_cost,
    SUM(CASE WHEN total_cost_exw IS NOT NULL THEN total_cost_exw ELSE 0 END) as total_cost_sum
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id IN (
    SELECT id FROM "BomInstances" 
    WHERE sale_order_line_id IN (
        SELECT id FROM "SalesOrderLines" 
        WHERE sale_order_id IN (
            SELECT id FROM "SalesOrders" 
            WHERE order_number = 'SO-090163'
        )
    )
)
AND bil.deleted = false;


