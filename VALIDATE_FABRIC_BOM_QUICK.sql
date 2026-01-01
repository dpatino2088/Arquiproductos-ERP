-- ====================================================
-- QUICK VALIDATION QUERIES - No placeholders needed
-- ====================================================
-- These queries work immediately without replacing any IDs
-- ====================================================

-- ====================================================
-- Query A: List all QuoteLines with fabric items
-- ====================================================
-- This shows all QuoteLines that have fabric CatalogItems
-- ====================================================

SELECT 
  ql.id as quote_line_id,
  ql.quote_id,
  ql.catalog_item_id,
  ql.width_m,
  ql.height_m,
  ql.qty,
  ci.sku,
  ci.item_name,
  ci.collection_name,
  ci.variant_name,
  ci.is_fabric,
  ci.fabric_pricing_mode,
  ci.roll_width_m,
  -- Check if fabric component exists
  EXISTS (
    SELECT 1
    FROM "QuoteLineComponents" qlc
    WHERE qlc.quote_line_id = ql.id
      AND qlc.component_role = 'fabric'
      AND qlc.deleted = false
  ) as has_fabric_component
FROM "QuoteLines" ql
JOIN "CatalogItems" ci ON ql.catalog_item_id = ci.id
WHERE ql.deleted = false
  AND ci.is_fabric = true
  AND ci.deleted = false
ORDER BY ql.created_at DESC
LIMIT 20;

-- ====================================================
-- Query B: List all fabric QuoteLineComponents
-- ====================================================
-- Shows all existing fabric components
-- ====================================================

SELECT 
  qlc.id as component_id,
  qlc.quote_line_id,
  qlc.catalog_item_id,
  qlc.component_role,
  qlc.qty,
  qlc.uom,
  qlc.unit_cost_exw,
  (qlc.qty * qlc.unit_cost_exw) as total_cost_exw,
  qlc.source,
  ci.sku,
  ci.item_name,
  ci.collection_name,
  ci.variant_name,
  ci.fabric_pricing_mode,
  ci.roll_width_m,
  ql.width_m,
  ql.height_m,
  ql.qty as quote_line_qty
FROM "QuoteLineComponents" qlc
JOIN "QuoteLines" ql ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
WHERE qlc.component_role = 'fabric'
  AND qlc.deleted = false
ORDER BY qlc.created_at DESC
LIMIT 20;

-- ====================================================
-- Query C: Find QuoteLines missing fabric components
-- ====================================================
-- Shows QuoteLines with fabric items but no fabric component
-- ====================================================

SELECT 
  ql.id as quote_line_id,
  ql.quote_id,
  ql.catalog_item_id,
  ql.width_m,
  ql.height_m,
  ql.qty,
  ci.sku,
  ci.item_name,
  ci.collection_name,
  ci.variant_name,
  ci.fabric_pricing_mode,
  ci.roll_width_m
FROM "QuoteLines" ql
JOIN "CatalogItems" ci ON ql.catalog_item_id = ci.id
WHERE ql.deleted = false
  AND ci.is_fabric = true
  AND ci.deleted = false
  AND NOT EXISTS (
    SELECT 1
    FROM "QuoteLineComponents" qlc
    WHERE qlc.quote_line_id = ql.id
      AND qlc.component_role = 'fabric'
      AND qlc.deleted = false
  )
ORDER BY ql.created_at DESC
LIMIT 20;

-- ====================================================
-- Query D: Check for duplicate fabric components
-- ====================================================
-- Each QuoteLine should have ONLY ONE active fabric component
-- If this returns any rows, there's a bug!
-- ====================================================

SELECT 
  qlc.quote_line_id,
  COUNT(*) as fabric_component_count,
  STRING_AGG(qlc.id::text, ', ') as component_ids,
  STRING_AGG(qlc.created_at::text, ', ') as created_dates
FROM "QuoteLineComponents" qlc
WHERE qlc.component_role = 'fabric'
  AND qlc.deleted = false
GROUP BY qlc.quote_line_id
HAVING COUNT(*) > 1;

-- ====================================================
-- Query E: Summary statistics
-- ====================================================
-- Overall statistics for fabric components
-- ====================================================

SELECT 
  COUNT(*) as total_fabric_components,
  COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_fabric,
  COUNT(DISTINCT qlc.organization_id) as organizations_with_fabric,
  SUM(qlc.qty * qlc.unit_cost_exw) as total_fabric_cost_exw,
  AVG(qlc.qty) as avg_fabric_qty,
  AVG(qlc.unit_cost_exw) as avg_unit_cost_exw,
  MIN(qlc.created_at) as first_fabric_component_created,
  MAX(qlc.created_at) as last_fabric_component_created
FROM "QuoteLineComponents" qlc
WHERE qlc.component_role = 'fabric'
  AND qlc.deleted = false;








