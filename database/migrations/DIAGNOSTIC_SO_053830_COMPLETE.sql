-- ====================================================
-- Diagnostic: Complete analysis for SO-053830
-- ====================================================
-- Run these queries in order to diagnose the BOM generation issue
-- ====================================================

-- FASE 0: Get bom_instance_id from SO-053830
-- ====================================================
SELECT
  so.sale_order_no,
  sol.id AS sale_order_line_id,
  bi.id AS bom_instance_id,
  bi.status,
  bi.bom_template_id
FROM "SalesOrders" so
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
WHERE so.sale_order_no = 'SO-053830'
ORDER BY sol.line_number NULLS LAST
LIMIT 5;

-- ⚠️ IMPORTANT: Save one bom_instance_id from above to use in queries below
-- Replace '<BOM_INSTANCE_ID>' with the actual ID

-- FASE 1: Check current state of BomInstanceLines
-- ====================================================
-- Run BEFORE Generate BOM
-- ⚠️ FIRST: Run GET_BOM_INSTANCE_ID_FOR_SO_053830.sql to get the actual ID
-- ⚠️ THEN: Replace the UUID below with the actual bom_instance_id from the results above

-- Example: WHERE bil.bom_instance_id = 'cc8fb87f-c851-4536-bc12-5041479cbf91'
-- (Replace with your actual ID)

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
WHERE bil.bom_instance_id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid  -- ⚠️ REPLACE 'YOUR-BOM-INSTANCE-ID-HERE' with actual UUID
  AND bil.deleted=false
ORDER BY bil.part_role, bil.resolved_sku;

-- FASE 2: Verify dimensions exist
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
  SELECT sale_order_line_id
  FROM "BomInstances"
  WHERE id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid  -- ⚠️ REPLACE with actual UUID
)
AND deleted=false;

-- ✅ Expected: width_m and height_m should NOT be null

-- FASE 3: Verify template and rules
-- ====================================================
-- 3A) Template link
SELECT
  bi.id,
  bt.name AS template_name,
  bt.active,
  bt.deleted
FROM "BomInstances" bi
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE bi.id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid;  -- ⚠️ REPLACE with actual UUID

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
  SELECT bom_template_id FROM "BomInstances" WHERE id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid  -- ⚠️ REPLACE with actual UUID
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

-- FASE 4: After Generate BOM - Verify results
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
WHERE bil.bom_instance_id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid  -- ⚠️ REPLACE with actual UUID
  AND bil.deleted=false
ORDER BY bil.part_role, bil.resolved_sku;

-- Acceptance checks for tube:
SELECT 
  part_role,
  resolved_sku,
  qty,
  uom,
  cut_length_mm,
  calc_notes
FROM "BomInstanceLines"
WHERE bom_instance_id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid  -- ⚠️ REPLACE with actual UUID
  AND deleted = false
  AND part_role = 'tube';

-- ✅ Expected after fix:
--    cut_length_mm IS NOT NULL
--    uom = 'm'
--    qty ≈ cut_length_mm/1000
--    calc_notes explains base + deltas

-- Acceptance checks for bottom_rail_profile:
SELECT 
  part_role,
  resolved_sku,
  qty,
  uom,
  cut_length_mm,
  calc_notes
FROM "BomInstanceLines"
WHERE bom_instance_id = 'YOUR-BOM-INSTANCE-ID-HERE'::uuid  -- ⚠️ REPLACE with actual UUID
  AND deleted = false
  AND part_role = 'bottom_rail_profile';

-- ✅ Expected after fix:
--    cut_length_mm IS NOT NULL
--    uom = 'm'
--    qty ≈ cut_length_mm/1000
--    calc_notes explains base + deltas

-- FASE 5: Check logs in Supabase
-- ====================================================
-- After running Generate BOM, check the Supabase logs for RAISE NOTICE messages
-- Look for:
--   - "Applying engineering rules to BomInstance..."
--   - "Dimensions: width=...m, height=...m"
--   - "Found X engineering rule(s) in template"
--   - "Updated ... (part_role=tube): cut_length_mm=..."
--   - "Applied engineering rules: X rule(s) applied, Y line(s) updated"

