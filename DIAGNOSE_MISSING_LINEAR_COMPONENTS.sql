-- ====================================================
-- DIAGNOSE: Missing Linear Components in BOM
-- ====================================================
-- This script helps identify why components with measure_basis = 'linear_m'
-- are not appearing in the BOM
-- ====================================================

-- Replace 'YOUR_MO_ID_HERE' with actual MO ID (e.g., from MO-000003)
-- First, get the MO ID:
/*
SELECT 
    mo.id,
    mo.manufacturing_order_no,
    mo.status,
    so.sale_order_no
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false;
*/

-- ====================================================
-- STEP 1: Check QuoteLineComponents (SOURCE)
-- ====================================================
-- This shows ALL components that SHOULD be in the BOM
SELECT 
    'QuoteLineComponents (SOURCE)' as source,
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
    so.sale_order_no
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY ci.measure_basis, qlc.component_role, ci.sku;

-- ====================================================
-- STEP 2: Check BomInstanceLines (ACTUAL)
-- ====================================================
-- This shows what's ACTUALLY in the BOM
SELECT 
    'BomInstanceLines (ACTUAL)' as source,
    bil.id as component_id,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.resolved_sku,
    bil.description,
    bil.cut_length_mm,
    bil.cut_width_mm,
    bil.cut_height_mm,
    ci.measure_basis,
    ci.item_type
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND bil.deleted = false
ORDER BY ci.measure_basis, bil.part_role, bil.resolved_sku;

-- ====================================================
-- STEP 3: Find Missing Components
-- ====================================================
-- Components in QuoteLineComponents but NOT in BomInstanceLines
WITH quote_components AS (
    SELECT DISTINCT
        qlc.component_role,
        ci.sku,
        ci.measure_basis,
        ci.item_type,
        qlc.uom
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
    WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
),
bom_components AS (
    SELECT DISTINCT
        bil.part_role,
        bil.resolved_sku,
        ci.measure_basis,
        ci.item_type,
        bil.uom
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
    WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
    AND bil.deleted = false
)
SELECT 
    'MISSING in BOM' as status,
    qc.component_role,
    qc.sku,
    qc.measure_basis,
    qc.item_type,
    qc.uom,
    'Should be in BOM but is missing' as note
FROM quote_components qc
LEFT JOIN bom_components bc ON 
    bc.part_role = qc.component_role 
    AND bc.resolved_sku = qc.sku
WHERE bc.part_role IS NULL
ORDER BY qc.measure_basis, qc.component_role;

-- ====================================================
-- STEP 4: Check UOM Distribution
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
        WHEN ci.measure_basis = 'linear_m' AND bil.uom NOT IN ('m', 'm2') THEN '⚠️ Linear should be m or m2'
        WHEN ci.measure_basis = 'fabric_wxh' AND bil.uom NOT IN ('m2') THEN '⚠️ Fabric should be m2'
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
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ci.measure_basis, ci.item_type, qlc.uom, bil.uom
ORDER BY ci.measure_basis, uom_status;






