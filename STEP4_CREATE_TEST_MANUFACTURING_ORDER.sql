-- STEP 4: Create a test Manufacturing Order from an existing Sale Order
-- Run these queries in order

-- 1) First, find a Sale Order that has BOM data (BomInstances)
SELECT 
  so.id as sale_order_id,
  so.sale_order_no,
  so.status as sale_order_status,
  COUNT(DISTINCT bi.id) as bom_instances_count,
  COUNT(DISTINCT bil.id) as bom_lines_count
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no, so.status
HAVING COUNT(DISTINCT bi.id) > 0
ORDER BY so.created_at DESC
LIMIT 5;

-- 2) If you found a sale_order_id above, use it to create a Manufacturing Order
-- Replace 'YOUR_SALE_ORDER_ID_HERE' with an actual UUID from query 1
-- Also replace 'YOUR_ORGANIZATION_ID_HERE' with your actual organization_id

/*
INSERT INTO "ManufacturingOrders" (
  organization_id,
  sale_order_id,
  manufacturing_order_no,
  status,
  priority,
  scheduled_start_date,
  scheduled_end_date,
  notes,
  deleted,
  archived
) VALUES (
  'YOUR_ORGANIZATION_ID_HERE',  -- Replace with actual organization_id
  'YOUR_SALE_ORDER_ID_HERE',     -- Replace with sale_order_id from query 1
  'MO-000001',                    -- Will be auto-generated if using get_next_counter_value
  'draft',
  'normal',
  CURRENT_DATE + INTERVAL '7 days',  -- Scheduled start: 7 days from now
  CURRENT_DATE + INTERVAL '14 days', -- Scheduled end: 14 days from now
  'Test Manufacturing Order created for validation',
  false,
  false
) RETURNING id, manufacturing_order_no, sale_order_id;
*/

-- 3) After creating the MO, verify it was created
/*
SELECT 
  mo.id,
  mo.manufacturing_order_no,
  mo.status,
  mo.sale_order_id,
  so.sale_order_no,
  so.status as sale_order_status
FROM "ManufacturingOrders" mo
LEFT JOIN "SaleOrders" so ON so.id = mo.sale_order_id
WHERE mo.deleted = false
ORDER BY mo.created_at DESC
LIMIT 5;
*/

-- 4) Test SaleOrderMaterialList for the sale_order_id used
-- Replace with the sale_order_id you used to create the MO
/*
SELECT 
  sale_order_id,
  category_code,
  sku,
  item_name,
  uom,
  total_qty,
  total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = 'YOUR_SALE_ORDER_ID_HERE'
ORDER BY category_code, sku;
*/








