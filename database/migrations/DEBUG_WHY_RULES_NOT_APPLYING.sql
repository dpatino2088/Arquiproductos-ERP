-- ====================================================
-- Debug: Why engineering rules are not applying
-- ====================================================
-- Check each piece needed for rules to work
-- ====================================================

-- 1. Check what material we have
SELECT 
    bil.id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.calc_notes
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bi.deleted = false
AND bil.deleted = false;

-- 2. Check if SalesOrderLine has dimensions (needed for rules)
SELECT 
    sol.id,
    sol.width_m,
    sol.height_m,
    sol.product_type_id
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false;

-- 3. Check BOMTemplate and its rules
SELECT 
    bt.id as template_id,
    bt.name as template_name,
    bt.product_type_id,
    bc.component_role,
    bc.affects_role,
    bc.cut_axis,
    bc.cut_delta_mm,
    bc.cut_delta_scope,
    bc.sequence_order
FROM "BomInstances" bi
JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bi.deleted = false
AND bt.deleted = false
AND (bc.deleted = false OR bc.deleted IS NULL)
AND bc.affects_role IS NOT NULL
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis <> 'none'
ORDER BY bc.sequence_order;

-- 4. Check if the material role matches any affects_role
SELECT 
    bil.part_role as material_role,
    bc.affects_role as rule_affects_role,
    bc.component_role as rule_source_role,
    bc.cut_axis,
    bc.cut_delta_mm,
    CASE 
        WHEN normalize_component_role(bil.part_role) = normalize_component_role(bc.affects_role) THEN '✅ MATCH'
        ELSE '❌ NO MATCH'
    END as role_match
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bi.deleted = false
AND bil.deleted = false
AND bt.deleted = false
AND bc.deleted = false
AND bc.affects_role IS NOT NULL
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis <> 'none';



