-- ========================================
-- FIX: UOM Issues and Regenerate BOM
-- ========================================
-- This script fixes UOM issues and helps regenerate BOM
-- INSTRUCTIONS: Replace 'SO-000004' with your Sale Order number
-- ========================================

-- Step 1: Fix UOM in QuoteLineComponents (fabrics)
UPDATE "QuoteLineComponents" qlc
SET 
  uom = CASE 
    WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
    WHEN ci.fabric_pricing_mode = 'per_sqm' OR ci.fabric_pricing_mode IS NULL THEN 'm2'
    ELSE 'm2'
  END,
  updated_at = NOW()
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
  AND qlc.quote_line_id = ql.id
  AND qlc.deleted = false
  AND ci.is_fabric = true
  AND (qlc.uom IS NULL OR qlc.uom = 'ea' OR qlc.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));

-- Step 2: Fix UOM in BomInstanceLines (fabrics)
UPDATE "BomInstanceLines" bil
SET 
  uom = CASE 
    WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
    WHEN ci.fabric_pricing_mode = 'per_sqm' OR ci.fabric_pricing_mode IS NULL THEN 'm2'
    ELSE 'm2'
  END,
  updated_at = NOW()
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
  AND bil.bom_instance_id = bi.id
  AND bil.deleted = false
  AND ci.is_fabric = true
  AND (bil.uom IS NULL OR bil.uom = 'ea' OR bil.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));

-- Step 3: Show QuoteLine IDs that need BOM regeneration
SELECT 
  'Step 3: QuoteLines Needing BOM Regeneration' as check_name,
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
  ql.qty,
  COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') as configured_component_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component'
    AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000004' -- CHANGE THIS
  AND so.deleted = false
GROUP BY ql.id, ql.product_type_id, pt.code, ql.drive_type, ql.bottom_rail_type, 
         ql.cassette, ql.cassette_type, ql.side_channel, ql.side_channel_type, 
         ql.hardware_color, ql.width_m, ql.height_m, ql.qty;

-- ========================================
-- INSTRUCTIONS FOR MANUAL BOM REGENERATION
-- ========================================
-- 
-- After fixing UOM, you need to regenerate the BOM:
--
-- Option 1: Re-configure in UI (Recommended)
--   1. Go to QuoteNew
--   2. Edit the QuoteLine
--   3. Re-configure the product (go through all steps)
--   4. Save - This will call generate_configured_bom_for_quote_line
--
-- Option 2: Call function manually (if needed)
--   Use the quote_line_id from Step 3 and call:
--   SELECT generate_configured_bom_for_quote_line(
--     p_quote_line_id := 'QUOTE_LINE_ID_HERE'::uuid,
--     p_product_type_id := 'PRODUCT_TYPE_ID_HERE'::uuid,
--     p_organization_id := 'ORGANIZATION_ID_HERE'::uuid,
--     p_drive_type := 'motor', -- or 'manual'
--     p_bottom_rail_type := 'standard', -- or 'wrapped'
--     p_cassette := false,
--     p_cassette_type := NULL,
--     p_side_channel := false,
--     p_side_channel_type := NULL,
--     p_hardware_color := 'white',
--     p_width_m := 2.0, -- from Step 3
--     p_height_m := 1.5, -- from Step 3
--     p_qty := 1 -- from Step 3
--   );
--
-- ========================================








