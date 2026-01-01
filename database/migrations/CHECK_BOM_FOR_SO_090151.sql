-- ====================================================
-- Check BOM for SO-090151
-- ====================================================
-- Verify if BomInstance and BomInstanceLines exist
-- ====================================================

-- 1. Find the SalesOrder
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted
FROM "SalesOrders"
WHERE sale_order_no = 'SO-090151'
AND deleted = false;

-- 2. Check SalesOrderLines for this SO
SELECT 
    sol.id,
    sol.line_number,
    sol.catalog_item_id,
    sol.qty,
    sol.width_m,
    sol.height_m,
    sol.product_type_id
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
ORDER BY sol.line_number;

-- 3. Check BomInstances for this SO
SELECT 
    bi.id as bom_instance_id,
    bi.sale_order_line_id,
    bi.bom_template_id,
    bi.status,
    bi.deleted,
    bt.name as template_name
FROM "BomInstances" bi
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND bi.deleted = false
ORDER BY sol.line_number;

-- 4. Check BomInstanceLines for this SO
SELECT 
    bil.id,
    bil.bom_instance_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.cut_width_mm,
    bil.cut_height_mm,
    bil.calc_notes,
    bil.deleted
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;

-- 5. Count summary
SELECT 
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(bil.id) as bom_lines_count,
    COUNT(bil.id) FILTER (WHERE bil.cut_length_mm IS NOT NULL) as lines_with_cut_length,
    COUNT(bil.id) FILTER (WHERE bil.part_role IN ('tube', 'bottom_rail_profile') AND bil.uom = 'm') as linear_in_meters
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND bi.deleted = false;



