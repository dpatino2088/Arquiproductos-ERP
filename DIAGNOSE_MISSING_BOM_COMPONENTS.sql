-- ====================================================
-- Script: Diagnose Missing BOM Components
-- ====================================================
-- This script checks what components exist in QuoteLineComponents
-- vs what exists in BomInstanceLines to identify missing components
-- ====================================================

-- Check 1: QuoteLineComponents by component_role
SELECT 
    'QuoteLineComponents by Role' as check_type,
    qlc.component_role,
    COUNT(*) as count,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLineComponents" qlc
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY qlc.component_role
ORDER BY count DESC;

-- Check 2: BomInstanceLines by category_code
SELECT 
    'BomInstanceLines by Category' as check_type,
    bil.category_code,
    bil.part_role,
    COUNT(*) as count,
    COUNT(DISTINCT bil.bom_instance_id) as bom_instances_count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "BomInstanceLines" bil
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.deleted = false
GROUP BY bil.category_code, bil.part_role
ORDER BY bil.category_code, count DESC;

-- Check 3: Compare QuoteLineComponents vs BomInstanceLines for a specific Sale Order
SELECT 
    'Comparison for SO-000008' as check_type,
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
GROUP BY qlc.component_role

UNION ALL

SELECT 
    'Comparison for SO-000008' as check_type,
    'BomInstanceLines' as source,
    bil.part_role as component_role,
    COUNT(*) as count
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
GROUP BY bil.part_role

ORDER BY source, component_role;

-- Check 4: Check if BomInstances exist for the Sale Order
SELECT 
    'BomInstances Check' as check_type,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT sol.id) as sale_order_lines_count,
    COUNT(DISTINCT bil.id) as bom_instance_lines_count
FROM "SaleOrders" so
LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND so.deleted = false
GROUP BY so.sale_order_no;








