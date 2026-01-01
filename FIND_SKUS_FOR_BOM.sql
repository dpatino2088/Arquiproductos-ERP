-- ====================================================
-- FIND: SKUs Needed for BOM Components
-- ====================================================
-- This script helps you find the CatalogItem IDs for the SKUs needed
-- ====================================================

-- Find SKUs that match the patterns we're looking for
SELECT 
  'SKUs Needed for BOM' as check_name,
  ci.sku,
  ci.item_name,
  ci.id as catalog_item_id,
  ci.uom,
  ci.is_fabric,
  CASE 
    WHEN ci.sku ILIKE '%RCA-04%' OR ci.sku ILIKE '%RCA04%' THEN '✅ Bottom Rail Profile (RCA-04)'
    WHEN ci.sku ILIKE '%RCA-21%' OR ci.sku ILIKE '%RCA21%' THEN '✅ Bottom Rail End Cap (RCA-21)'
    WHEN ci.sku ILIKE '%RC3101%' THEN '✅ Side Channel Profile (RC3101)'
    WHEN ci.sku ILIKE '%RC3102%' THEN '✅ Side Channel Cover (RC3102)'
    WHEN ci.sku ILIKE '%RCAS-09-75%' OR ci.sku ILIKE '%RCAS0975%' THEN '✅ Insert/Gasket (RCAS-09-75)'
    WHEN ci.sku ILIKE '%RC3104%' THEN '✅ Top Fix Bracket (RC3104)'
    WHEN ci.sku ILIKE '%RTU%42%' OR ci.sku ILIKE '%TUBE%42%' THEN '✅ Tube 42mm'
    WHEN ci.sku ILIKE '%RTU%65%' OR ci.sku ILIKE '%TUBE%65%' THEN '✅ Tube 65mm'
    WHEN ci.sku ILIKE '%RTU%80%' OR ci.sku ILIKE '%TUBE%80%' THEN '✅ Tube 80mm'
    ELSE 'ℹ️ Other'
  END as bom_component_match
FROM "CatalogItems" ci
WHERE ci.organization_id = (
  SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
  AND ci.deleted = false
  AND (
    ci.sku ILIKE '%RCA-04%' OR ci.sku ILIKE '%RCA04%'
    OR ci.sku ILIKE '%RCA-21%' OR ci.sku ILIKE '%RCA21%'
    OR ci.sku ILIKE '%RC3101%'
    OR ci.sku ILIKE '%RC3102%'
    OR ci.sku ILIKE '%RCAS-09-75%' OR ci.sku ILIKE '%RCAS0975%'
    OR ci.sku ILIKE '%RC3104%'
    OR ci.sku ILIKE '%RTU%42%' OR ci.sku ILIKE '%TUBE%42%'
    OR ci.sku ILIKE '%RTU%65%' OR ci.sku ILIKE '%TUBE%65%'
    OR ci.sku ILIKE '%RTU%80%' OR ci.sku ILIKE '%TUBE%80%'
  )
ORDER BY 
  CASE 
    WHEN ci.sku ILIKE '%RCA-04%' OR ci.sku ILIKE '%RCA04%' THEN 1
    WHEN ci.sku ILIKE '%RCA-21%' OR ci.sku ILIKE '%RCA21%' THEN 2
    WHEN ci.sku ILIKE '%RC3101%' THEN 3
    WHEN ci.sku ILIKE '%RC3102%' THEN 4
    WHEN ci.sku ILIKE '%RCAS-09-75%' OR ci.sku ILIKE '%RCAS0975%' THEN 5
    WHEN ci.sku ILIKE '%RC3104%' THEN 6
    ELSE 99
  END,
  ci.sku;








