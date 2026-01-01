-- ========================================
-- CHECK: Complete BOM Flow Status
-- ========================================
-- This script checks the entire BOM generation flow
-- INSTRUCTIONS: Replace 'SO-000006' with your Sale Order number
-- ========================================

-- Step 1: Check Sale Order and QuoteLine status
SELECT 
  'Step 1: Sale Order and QuoteLine' as check_name,
  so.sale_order_no,
  so.status as sale_order_status,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.code as product_type_code,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.side_channel,
  ql.hardware_color
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 2: Check QuoteLineComponents (configured components)
SELECT 
  'Step 2: QuoteLineComponents (Configured)' as check_name,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  CASE 
    WHEN ci.is_fabric = true AND qlc.uom = 'ea' THEN '❌ WRONG UOM'
    WHEN ci.is_fabric = true AND qlc.uom IN ('m', 'm2') THEN '✅ OK'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false
ORDER BY qlc.component_role;

-- Step 3: Check BomInstances (BOM instances created)
SELECT 
  'Step 3: BomInstances' as check_name,
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  bi.status,
  bi.created_at
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 4: Check BomInstanceLines (frozen BOM materials)
SELECT 
  'Step 4: BomInstanceLines (Frozen Materials)' as check_name,
  bil.category_code,
  bil.part_role,
  bil.qty,
  bil.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  CASE 
    WHEN ci.is_fabric = true AND bil.uom = 'ea' THEN '❌ WRONG UOM'
    WHEN ci.is_fabric = true AND bil.uom IN ('m', 'm2') THEN '✅ OK'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false
ORDER BY bil.category_code;

-- Step 5: Summary - Component counts
SELECT 
  'Step 5: Component Count Summary' as check_name,
  'QuoteLineComponents' as source,
  COUNT(*) FILTER (WHERE qlc.source = 'configured_component') as configured_count,
  COUNT(*) FILTER (WHERE qlc.source = 'accessory') as accessory_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = true) as fabric_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = false) as non_fabric_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false
UNION ALL
SELECT 
  'Step 5: Component Count Summary' as check_name,
  'BomInstanceLines' as source,
  COUNT(*) as configured_count,
  0 as accessory_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = true) as fabric_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = false) as non_fabric_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- ========================================
-- INTERPRETATION
-- ========================================
-- 
-- Step 1: Shows Sale Order and QuoteLine configuration
-- Step 2: Shows what was generated in QuoteLineComponents
--   - If empty or only fabric → BOM generation didn't work
-- Step 3: Shows if BomInstances were created
--   - If empty → BomInstances were not created (trigger didn't run?)
-- Step 4: Shows frozen BOM materials (what appears in Manufacturing Order)
--   - If empty → No materials were frozen
-- Step 5: Shows summary counts
--   - Compare configured_count between QuoteLineComponents and BomInstanceLines
--
-- ========================================

