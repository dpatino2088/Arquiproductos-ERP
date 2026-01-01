-- ====================================================
-- Script: Diagnose BOM Workflow - Table and Column Names
-- ====================================================
-- This script verifies the complete workflow from QuoteLineComponents
-- to BomInstanceLines to identify naming inconsistencies
-- ====================================================

-- Step 1: Check component_role values in QuoteLineComponents for SO-000008
SELECT 
    'Step 1: QuoteLineComponents component_role' as check_type,
    qlc.component_role,
    qlc.source,
    COUNT(*) as count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role, qlc.source
ORDER BY qlc.component_role, qlc.source;

-- Step 2: Check what category_code would be derived from these component_role values
SELECT 
    'Step 2: Expected category_code from component_role' as check_type,
    qlc.component_role,
    public.derive_category_code_from_role(qlc.component_role) as expected_category_code,
    COUNT(*) as count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role
ORDER BY qlc.component_role;

-- Step 3: Check part_role and category_code in BomInstanceLines for SO-000008
SELECT 
    'Step 3: BomInstanceLines part_role and category_code' as check_type,
    bil.part_role,
    bil.category_code,
    COUNT(*) as count,
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
GROUP BY bil.part_role, bil.category_code
ORDER BY bil.category_code, bil.part_role;

-- Step 4: Compare QuoteLineComponents vs BomInstanceLines
SELECT 
    'Step 4: Comparison QuoteLineComponents vs BomInstanceLines' as check_type,
    'QuoteLineComponents' as source_table,
    qlc.component_role,
    public.derive_category_code_from_role(qlc.component_role) as expected_category_code,
    COUNT(*) as count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role

UNION ALL

SELECT 
    'Step 4: Comparison QuoteLineComponents vs BomInstanceLines' as check_type,
    'BomInstanceLines' as source_table,
    bil.part_role as component_role,
    bil.category_code as expected_category_code,
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
GROUP BY bil.part_role, bil.category_code

ORDER BY source_table, component_role;

-- Step 5: Check BOMComponents component_role values (what should be generated)
SELECT 
    'Step 5: BOMComponents component_role (Template)' as check_type,
    bc.component_role,
    bc.block_type,
    COUNT(*) as count,
    COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as with_item_id,
    COUNT(*) FILTER (WHERE bc.auto_select = true) as auto_select_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY bc.component_role, bc.block_type
ORDER BY bc.component_role;

-- Step 6: Verify derive_category_code_from_role function patterns
SELECT 
    'Step 6: Test derive_category_code_from_role' as check_type,
    test_role,
    public.derive_category_code_from_role(test_role) as derived_category
FROM (
    SELECT 'fabric' as test_role
    UNION ALL SELECT 'tube'
    UNION ALL SELECT 'motor'
    UNION ALL SELECT 'operating_system_drive'
    UNION ALL SELECT 'bottom_rail_profile'
    UNION ALL SELECT 'side_channel_profile'
    UNION ALL SELECT 'bracket'
    UNION ALL SELECT 'cassette'
    UNION ALL SELECT NULL
) as test_roles
ORDER BY test_role;








