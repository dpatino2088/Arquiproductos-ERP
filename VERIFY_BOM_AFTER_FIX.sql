-- ====================================================
-- VERIFY: BOM after UOM normalization fix
-- ====================================================
-- MO-000003: 36245978-4d87-4288-8a7d-b4f3acce9f58
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
WHERE mo.id = '36245978-4d87-4288-8a7d-b4f3acce9f58'  -- MO-000003
AND bil.deleted = false
ORDER BY ci.measure_basis, bil.part_role, bil.resolved_sku;

-- ====================================================
-- STEP 2: Summary by measure_basis (COMPARISON)
-- ====================================================
SELECT 
    ci.measure_basis,
    COUNT(DISTINCT qlc.id) as quote_components,
    COUNT(DISTINCT bil.id) as bom_components,
    STRING_AGG(DISTINCT qlc.uom, ', ' ORDER BY qlc.uom) as quote_uoms,
    STRING_AGG(DISTINCT bil.uom, ', ' ORDER BY bil.uom) as bom_uoms,
    CASE 
        WHEN COUNT(DISTINCT qlc.id) != COUNT(DISTINCT bil.id) THEN '⚠️ Count mismatch'
        WHEN STRING_AGG(DISTINCT qlc.uom, ', ') != STRING_AGG(DISTINCT bil.uom, ', ') THEN '⚠️ UOM mismatch (but may be normalized)'
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

-- ====================================================
-- STEP 3: Check UOM normalization worked
-- ====================================================
SELECT 
    'UOM Normalization Check' as check_type,
    ci.measure_basis,
    COUNT(*) as total_components,
    COUNT(*) FILTER (WHERE bil.uom = 'mts' AND ci.measure_basis = 'linear_m') as linear_m_with_mts,
    COUNT(*) FILTER (WHERE bil.uom = 'm2' AND (ci.measure_basis = 'fabric_wxh' OR ci.item_type = 'fabric')) as fabric_with_m2,
    COUNT(*) FILTER (WHERE bil.uom = 'ea' AND ci.measure_basis = 'unit') as unit_with_ea,
    COUNT(*) FILTER (WHERE bil.uom = 'ea' AND ci.measure_basis = 'linear_m') as linear_m_with_ea_error,
    COUNT(*) FILTER (WHERE bil.uom = 'ea' AND ci.measure_basis = 'fabric_wxh') as fabric_with_ea_error
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.id = '36245978-4d87-4288-8a7d-b4f3acce9f58'  -- MO-000003
AND bil.deleted = false
GROUP BY ci.measure_basis
ORDER BY ci.measure_basis;






