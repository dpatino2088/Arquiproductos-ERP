-- ====================================================
-- Diagnostic: Complete analysis for SO-053830 (AUTO VERSION)
-- ====================================================
-- This version automatically gets bom_instance_id - no manual replacement needed!
-- ====================================================

-- FASE 0: Get bom_instance_id from SO-053830
-- ====================================================
-- This shows all available bom_instances for SO-053830
SELECT
  so.sale_order_no,
  sol.id AS sale_order_line_id,
  bi.id AS bom_instance_id,
  bi.status,
  bi.bom_template_id,
  bt.name AS template_name
FROM "SalesOrders" so
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE so.sale_order_no = 'SO-053830'
ORDER BY sol.line_number NULLS LAST
LIMIT 5;

-- ====================================================
-- FASE 1: Check current state of BomInstanceLines (AUTO)
-- ====================================================
-- Gets the FIRST bom_instance_id for SO-053830 automatically
SELECT
  bil.part_role,
  bil.resolved_sku,
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = (
  SELECT bi.id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
  JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol.line_number NULLS LAST
  LIMIT 1
)
AND bil.deleted=false
ORDER BY bil.part_role, bil.resolved_sku;

-- ====================================================
-- FASE 2: Verify dimensions exist (AUTO)
-- ====================================================
SELECT
  sol.id,
  sol.width_m,
  sol.height_m,
  sol.qty,
  sol.product_type,
  sol.drive_type
FROM "SalesOrderLines" sol
WHERE id = (
  SELECT bi.sale_order_line_id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol2 ON sol2.sale_order_id = so.id AND sol2.deleted=false
  JOIN "BomInstances" bi ON bi.sale_order_line_id = sol2.id AND bi.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol2.line_number NULLS LAST
  LIMIT 1
)
AND deleted=false;

-- ✅ Expected: width_m and height_m should NOT be null

-- ====================================================
-- FASE 3: Verify template and rules (AUTO)
-- ====================================================
-- 3A) Template link
SELECT
  bi.id,
  bt.name AS template_name,
  bt.active,
  bt.deleted
FROM "BomInstances" bi
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE bi.id = (
  SELECT bi2.id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
  JOIN "BomInstances" bi2 ON bi2.sale_order_line_id = sol.id AND bi2.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol.line_number NULLS LAST
  LIMIT 1
);

-- 3B) Rules that should affect tube/bottom_rail_profile
SELECT
  bc.component_role,
  bc.affects_role,
  bc.cut_axis,
  bc.cut_delta_mm,
  bc.cut_delta_scope,
  bc.sequence_order
FROM "BOMComponents" bc
WHERE bc.bom_template_id = (
  SELECT bi.bom_template_id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
  JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol.line_number NULLS LAST
  LIMIT 1
)
AND bc.deleted=false
AND bc.affects_role IS NOT NULL
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis <> 'none'
ORDER BY bc.sequence_order;

-- ✅ Expected: Should have rules like:
--    bracket -> affects tube, cut_axis=length
--    idle_end/pin -> affects tube, cut_axis=length
--    bottom_rail_profile -> affects bottom_rail_profile, cut_axis=length

-- ====================================================
-- FASE 4: After Generate BOM - Verify results (AUTO)
-- ====================================================
-- Run AFTER Generate BOM (same query as FASE 1)
SELECT
  bil.part_role,
  bil.resolved_sku,
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = (
  SELECT bi.id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
  JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol.line_number NULLS LAST
  LIMIT 1
)
AND bil.deleted=false
ORDER BY bil.part_role, bil.resolved_sku;

-- Acceptance checks for tube (AUTO):
SELECT 
  part_role,
  resolved_sku,
  qty,
  uom,
  cut_length_mm,
  calc_notes,
  CASE 
    WHEN cut_length_mm IS NOT NULL THEN '✅ cut_length_mm OK'
    ELSE '❌ cut_length_mm NULL'
  END as cut_length_status,
  CASE 
    WHEN uom = 'm' THEN '✅ uom OK'
    ELSE '❌ uom = ' || uom
  END as uom_status,
  CASE 
    WHEN cut_length_mm IS NOT NULL AND ABS(qty - (cut_length_mm::numeric / 1000)) < 0.01 THEN '✅ qty OK'
    ELSE '❌ qty mismatch'
  END as qty_status
FROM "BomInstanceLines"
WHERE bom_instance_id = (
  SELECT bi.id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
  JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol.line_number NULLS LAST
  LIMIT 1
)
AND deleted = false
AND part_role = 'tube';

-- ✅ Expected after fix:
--    cut_length_mm IS NOT NULL
--    uom = 'm'
--    qty ≈ cut_length_mm/1000
--    calc_notes explains base + deltas

-- Acceptance checks for bottom_rail_profile (AUTO):
SELECT 
  part_role,
  resolved_sku,
  qty,
  uom,
  cut_length_mm,
  calc_notes,
  CASE 
    WHEN cut_length_mm IS NOT NULL THEN '✅ cut_length_mm OK'
    ELSE '❌ cut_length_mm NULL'
  END as cut_length_status,
  CASE 
    WHEN uom = 'm' THEN '✅ uom OK'
    ELSE '❌ uom = ' || uom
  END as uom_status,
  CASE 
    WHEN cut_length_mm IS NOT NULL AND ABS(qty - (cut_length_mm::numeric / 1000)) < 0.01 THEN '✅ qty OK'
    ELSE '❌ qty mismatch'
  END as qty_status
FROM "BomInstanceLines"
WHERE bom_instance_id = (
  SELECT bi.id
  FROM "SalesOrders" so
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
  JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
  WHERE so.sale_order_no = 'SO-053830'
  ORDER BY sol.line_number NULLS LAST
  LIMIT 1
)
AND deleted = false
AND part_role = 'bottom_rail_profile';

-- ✅ Expected after fix:
--    cut_length_mm IS NOT NULL
--    uom = 'm'
--    qty ≈ cut_length_mm/1000
--    calc_notes explains base + deltas



