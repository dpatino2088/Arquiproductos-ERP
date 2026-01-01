-- ====================================================
-- Script: Verify SO-000010 After Fix
-- ====================================================
-- This script verifies what happened after running FIX_SO_000010
-- ====================================================

-- Step 1: Check if product_type_id was updated
SELECT 
    'Step 1: QuoteLine product_type_id' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.catalog_item_id,
    ci.item_name as catalog_item_name
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;

-- Step 2: Check active BOMTemplate and components
SELECT 
    'Step 2: BOMTemplate Components' as check_type,
    ql.product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    bt.active,
    bc.id as component_id,
    bc.component_role,
    bc.component_item_id,
    bc.auto_select,
    bc.block_condition,
    bc.applies_color,
    ci.sku as component_sku,
    ci.item_name as component_name
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
ORDER BY bc.component_role, ci.sku;

-- Step 3: Check QuoteLineComponents (what was generated)
SELECT 
    'Step 3: QuoteLineComponents Generated' as check_type,
    COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom,
    qlc.component_role,
    qlc.source
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY category_code, ci.sku;

-- Step 4: Check BomInstanceLines (what was copied)
SELECT 
    'Step 4: BomInstanceLines' as check_type,
    bil.category_code,
    ci.sku,
    ci.item_name,
    bil.qty,
    bil.uom,
    bil.part_role,
    bil.description
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000010'
AND bil.deleted = false
ORDER BY bil.category_code, ci.sku;

-- Step 5: Check QuoteLine configuration (block conditions)
SELECT 
    'Step 5: QuoteLine Configuration' as check_type,
    ql.id as quote_line_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.cassette_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;

-- Step 6: Compare counts
WITH quote_components AS (
    SELECT 
        COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
        COUNT(*) as count
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.sale_order_no = 'SO-000010'
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    GROUP BY category_code
),
bom_lines AS (
    SELECT 
        bil.category_code,
        COUNT(*) as count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.sale_order_no = 'SO-000010'
    AND bil.deleted = false
    GROUP BY bil.category_code
),
material_list AS (
    SELECT 
        category_code,
        COUNT(*) as count
    FROM "SaleOrderMaterialList"
    WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000010' AND deleted = false)
    GROUP BY category_code
)
SELECT 
    'Step 6: Comparison' as check_type,
    COALESCE(qc.category_code, bl.category_code, ml.category_code) as category_code,
    COALESCE(qc.count, 0) as quote_components,
    COALESCE(bl.count, 0) as bom_lines,
    COALESCE(ml.count, 0) as material_list,
    CASE 
        WHEN COALESCE(qc.count, 0) = 0 THEN '❌ Not generated'
        WHEN COALESCE(qc.count, 0) > 0 AND COALESCE(bl.count, 0) = 0 THEN '❌ Not copied to BomInstanceLines'
        WHEN COALESCE(bl.count, 0) > 0 AND COALESCE(ml.count, 0) = 0 THEN '❌ Not in MaterialList view'
        WHEN COALESCE(qc.count, 0) = COALESCE(bl.count, 0) AND COALESCE(bl.count, 0) = COALESCE(ml.count, 0) THEN '✅ All match'
        ELSE '⚠️ Partial match'
    END as status
FROM quote_components qc
FULL OUTER JOIN bom_lines bl ON bl.category_code = qc.category_code
FULL OUTER JOIN material_list ml ON ml.category_code = COALESCE(qc.category_code, bl.category_code)
ORDER BY category_code;








