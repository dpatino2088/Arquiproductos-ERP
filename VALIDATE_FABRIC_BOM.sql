-- ====================================================
-- Validation Queries for Fabric BOM Handling
-- ====================================================
-- Use these queries to verify that fabric QuoteLineComponents
-- are being created correctly after configuring a QuoteLine
-- ====================================================

-- ====================================================
-- Query 1: Check if fabric QuoteLineComponent exists for a QuoteLine
-- ====================================================
-- INSTRUCTIONS: 
-- 1. First, get a QuoteLine ID by running:
--    SELECT id, catalog_item_id, width_m, height_m, qty FROM "QuoteLines" WHERE deleted = false LIMIT 5;
-- 2. Copy one of the IDs and replace 'YOUR_QUOTE_LINE_ID_HERE' below
-- ====================================================

-- EXAMPLE: Replace 'YOUR_QUOTE_LINE_ID_HERE' with actual UUID like '123e4567-e89b-12d3-a456-426614174000'
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
  qlc.deleted,
  ci.sku,
  ci.item_name,
  ci.collection_name,
  ci.variant_name,
  ci.cost_exw as catalog_cost_exw,
  ci.uom as catalog_uom,
  ci.roll_width_m,
  ci.fabric_pricing_mode,
  ci.can_rotate,
  ci.can_heatseal,
  ql.width_m,
  ql.height_m,
  ql.qty as quote_line_qty,
  ql.metadata->>'fabric_rotation' as fabric_rotation,
  ql.metadata->>'fabric_heatseal' as fabric_heatseal
FROM "QuoteLineComponents" qlc
JOIN "QuoteLines" ql ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
WHERE qlc.quote_line_id = 'YOUR_QUOTE_LINE_ID_HERE'::uuid  -- ⚠️ REPLACE THIS WITH ACTUAL UUID
  AND qlc.component_role = 'fabric'
  AND qlc.deleted = false;

-- ====================================================
-- Query 2: Verify fabric consumption calculation
-- ====================================================
-- This query shows the expected vs actual qty/uom/cost
-- INSTRUCTIONS: Replace 'YOUR_QUOTE_LINE_ID_HERE' with actual UUID
-- ====================================================

SELECT 
  qlc.component_role,
  qlc.uom as actual_uom,
  qlc.qty as actual_qty,
  qlc.unit_cost_exw as actual_unit_cost_exw,
  (qlc.qty * qlc.unit_cost_exw) as actual_total_cost_exw,
  ci.fabric_pricing_mode,
  ci.roll_width_m,
  ql.width_m,
  ql.height_m,
  ql.qty as quote_line_qty,
  ql.metadata->>'fabric_rotation' as fabric_rotation,
  -- Expected calculation
  CASE 
    WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 
      (ql.width_m * ql.height_m * ql.qty)::numeric(12,4)
    WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 
      CASE 
        WHEN ci.can_rotate AND (ql.metadata->>'fabric_rotation')::boolean = true AND ql.height_m > ql.width_m THEN 
          -- Rotated: use height as width
          (CEIL(GREATEST(ql.height_m, 0.001) / GREATEST(ci.roll_width_m, 0.001)) * ql.width_m * ql.qty)::numeric(12,4)
        ELSE 
          -- Not rotated: use width as width
          (CEIL(GREATEST(ql.width_m, 0.001) / GREATEST(ci.roll_width_m, 0.001)) * ql.height_m * ql.qty)::numeric(12,4)
      END
    ELSE 
      (ql.width_m * ql.height_m * ql.qty)::numeric(12,4)  -- Default to area
  END as expected_qty,
  CASE 
    WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
    WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
    ELSE 'm2'  -- Default
  END as expected_uom,
  -- Validation
  CASE 
    WHEN qlc.qty = CASE 
      WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 
        (ql.width_m * ql.height_m * ql.qty)::numeric(12,4)
      WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 
        CASE 
          WHEN ci.can_rotate AND (ql.metadata->>'fabric_rotation')::boolean = true AND ql.height_m > ql.width_m THEN 
            (CEIL(GREATEST(ql.height_m, 0.001) / GREATEST(ci.roll_width_m, 0.001)) * ql.width_m * ql.qty)::numeric(12,4)
          ELSE 
            (CEIL(GREATEST(ql.width_m, 0.001) / GREATEST(ci.roll_width_m, 0.001)) * ql.height_m * ql.qty)::numeric(12,4)
        END
      ELSE 
        (ql.width_m * ql.height_m * ql.qty)::numeric(12,4)
    END THEN '✅ CORRECT'
    ELSE '❌ MISMATCH'
  END as qty_validation,
  CASE 
    WHEN qlc.uom = CASE 
      WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
      WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
      ELSE 'm2'
    END THEN '✅ CORRECT'
    ELSE '❌ MISMATCH'
  END as uom_validation
FROM "QuoteLineComponents" qlc
JOIN "QuoteLines" ql ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
WHERE qlc.quote_line_id = 'YOUR_QUOTE_LINE_ID_HERE'::uuid  -- ⚠️ REPLACE THIS WITH ACTUAL UUID
  AND qlc.component_role = 'fabric'
  AND qlc.deleted = false;

-- ====================================================
-- Query 3: List all QuoteLines with fabric but missing fabric component
-- ====================================================
-- This helps identify QuoteLines that need fabric components
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
ORDER BY ql.created_at DESC;

-- ====================================================
-- Query 4: Count fabric components by organization
-- ====================================================
-- INSTRUCTIONS: 
-- 1. Get your organization ID by running:
--    SELECT id, name FROM "Organizations" WHERE deleted = false LIMIT 5;
-- 2. Replace 'YOUR_ORGANIZATION_ID_HERE' below
-- ====================================================

SELECT 
  COUNT(*) as total_fabric_components,
  COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_fabric,
  SUM(qlc.qty * qlc.unit_cost_exw) as total_fabric_cost_exw,
  AVG(qlc.qty) as avg_fabric_qty,
  AVG(qlc.unit_cost_exw) as avg_unit_cost_exw
FROM "QuoteLineComponents" qlc
WHERE qlc.organization_id = 'YOUR_ORGANIZATION_ID_HERE'::uuid  -- ⚠️ REPLACE THIS WITH ACTUAL UUID
  AND qlc.component_role = 'fabric'
  AND qlc.deleted = false;

-- ====================================================
-- Query 5: Check for duplicate fabric components (should be 0)
-- ====================================================
-- Each QuoteLine should have ONLY ONE active fabric component
-- ====================================================

SELECT 
  qlc.quote_line_id,
  COUNT(*) as fabric_component_count,
  STRING_AGG(qlc.id::text, ', ') as component_ids
FROM "QuoteLineComponents" qlc
WHERE qlc.component_role = 'fabric'
  AND qlc.deleted = false
GROUP BY qlc.quote_line_id
HAVING COUNT(*) > 1;

-- If this query returns any rows, there are duplicate fabric components (BUG!)

