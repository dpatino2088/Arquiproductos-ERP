-- ====================================================
-- VERIFY: BomInstanceLines columns for Material Planning
-- ====================================================
-- This script verifies that all required columns exist
-- and are being populated correctly for Material Planning UI
-- ====================================================

-- Check if dimensional columns exist
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN (
    'cut_length_mm',
    'cut_width_mm',
    'cut_height_mm',
    'calc_notes',
    'part_role',
    'resolved_sku',
    'resolved_part_id',
    'qty',
    'uom',
    'description',
    'category_code'
)
ORDER BY column_name;

-- Sample query to verify data structure
-- (Replace with actual MO ID to test)
/*
SELECT 
    bil.id,
    bil.bom_instance_id,
    bil.resolved_part_id,
    bil.resolved_sku,
    bil.part_role,
    bil.description,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.cut_width_mm,
    bil.cut_height_mm,
    bil.calc_notes,
    bil.category_code,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bi.sale_order_line_id,
    sol.sale_order_id
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = sol.sale_order_id
WHERE mo.id = 'YOUR_MO_ID_HERE'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;
*/






