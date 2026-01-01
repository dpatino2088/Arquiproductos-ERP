-- ====================================================
-- Script: Check UI Data Source for Manufacturing Materials
-- ====================================================
-- The UI uses SaleOrderMaterialList view or BomInstanceLines
-- Let's check both data sources for SO-000008
-- ====================================================

-- Step 1: Check SaleOrderMaterialList view for SO-000008
SELECT 
    'Step 1: SaleOrderMaterialList View' as check_type,
    COUNT(*) as total_rows,
    COUNT(DISTINCT category_code) as distinct_categories,
    STRING_AGG(DISTINCT category_code, ', ' ORDER BY category_code) as categories
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000008' AND deleted = false);

-- Step 2: Check BomInstanceLines for SO-000008
SELECT 
    'Step 2: BomInstanceLines' as check_type,
    COUNT(*) as total_lines,
    COUNT(DISTINCT bil.category_code) as distinct_categories,
    STRING_AGG(DISTINCT bil.category_code, ', ' ORDER BY bil.category_code) as categories
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND so.deleted = false;

-- Step 3: Check QuoteLineComponents (source data)
SELECT 
    'Step 3: QuoteLineComponents (Source)' as check_type,
    COUNT(*) as total_components,
    COUNT(DISTINCT public.derive_category_code_from_role(qlc.component_role)) as distinct_categories,
    STRING_AGG(DISTINCT public.derive_category_code_from_role(qlc.component_role), ', ' ORDER BY public.derive_category_code_from_role(qlc.component_role)) as categories
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component';

-- Step 4: Detailed breakdown by category for QuoteLineComponents
SELECT 
    'Step 4: QuoteLineComponents by Category' as check_type,
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
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY public.derive_category_code_from_role(qlc.component_role), qlc.component_role
ORDER BY category_code, qlc.component_role;

-- Step 5: Detailed breakdown by category for BomInstanceLines
SELECT 
    'Step 5: BomInstanceLines by Category' as check_type,
    bil.category_code,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000008'
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY bil.category_code;

-- Step 6: Check if BomInstances exist for SO-000008
SELECT 
    'Step 6: BomInstances Check' as check_type,
    COUNT(*) as bom_instance_count,
    STRING_AGG(bi.id::text, ', ') as bom_instance_ids
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND so.deleted = false;








