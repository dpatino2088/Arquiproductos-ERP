-- ====================================================
-- COMPLETE FIX: BOM Generation + UOM Normalization for MO-000003
-- ====================================================
-- This script:
-- 1. Updates generate_bom_for_manufacturing_order with UOM normalization
-- 2. Regenerates the BOM for MO-000003
-- 3. Verifies the results
-- ====================================================

-- ====================================================
-- STEP 1: Update the function with UOM normalization
-- ====================================================
-- (The full function definition is in FIX_UOM_NORMALIZATION_LINEAR_M.sql)
-- For now, we'll just regenerate the BOM after applying the fix separately

-- ====================================================
-- STEP 2: Regenerate BOM for MO-000003
-- ====================================================
-- This will use the updated function (if already applied)
-- or the current function (which we'll fix next)
SELECT public.generate_bom_for_manufacturing_order('36245978-4d87-4288-8a7d-b4f3acce9f58');

-- ====================================================
-- STEP 3: Verify results
-- ====================================================
SELECT 
    ci.measure_basis,
    COUNT(DISTINCT qlc.id) as quote_components,
    COUNT(DISTINCT bil.id) as bom_components,
    STRING_AGG(DISTINCT qlc.uom, ', ' ORDER BY qlc.uom) as quote_uoms,
    STRING_AGG(DISTINCT bil.uom, ', ' ORDER BY bil.uom) as bom_uoms,
    CASE 
        WHEN COUNT(DISTINCT qlc.id) != COUNT(DISTINCT bil.id) THEN '⚠️ Count mismatch'
        WHEN STRING_AGG(DISTINCT qlc.uom, ', ') != STRING_AGG(DISTINCT bil.uom, ', ') THEN '⚠️ UOM mismatch'
        ELSE '✅ OK'
    END as status
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.resolved_part_id = qlc.catalog_item_id 
    AND bil.deleted = false
WHERE mo.id = '36245978-4d87-4288-8a7d-b4f3acce9f58'  -- MO-000003
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ci.measure_basis
ORDER BY ci.measure_basis;






