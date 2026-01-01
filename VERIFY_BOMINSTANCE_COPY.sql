-- ====================================================
-- Script: Verify BomInstanceLines Copy
-- ====================================================
-- Check what was actually copied to BomInstanceLines
-- ====================================================

-- Step 1: Check QuoteLineComponents (source data)
SELECT 
    'Step 1: QuoteLineComponents (Source)' as check_type,
    public.derive_category_code_from_role(qlc.component_role) as category_code,
    qlc.component_role,
    COUNT(*) as count,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY public.derive_category_code_from_role(qlc.component_role), qlc.component_role
ORDER BY category_code, qlc.component_role;

-- Step 2: Check BomInstanceLines (copied data)
SELECT 
    'Step 2: BomInstanceLines (Copied)' as check_type,
    bil.category_code,
    bil.part_role,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND so.deleted = false
GROUP BY bil.category_code, bil.part_role
ORDER BY bil.category_code, bil.part_role;

-- Step 3: Check SaleOrderMaterialList view
SELECT 
    'Step 3: SaleOrderMaterialList View' as check_type,
    category_code,
    COUNT(*) as count,
    SUM(total_qty) as total_qty,
    STRING_AGG(DISTINCT sku, ', ' ORDER BY sku) FILTER (WHERE sku IS NOT NULL) as sample_skus
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no IN ('SO-000008', '50-000008') AND deleted = false LIMIT 1)
GROUP BY category_code
ORDER BY category_code;

-- Step 4: Detailed comparison - QuoteLineComponents vs BomInstanceLines
SELECT 
    'Step 4: Comparison' as check_type,
    public.derive_category_code_from_role(qlc.component_role) as qlc_category,
    bil.category_code as bil_category,
    COUNT(DISTINCT qlc.id) as qlc_count,
    COUNT(DISTINCT bil.id) as bil_count,
    CASE 
        WHEN COUNT(DISTINCT qlc.id) = COUNT(DISTINCT bil.id) THEN '✅ Match'
        WHEN COUNT(DISTINCT bil.id) = 0 THEN '❌ Missing in BomInstanceLines'
        ELSE '⚠️ Partial match'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.resolved_part_id = qlc.catalog_item_id 
    AND bil.part_role = qlc.component_role
    AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY public.derive_category_code_from_role(qlc.component_role), bil.category_code
ORDER BY qlc_category;








