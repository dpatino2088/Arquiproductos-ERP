-- ====================================================
-- VERIFY: BOM Components and UOM for MO-000004
-- ====================================================
-- MO ID: cda86b7a-ce4b-427d-95dc-838e8e12a65e
-- ====================================================

-- ====================================================
-- STEP 1: Check BomInstanceLines (ACTUAL BOM)
-- ====================================================
SELECT 
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    ci.measure_basis,
    ci.item_type,
    CASE 
        WHEN ci.measure_basis = 'linear_m' AND bil.uom NOT IN ('m', 'mts', 'm2') THEN '⚠️ Linear should be m/mts/m2'
        WHEN ci.measure_basis = 'fabric_wxh' AND bil.uom NOT IN ('m2', 'yd2') THEN '⚠️ Fabric should be m2'
        WHEN ci.measure_basis = 'unit' AND bil.uom != 'ea' THEN '⚠️ Unit should be ea'
        ELSE '✅ OK'
    END as uom_status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.id = 'cda86b7a-ce4b-427d-95dc-838e8e12a65e'  -- MO-000004
AND bil.deleted = false
ORDER BY ci.measure_basis, bil.part_role, bil.resolved_sku;

-- ====================================================
-- STEP 2: Check QuoteLineComponents (SOURCE)
-- ====================================================
SELECT 
    qlc.component_role,
    ci.sku,
    ci.measure_basis,
    ci.item_type,
    qlc.qty,
    qlc.uom,
    CASE 
        WHEN ci.measure_basis = 'linear_m' AND qlc.uom NOT IN ('m', 'mts', 'm2') THEN '⚠️ Linear should be m/mts/m2'
        WHEN ci.measure_basis = 'fabric_wxh' AND qlc.uom NOT IN ('m2', 'yd2') THEN '⚠️ Fabric should be m2'
        WHEN ci.measure_basis = 'unit' AND qlc.uom != 'ea' THEN '⚠️ Unit should be ea'
        ELSE '✅ OK'
    END as uom_status
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
WHERE mo.id = 'cda86b7a-ce4b-427d-95dc-838e8e12a65e'  -- MO-000004
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY ci.measure_basis, qlc.component_role, ci.sku;

-- ====================================================
-- STEP 3: Summary by measure_basis
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
WHERE mo.id = 'cda86b7a-ce4b-427d-95dc-838e8e12a65e'  -- MO-000004
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ci.measure_basis
ORDER BY ci.measure_basis;






