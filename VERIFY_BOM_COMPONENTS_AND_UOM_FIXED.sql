-- ====================================================
-- VERIFY: BOM Components and UOM
-- ====================================================
-- This script checks what components are in the BOM
-- and verifies their measure_basis and UOM
-- ====================================================
-- 
-- IMPORTANT: First run GET_MO_ID_FIRST.sql to get the MO ID
-- Then replace 'YOUR_MO_ID_HERE' below with the actual UUID
-- ====================================================

-- ====================================================
-- STEP 1: Check BomInstanceLines for a specific MO
-- ====================================================
-- Replace 'YOUR_MO_ID_HERE' with actual MO ID from GET_MO_ID_FIRST.sql
SELECT 
    bil.id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.cut_width_mm,
    bil.cut_height_mm,
    bil.calc_notes,
    bil.description,
    ci.measure_basis,
    ci.item_type,
    ci.sku as catalog_sku,
    ci.item_name as catalog_item_name,
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
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- ⚠️ REPLACE THIS with actual UUID from GET_MO_ID_FIRST.sql
AND bil.deleted = false
ORDER BY ci.measure_basis, bil.part_role, bil.resolved_sku;

-- ====================================================
-- STEP 2: Check QuoteLineComponents (source of BOM)
-- ====================================================
-- This shows what components SHOULD be in the BOM
SELECT 
    qlc.id as component_id,
    qlc.component_role,
    qlc.qty,
    qlc.uom,
    qlc.source,
    ci.sku,
    ci.item_name,
    ci.measure_basis,
    ci.item_type,
    ql.id as quote_line_id,
    so.sale_order_no,
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
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- ⚠️ REPLACE THIS with actual UUID from GET_MO_ID_FIRST.sql
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY ci.measure_basis, qlc.component_role, ci.sku;

-- ====================================================
-- STEP 3: Compare BOM vs QuoteLineComponents
-- ====================================================
-- This shows what's missing or different
WITH bom_components AS (
    SELECT 
        bil.resolved_sku,
        bil.part_role,
        bil.qty,
        bil.uom,
        COUNT(*) as bom_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = 'YOUR_MO_ID_HERE'  -- ⚠️ REPLACE THIS with actual UUID from GET_MO_ID_FIRST.sql
    AND bil.deleted = false
    GROUP BY bil.resolved_sku, bil.part_role, bil.qty, bil.uom
),
quote_components AS (
    SELECT 
        ci.sku,
        qlc.component_role,
        qlc.qty,
        qlc.uom,
        ci.measure_basis,
        COUNT(*) as quote_count
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
    WHERE mo.id = 'YOUR_MO_ID_HERE'  -- ⚠️ REPLACE THIS with actual UUID from GET_MO_ID_FIRST.sql
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    GROUP BY ci.sku, qlc.component_role, qlc.qty, qlc.uom, ci.measure_basis
)
SELECT 
    'In Quote but NOT in BOM' as status,
    qc.sku,
    qc.component_role,
    qc.measure_basis,
    qc.qty,
    qc.uom
FROM quote_components qc
LEFT JOIN bom_components bc ON bc.resolved_sku = qc.sku AND bc.part_role = qc.component_role
WHERE bc.resolved_sku IS NULL
UNION ALL
SELECT 
    'In BOM but NOT in Quote' as status,
    bc.resolved_sku,
    bc.part_role,
    NULL as measure_basis,
    bc.qty,
    bc.uom
FROM bom_components bc
LEFT JOIN quote_components qc ON qc.sku = bc.resolved_sku AND qc.component_role = bc.part_role
WHERE qc.sku IS NULL
ORDER BY status, component_role;

-- ====================================================
-- STEP 4: Check UOM distribution
-- ====================================================
-- Verify UOM matches measure_basis
SELECT 
    ci.measure_basis,
    ci.item_type,
    qlc.uom as quote_uom,
    bil.uom as bom_uom,
    COUNT(*) as count,
    CASE 
        WHEN qlc.uom != bil.uom THEN '⚠️ UOM MISMATCH'
        WHEN ci.measure_basis = 'linear_m' AND bil.uom NOT IN ('m', 'mts', 'm2') THEN '⚠️ Linear should be m/mts/m2'
        WHEN ci.measure_basis = 'fabric_wxh' AND bil.uom NOT IN ('m2', 'yd2') THEN '⚠️ Fabric should be m2'
        WHEN ci.measure_basis = 'unit' AND bil.uom != 'ea' THEN '⚠️ Unit should be ea'
        ELSE '✅ OK'
    END as uom_status
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
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- ⚠️ REPLACE THIS with actual UUID from GET_MO_ID_FIRST.sql
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ci.measure_basis, ci.item_type, qlc.uom, bil.uom
ORDER BY ci.measure_basis, uom_status;






