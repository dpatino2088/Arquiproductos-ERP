-- ========================================
-- CHECK: Fabrics with Invalid UOM Only
-- ========================================
-- This script shows only fabrics with invalid UOM (ea, NULL, or invalid values)

SELECT 
  'Fabrics with INVALID UOM' as issue_type,
  ci.uom,
  ci.fabric_pricing_mode,
  COUNT(*) as count,
  STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) as sample_skus
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
  AND ci.deleted = false
  AND (ci.uom IS NULL OR ci.uom = 'ea' OR ci.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'))
GROUP BY ci.uom, ci.fabric_pricing_mode
ORDER BY count DESC;








