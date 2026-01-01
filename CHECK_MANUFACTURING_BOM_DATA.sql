-- ====================================================
-- Script: Check Manufacturing BOM Data
-- ====================================================
-- This script checks what data is available for Manufacturing BOM
-- and compares it with what should be displayed
-- ====================================================

-- Step 1: Check SaleOrderMaterialList view (primary source)
SELECT 
    'Step 1: SaleOrderMaterialList View' as check_type,
    sale_order_id,
    category_code,
    COUNT(*) as component_count,
    SUM(total_qty) as total_qty,
    STRING_AGG(DISTINCT uom, ', ' ORDER BY uom) as uoms
FROM "SaleOrderMaterialList"
WHERE sale_order_id IN (
    SELECT id FROM "SaleOrders" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 5
)
GROUP BY sale_order_id, category_code
ORDER BY sale_order_id, category_code;

-- Step 2: Check BomInstanceLines directly
SELECT 
    'Step 2: BomInstanceLines Direct' as check_type,
    sol.sale_order_id,
    bil.category_code,
    COUNT(*) as component_count,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT bil.uom, ', ' ORDER BY bil.uom) as uoms
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
WHERE sol.sale_order_id IN (
    SELECT id FROM "SaleOrders" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 5
)
AND bil.deleted = false
GROUP BY sol.sale_order_id, bil.category_code
ORDER BY sol.sale_order_id, bil.category_code;

-- Step 3: Check QuoteLineComponents (source of truth)
SELECT 
    'Step 3: QuoteLineComponents' as check_type,
    q.organization_id,
    ql.id as quote_line_id,
    COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
    COUNT(*) as component_count,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT qlc.uom, ', ' ORDER BY qlc.uom) as uoms
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
AND ql.id IN (
    SELECT ql2.id 
    FROM "QuoteLines" ql2
    INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql2.id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.deleted = false
    ORDER BY so.created_at DESC
    LIMIT 5
)
GROUP BY q.organization_id, ql.id, category_code
ORDER BY ql.id, category_code;

-- Step 4: Compare counts by category for latest Sale Order
WITH latest_so AS (
    SELECT id, sale_order_no
    FROM "SaleOrders"
    WHERE deleted = false
    ORDER BY created_at DESC
    LIMIT 1
),
material_list AS (
    SELECT 
        'SaleOrderMaterialList' as source,
        category_code,
        COUNT(*) as count,
        SUM(total_qty) as total_qty
    FROM "SaleOrderMaterialList"
    WHERE sale_order_id = (SELECT id FROM latest_so)
    GROUP BY category_code
),
bom_lines AS (
    SELECT 
        'BomInstanceLines' as source,
        bil.category_code,
        COUNT(*) as count,
        SUM(bil.qty) as total_qty
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = (SELECT id FROM latest_so)
    AND bil.deleted = false
    GROUP BY bil.category_code
),
quote_components AS (
    SELECT 
        'QuoteLineComponents' as source,
        COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
        COUNT(*) as count,
        SUM(qlc.qty) as total_qty
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
    WHERE sol.sale_order_id = (SELECT id FROM latest_so)
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    GROUP BY category_code
)
SELECT 
    'Step 4: Comparison for Latest Sale Order' as check_type,
    (SELECT sale_order_no FROM latest_so) as sale_order_no,
    COALESCE(ml.category_code, bl.category_code, qc.category_code) as category_code,
    COALESCE(ml.count, 0) as material_list_count,
    COALESCE(bl.count, 0) as bom_lines_count,
    COALESCE(qc.count, 0) as quote_components_count,
    CASE 
        WHEN COALESCE(ml.count, 0) = COALESCE(bl.count, 0) AND COALESCE(bl.count, 0) = COALESCE(qc.count, 0) THEN '✅ MATCH'
        WHEN COALESCE(ml.count, 0) < COALESCE(qc.count, 0) THEN '⚠️ MaterialList missing components'
        WHEN COALESCE(bl.count, 0) < COALESCE(qc.count, 0) THEN '⚠️ BomInstanceLines missing components'
        ELSE '❌ MISMATCH'
    END as status
FROM material_list ml
FULL OUTER JOIN bom_lines bl ON bl.category_code = ml.category_code
FULL OUTER JOIN quote_components qc ON qc.category_code = COALESCE(ml.category_code, bl.category_code)
ORDER BY category_code;

-- Step 5: Check UOM for fabrics specifically
SELECT 
    'Step 5: Fabric UOM Check' as check_type,
    'SaleOrderMaterialList' as source,
    category_code,
    uom,
    COUNT(*) as count,
    SUM(total_qty) as total_qty
FROM "SaleOrderMaterialList"
WHERE category_code = 'fabric'
AND sale_order_id IN (
    SELECT id FROM "SaleOrders" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 5
)
GROUP BY category_code, uom
ORDER BY uom;

-- Step 6: List all categories present in latest Sale Order
WITH latest_so AS (
    SELECT id, sale_order_no
    FROM "SaleOrders"
    WHERE deleted = false
    ORDER BY created_at DESC
    LIMIT 1
)
SELECT 
    'Step 6: All Categories in Latest Sale Order' as check_type,
    (SELECT sale_order_no FROM latest_so) as sale_order_no,
    category_code,
    COUNT(*) as component_count,
    SUM(total_qty) as total_qty,
    STRING_AGG(DISTINCT uom, ', ' ORDER BY uom) as uoms
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM latest_so)
GROUP BY category_code
ORDER BY category_code;

-- Step 7: Detailed breakdown of components by category for latest SO
WITH latest_so AS (
    SELECT id, sale_order_no
    FROM "SaleOrders"
    WHERE deleted = false
    ORDER BY created_at DESC
    LIMIT 1
)
SELECT 
    'Step 7: Detailed Components by Category' as check_type,
    (SELECT sale_order_no FROM latest_so) as sale_order_no,
    category_code,
    sku,
    item_name,
    uom,
    total_qty,
    avg_unit_cost_exw,
    total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM latest_so)
ORDER BY category_code, sku;
