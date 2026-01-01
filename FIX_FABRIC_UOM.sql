-- ========================================
-- FIX: Update Fabric UOM to m2
-- ========================================
-- This script updates fabrics in CatalogItems to use 'm2' as UOM
-- ========================================

-- Step 1: Update CatalogItems
-- Only fix fabrics with INVALID UOM (ea or NULL), preserve valid UOMs (m, m2, yd, yd2, ft, ft2, etc.)
UPDATE "CatalogItems"
SET 
  uom = CASE 
    WHEN fabric_pricing_mode = 'per_linear_m' THEN 'm'
    ELSE 'm2' -- Default to m2 for per_sqm or NULL
  END,
  updated_at = now()
WHERE is_fabric = true
  AND deleted = false
  AND (uom IS NULL OR uom = 'ea' OR uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));

-- Step 1b: Optionally set fabric_pricing_mode for fabrics with valid UOM but NULL pricing_mode
-- This helps future BOM generation logic
UPDATE "CatalogItems"
SET 
  fabric_pricing_mode = CASE 
    WHEN uom IN ('m', 'mts', 'yd', 'ft') THEN 'per_linear_m'
    WHEN uom IN ('m2', 'yd2', 'ft2', 'sqm', 'area') THEN 'per_sqm'
    ELSE fabric_pricing_mode -- Keep existing if UOM doesn't match
  END,
  updated_at = now()
WHERE is_fabric = true
  AND deleted = false
  AND fabric_pricing_mode IS NULL
  AND uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area');

-- Step 2: Verify the update
SELECT 
  'Verification: Fabric UOM after update' as check_name,
  ci.uom,
  COUNT(*) as count
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
  AND ci.deleted = false
GROUP BY ci.uom
ORDER BY ci.uom;

-- Step 3: Update existing QuoteLineComponents with fabric role
-- Set UOM based on CatalogItem fabric_pricing_mode if UOM is 'ea' or NULL
UPDATE "QuoteLineComponents" qlc
SET 
  uom = COALESCE(
    CASE 
      WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
      ELSE 'm2' -- Default to m2 for per_sqm or NULL
    END,
    'm2' -- Fallback if CatalogItem not found
  ),
  updated_at = now()
FROM "CatalogItems" ci
WHERE qlc.component_role LIKE '%fabric%'
  AND qlc.deleted = false
  AND (qlc.uom IS NULL OR qlc.uom = 'ea' OR qlc.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'))
  AND ci.id = qlc.catalog_item_id
  AND ci.deleted = false;

-- Step 4: Update existing BomInstanceLines with fabric category
-- Set UOM based on CatalogItem fabric_pricing_mode if UOM is 'ea' or NULL
UPDATE "BomInstanceLines" bil
SET 
  uom = COALESCE(
    CASE 
      WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
      ELSE 'm2' -- Default to m2 for per_sqm or NULL
    END,
    'm2' -- Fallback if CatalogItem not found
  ),
  updated_at = now()
FROM "CatalogItems" ci
WHERE bil.category_code = 'fabric'
  AND bil.deleted = false
  AND (bil.uom IS NULL OR bil.uom = 'ea' OR bil.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'))
  AND ci.id = bil.resolved_part_id
  AND ci.deleted = false;

-- Step 5: Verify QuoteLineComponents update
SELECT 
  'Verification: QuoteLineComponents fabric UOM' as check_name,
  qlc.component_role,
  qlc.uom,
  COUNT(*) as count
FROM "QuoteLineComponents" qlc
WHERE qlc.component_role LIKE '%fabric%'
  AND qlc.deleted = false
GROUP BY qlc.component_role, qlc.uom
ORDER BY qlc.component_role, qlc.uom;

-- Step 6: Verify BomInstanceLines update
SELECT 
  'Verification: BomInstanceLines fabric UOM' as check_name,
  bil.category_code,
  bil.uom,
  COUNT(*) as count
FROM "BomInstanceLines" bil
WHERE bil.category_code = 'fabric'
  AND bil.deleted = false
GROUP BY bil.category_code, bil.uom
ORDER BY bil.category_code, bil.uom;

-- ========================================
-- NOTE: After running this script:
-- 1. New BOMs will use 'm2' for fabrics (from CatalogItems.uom)
-- 2. Existing QuoteLineComponents and BomInstanceLines are updated
-- 3. You may need to regenerate BOMs for existing quotes if needed
-- ========================================

