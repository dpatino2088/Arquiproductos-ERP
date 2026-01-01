-- ========================================
-- CHECK: Fabric UOM Issues
-- ========================================
-- This script identifies fabrics with invalid UOM (ea, NULL) or missing fabric_pricing_mode

-- Check 1: Fabrics with invalid UOM (ea or NULL)
SELECT 
  'Fabrics with INVALID UOM (ea or NULL)' as issue_type,
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

-- Check 2: Fabrics with valid UOM but NULL fabric_pricing_mode
SELECT 
  'Fabrics with VALID UOM but NULL fabric_pricing_mode' as issue_type,
  ci.uom,
  COUNT(*) as count,
  CASE 
    WHEN ci.uom IN ('m', 'mts', 'yd', 'ft') THEN 'Should have fabric_pricing_mode = per_linear_m'
    WHEN ci.uom IN ('m2', 'yd2', 'ft2', 'sqm', 'area') THEN 'Should have fabric_pricing_mode = per_sqm'
    ELSE 'Unknown'
  END as recommendation
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
  AND ci.deleted = false
  AND ci.fabric_pricing_mode IS NULL
  AND ci.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area')
GROUP BY ci.uom
ORDER BY count DESC;

-- Check 3: Summary
SELECT 
  'Summary' as issue_type,
  COUNT(*) FILTER (WHERE ci.uom IS NULL OR ci.uom = 'ea' OR ci.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area')) as invalid_uom_count,
  COUNT(*) FILTER (WHERE ci.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') AND ci.fabric_pricing_mode IS NULL) as valid_uom_null_pricing_mode,
  COUNT(*) FILTER (WHERE ci.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') AND ci.fabric_pricing_mode IS NOT NULL) as valid_uom_valid_pricing_mode,
  COUNT(*) as total_fabrics
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
  AND ci.deleted = false;

