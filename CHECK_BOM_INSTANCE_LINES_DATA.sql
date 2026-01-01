-- ====================================================
-- Script: Check BomInstanceLines Data for SO-000008
-- ====================================================
-- This script verifies what data exists in BomInstanceLines
-- and compares it with what the UI should display
-- ====================================================

-- Check 1: What's in BomInstanceLines for SO-000008?
SELECT 
    'BomInstanceLines Data' as check_type,
    bil.category_code,
    bil.part_role,
    bil.resolved_part_id,
    ci.sku,
    ci.item_name,
    bil.qty,
    bil.uom,
    bil.unit_cost_exw,
    bil.total_cost_exw
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false
ORDER BY bil.category_code, bil.part_role, ci.sku;

-- Check 2: Summary by category_code
SELECT 
    'Summary by Category' as check_type,
    bil.category_code,
    COUNT(*) as line_count,
    COUNT(DISTINCT bil.resolved_part_id) as unique_parts,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY line_count DESC;

-- Check 3: What does SaleOrderMaterialList view return?
SELECT 
    'SaleOrderMaterialList View' as check_type,
    category_code,
    catalog_item_id,
    sku,
    item_name,
    uom,
    total_qty,
    avg_unit_cost_exw,
    total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (
    SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000008' AND deleted = false LIMIT 1
)
ORDER BY category_code, sku;

-- Check 4: Compare QuoteLineComponents vs BomInstanceLines
SELECT 
    'Comparison' as check_type,
    'QuoteLineComponents' as source,
    qlc.component_role,
    COUNT(*) as count
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000008'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role

UNION ALL

SELECT 
    'Comparison' as check_type,
    'BomInstanceLines' as source,
    bil.part_role as component_role,
    COUNT(*) as count
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false
GROUP BY bil.part_role

ORDER BY source, component_role;








