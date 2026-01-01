-- ========================================
-- CHECK: Fabric UOM in CatalogItems
-- ========================================
-- This script checks what UOM fabrics have in CatalogItems

SELECT 
  'Fabric UOM Check' as check_name,
  ci.uom,
  ci.fabric_pricing_mode,
  COUNT(*) as count,
  STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) as sample_skus
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
  AND ci.deleted = false
GROUP BY ci.uom, ci.fabric_pricing_mode
ORDER BY ci.uom, ci.fabric_pricing_mode;

-- Expected: 
-- - Fabrics should have uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area')
-- - NEVER 'ea' or NULL
-- - If fabric_pricing_mode = 'per_linear_m' → uom should be 'm' or 'mts'
-- - If fabric_pricing_mode = 'per_sqm' → uom should be 'm2' or 'sqm'
-- - If fabric_pricing_mode is NULL → default to 'm2'

