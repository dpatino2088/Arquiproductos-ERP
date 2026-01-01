-- ====================================================
-- QUICK CHECK: MO-000003 Components and UOM
-- ====================================================
-- Replace 'YOUR_MO_ID_HERE' with the actual UUID for MO-000003
-- First get the MO ID:
SELECT 
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.status
FROM "ManufacturingOrders" mo
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false;

-- ====================================================
-- Then use that ID in the queries below:
-- ====================================================

-- 1. What components are in QuoteLineComponents?
SELECT 
    'QuoteLineComponents' as source,
    qlc.component_role,
    ci.sku,
    ci.measure_basis,
    ci.item_type,
    qlc.qty,
    qlc.uom,
    CASE 
        WHEN ci.measure_basis = 'linear_m' AND qlc.uom NOT IN ('m', 'm2') THEN '⚠️ Should be m or m2'
        WHEN ci.measure_basis = 'fabric_wxh' AND qlc.uom != 'm2' THEN '⚠️ Should be m2'
        WHEN ci.measure_basis = 'unit' AND qlc.uom != 'ea' THEN '⚠️ Should be ea'
        ELSE '✅ OK'
    END as uom_check
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY ci.measure_basis, qlc.component_role;

-- 2. What components are in BomInstanceLines?
SELECT 
    'BomInstanceLines' as source,
    bil.part_role,
    bil.resolved_sku,
    ci.measure_basis,
    ci.item_type,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.cut_width_mm,
    bil.cut_height_mm
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND bil.deleted = false
ORDER BY ci.measure_basis, bil.part_role;

-- 3. Summary by measure_basis
SELECT 
    ci.measure_basis,
    COUNT(DISTINCT qlc.id) as quote_components,
    COUNT(DISTINCT bil.id) as bom_components,
    COUNT(DISTINCT qlc.id) - COUNT(DISTINCT bil.id) as missing
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
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ci.measure_basis
ORDER BY ci.measure_basis;






