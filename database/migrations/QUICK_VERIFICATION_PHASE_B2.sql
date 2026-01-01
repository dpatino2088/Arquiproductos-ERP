-- ====================================================
-- QUICK VERIFICATION: Phase B2 - Check which roles have NULL cut_length_mm
-- ====================================================
-- Run this FIRST to see which roles need fixing
-- ====================================================

-- Step 1: Find BOM instance for MO-000001
SELECT 
  mo.id AS manufacturing_order_id,
  mo.manufacturing_order_no,
  mo.sale_order_id,
  mo.sale_order_line_id,
  bi.id AS bom_instance_id,
  bi.status AS bom_status,
  so.sale_order_no
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "BomInstances" bi 
  ON bi.sale_order_line_id = mo.sale_order_line_id
 AND bi.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000001'
LIMIT 1;

-- Step 2: Check actual column names in BomInstanceLines
SELECT column_name
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name='BomInstanceLines'
ORDER BY ordinal_position;

-- Step 3: Replace <BOM_INSTANCE_ID> with the ID from Step 1
-- Then run this query to see which roles have NULL cut_length_mm:
SELECT
  bil.id,
  bil.resolved_sku,  -- Adjust if column is named 'sku'
  bil.part_role,     -- Adjust if column is named 'component_role'
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes,
  CASE 
    WHEN bil.cut_length_mm IS NULL THEN '❌ NULL'
    ELSE '✅ OK'
  END as status
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'  -- REPLACE THIS
  AND bil.deleted = false
ORDER BY 
  CASE WHEN bil.cut_length_mm IS NULL THEN 0 ELSE 1 END,
  bil.part_role,  -- Adjust column name as needed
  bil.resolved_sku;  -- Adjust column name as needed

-- Step 4: Summary of NULL cut_length_mm by role
SELECT
  bil.part_role,  -- Adjust if column is named 'component_role'
  COUNT(*) as total_lines,
  COUNT(*) FILTER (WHERE bil.cut_length_mm IS NULL) as null_count,
  COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) as ok_count
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'  -- REPLACE THIS
  AND bil.deleted = false
GROUP BY bil.part_role
ORDER BY null_count DESC, bil.part_role;




