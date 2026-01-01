-- ========================================
-- CHECK: Final BOM Status - Complete Verification
-- ========================================
-- This script checks QuoteLineComponents, BomInstanceLines, and UOM issues
-- INSTRUCTIONS: Replace 'SO-000004' with your Sale Order number
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
  ci.fabric_pricing_mode
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE qlc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

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
  ci.fabric_pricing_mode
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE bil.category_code
    WHEN 'fabric' THEN 1
    WHEN 'motor' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_rail' THEN 5
    ELSE 99
  END;

-- Step 3: Check UOM issues in QuoteLineComponents (fabrics with wrong UOM)
SELECT 
  'Step 3: UOM Issues in QuoteLineComponents' as check_name,
  qlc.component_role,
  qlc.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  ci.fabric_pricing_mode,
  CASE 
    WHEN ci.is_fabric = true AND qlc.uom = 'ea' THEN '❌ WRONG: Fabric with UOM=ea'
    WHEN ci.is_fabric = true AND qlc.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '✅ OK: Valid fabric UOM'
    WHEN ci.is_fabric = true AND qlc.uom IS NULL THEN '❌ MISSING: Fabric with NULL UOM'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
  AND ci.is_fabric = true
ORDER BY qlc.component_role;

-- Step 4: Check UOM issues in BomInstanceLines (fabrics with wrong UOM)
SELECT 
  'Step 4: UOM Issues in BomInstanceLines' as check_name,
  bil.category_code,
  bil.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  ci.fabric_pricing_mode,
  CASE 
    WHEN ci.is_fabric = true AND bil.uom = 'ea' THEN '❌ WRONG: Fabric with UOM=ea'
    WHEN ci.is_fabric = true AND bil.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '✅ OK: Valid fabric UOM'
    WHEN ci.is_fabric = true AND bil.uom IS NULL THEN '❌ MISSING: Fabric with NULL UOM'
    ELSE 'ℹ️ N/A'
  END as uom_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
  AND ci.is_fabric = true
ORDER BY bil.category_code;

-- Step 5: Count components by type
SELECT 
  'Step 5: Component Count Summary' as check_name,
  'QuoteLineComponents' as source,
  qlc.component_role,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
GROUP BY qlc.component_role
UNION ALL
SELECT 
  'Step 5: Component Count Summary' as check_name,
  'BomInstanceLines' as source,
  bil.category_code as component_role,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bil.category_code
ORDER BY source, component_role;








