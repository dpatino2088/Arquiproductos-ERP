-- ========================================
-- DIAGNÓSTICO COMPLETO: BOM Solo Telas + UOM + Accessories
-- ========================================
-- Este script diagnostica todos los problemas del BOM
-- INSTRUCTIONS: Replace 'SO-000007' with your Sale Order number
-- ========================================

-- Step 1: Check QuoteLineComponents (what was generated)
SELECT 
  'Step 1: QuoteLineComponents Generated' as check_name,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  CASE 
    WHEN ci.is_fabric = true AND qlc.uom = 'ea' THEN '❌ WRONG UOM (should be m2 or m)'
    WHEN ci.is_fabric = true AND qlc.uom IN ('m', 'm2') THEN '✅ OK'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE qlc.source
    WHEN 'configured_component' THEN 1
    WHEN 'accessory' THEN 2
    ELSE 99
  END,
  qlc.component_role;

-- Step 2: Check BomInstanceLines (what appears in Manufacturing Order)
SELECT 
  'Step 2: BomInstanceLines (Manufacturing Order)' as check_name,
  bil.category_code,
  bil.part_role,
  bil.qty,
  bil.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  CASE 
    WHEN ci.is_fabric = true AND bil.uom = 'ea' THEN '❌ WRONG UOM (should be m2 or m)'
    WHEN ci.is_fabric = true AND bil.uom IN ('m', 'm2') THEN '✅ OK'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false
ORDER BY bil.category_code;

-- Step 3: Check QuoteLine configuration
SELECT 
  'Step 3: QuoteLine Configuration' as check_name,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.code as product_type_code,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.cassette_type,
  ql.side_channel,
  ql.side_channel_type,
  ql.hardware_color,
  ql.width_m,
  ql.height_m,
  ql.qty
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false;

-- Step 4: Check BOMTemplate components
SELECT 
  'Step 4: BOMTemplate Components' as check_name,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule,
  CASE 
    WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN '❌ Cannot resolve'
    WHEN bc.block_condition IS NOT NULL THEN '⚠️ Has block_condition'
    WHEN bc.component_item_id IS NOT NULL THEN '✅ Has item_id'
    WHEN bc.auto_select = true THEN '✅ Has auto_select'
    ELSE '⚠️ Unknown'
  END as resolution_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false
ORDER BY bc.component_role;

-- Step 5: Summary counts
SELECT 
  'Step 5: Summary' as check_name,
  'QuoteLineComponents' as source,
  COUNT(*) FILTER (WHERE qlc.source = 'configured_component') as configured_count,
  COUNT(*) FILTER (WHERE qlc.source = 'accessory') as accessory_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = true) as fabric_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = false) as non_fabric_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = true AND qlc.uom = 'ea') as fabric_wrong_uom_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false
UNION ALL
SELECT 
  'Step 5: Summary' as check_name,
  'BomInstanceLines' as source,
  COUNT(*) as configured_count,
  0 as accessory_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = true) as fabric_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = false) as non_fabric_count,
  COUNT(*) FILTER (WHERE ci.is_fabric = true AND bil.uom = 'ea') as fabric_wrong_uom_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000007' -- CHANGE THIS
  AND so.deleted = false;








