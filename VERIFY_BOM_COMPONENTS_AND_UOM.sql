-- ====================================================
-- VERIFY: BOM Components and UOM
-- ====================================================
-- This script checks what components are in the BOM
-- and verifies their measure_basis and UOM
-- ====================================================

-- Replace 'YOUR_MO_ID_HERE' with actual MO ID
-- Or use this to find MOs with BOM:
/*
SELECT 
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.status,
    so.sale_order_no
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.status = 'planned'
AND mo.deleted = false
ORDER BY mo.created_at DESC
LIMIT 5;
*/

-- ====================================================
-- STEP 1: Check BomInstanceLines for a specific MO
-- ====================================================
-- Replace 'YOUR_MO_ID_HERE' with actual MO ID
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
    ci.item_name as catalog_item_name
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND bil.deleted = false
AND bi.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;

-- ====================================================
-- STEP 2: Check QuoteLineComponents (source of BOM)
-- ====================================================
-- This shows what components SHOULD be in the BOM
SELECT 
    qlc.id,
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
ORDER BY qlc.component_role, ci.measure_basis, ci.sku;

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
    WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
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
    WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
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
SELECT 
    bil.uom,
    ci.measure_basis,
    COUNT(*) as component_count,
    SUM(bil.qty) as total_qty
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'  -- Replace with actual MO ID
AND bil.deleted = false
GROUP BY bil.uom, ci.measure_basis
ORDER BY bil.uom, ci.measure_basis;






