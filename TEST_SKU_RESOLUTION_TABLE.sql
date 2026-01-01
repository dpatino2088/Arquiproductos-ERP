-- ====================================================
-- TEST: SKU Resolution Logic (Table Output)
-- ====================================================
-- This script tests if the SKU resolution logic would find the SKUs
-- and shows results in a table
-- ====================================================

WITH org AS (
  SELECT id
  FROM "Organizations"
  WHERE deleted = false
  ORDER BY created_at ASC
  LIMIT 1
),
sku_tests AS (
  SELECT 
    'RCA-04' as sku_pattern,
    'Bottom Rail Profile' as component_name,
    ci.id as catalog_item_id,
    ci.sku as found_sku,
    ci.item_name,
    CASE 
      WHEN ci.id IS NOT NULL THEN '✅ FOUND'
      ELSE '❌ NOT FOUND'
    END as status,
    CASE 
      WHEN ci.sku = 'RCA-04' THEN 1
      WHEN ci.sku ILIKE 'RCA-04-W%' OR ci.sku ILIKE '%W%' THEN 2
      WHEN ci.sku ILIKE 'RCA-04-A%' OR ci.sku ILIKE '%A%' THEN 3
      ELSE 4
    END as priority
  FROM org
  LEFT JOIN LATERAL (
    SELECT id, sku, item_name
    FROM "CatalogItems" 
    WHERE (sku = 'RCA-04' OR sku ILIKE 'RCA-04-%' OR sku ILIKE 'RCA04%')
      AND organization_id = org.id 
      AND deleted = false
    ORDER BY 
      CASE 
        WHEN sku = 'RCA-04' THEN 1
        WHEN sku ILIKE 'RCA-04-W%' OR sku ILIKE '%W%' THEN 2
        WHEN sku ILIKE 'RCA-04-A%' OR sku ILIKE '%A%' THEN 3
        ELSE 4
      END
    LIMIT 1
  ) ci ON true
  
  UNION ALL
  
  SELECT 
    'RCA-21' as sku_pattern,
    'Bottom Rail End Cap' as component_name,
    ci.id,
    ci.sku,
    ci.item_name,
    CASE 
      WHEN ci.id IS NOT NULL THEN '✅ FOUND'
      ELSE '❌ NOT FOUND'
    END,
    CASE 
      WHEN ci.sku = 'RCA-21' THEN 1
      WHEN ci.sku ILIKE 'RCA-21-W%' OR ci.sku ILIKE '%W%' THEN 2
      WHEN ci.sku ILIKE 'RCA-21-A%' OR ci.sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  FROM org
  LEFT JOIN LATERAL (
    SELECT id, sku, item_name
    FROM "CatalogItems" 
    WHERE (sku = 'RCA-21' OR sku ILIKE 'RCA-21-%' OR sku ILIKE 'RCA21%')
      AND organization_id = org.id 
      AND deleted = false
    ORDER BY 
      CASE 
        WHEN sku = 'RCA-21' THEN 1
        WHEN sku ILIKE 'RCA-21-W%' OR sku ILIKE '%W%' THEN 2
        WHEN sku ILIKE 'RCA-21-A%' OR sku ILIKE '%A%' THEN 3
        ELSE 4
      END
    LIMIT 1
  ) ci ON true
  
  UNION ALL
  
  SELECT 
    'RC3101' as sku_pattern,
    'Side Channel Profile' as component_name,
    ci.id,
    ci.sku,
    ci.item_name,
    CASE 
      WHEN ci.id IS NOT NULL THEN '✅ FOUND'
      ELSE '❌ NOT FOUND'
    END,
    CASE 
      WHEN ci.sku = 'RC3101' THEN 1
      WHEN ci.sku ILIKE 'RC3101-W%' OR ci.sku ILIKE '%W%' THEN 2
      WHEN ci.sku ILIKE 'RC3101-A%' OR ci.sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  FROM org
  LEFT JOIN LATERAL (
    SELECT id, sku, item_name
    FROM "CatalogItems" 
    WHERE (sku = 'RC3101' OR sku ILIKE 'RC3101-%' OR sku ILIKE '%RC3101%')
      AND organization_id = org.id 
      AND deleted = false
    ORDER BY 
      CASE 
        WHEN sku = 'RC3101' THEN 1
        WHEN sku ILIKE 'RC3101-W%' OR sku ILIKE '%W%' THEN 2
        WHEN sku ILIKE 'RC3101-A%' OR sku ILIKE '%A%' THEN 3
        ELSE 4
      END
    LIMIT 1
  ) ci ON true
  
  UNION ALL
  
  SELECT 
    'RC3102' as sku_pattern,
    'Side Channel Cover' as component_name,
    ci.id,
    ci.sku,
    ci.item_name,
    CASE 
      WHEN ci.id IS NOT NULL THEN '✅ FOUND'
      ELSE '❌ NOT FOUND'
    END,
    CASE 
      WHEN ci.sku = 'RC3102' THEN 1
      WHEN ci.sku ILIKE 'RC3102-W%' OR ci.sku ILIKE '%W%' THEN 2
      WHEN ci.sku ILIKE 'RC3102-A%' OR ci.sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  FROM org
  LEFT JOIN LATERAL (
    SELECT id, sku, item_name
    FROM "CatalogItems" 
    WHERE (sku = 'RC3102' OR sku ILIKE 'RC3102-%' OR sku ILIKE '%RC3102%')
      AND organization_id = org.id 
      AND deleted = false
    ORDER BY 
      CASE 
        WHEN sku = 'RC3102' THEN 1
        WHEN sku ILIKE 'RC3102-W%' OR sku ILIKE '%W%' THEN 2
        WHEN sku ILIKE 'RC3102-A%' OR sku ILIKE '%A%' THEN 3
        ELSE 4
      END
    LIMIT 1
  ) ci ON true
  
  UNION ALL
  
  SELECT 
    'RCAS-09-75' as sku_pattern,
    'Insert/Gasket' as component_name,
    ci.id,
    ci.sku,
    ci.item_name,
    CASE 
      WHEN ci.id IS NOT NULL THEN '✅ FOUND'
      ELSE '❌ NOT FOUND'
    END,
    1
  FROM org
  LEFT JOIN LATERAL (
    SELECT id, sku, item_name
    FROM "CatalogItems" 
    WHERE (sku = 'RCAS-09-75' OR sku ILIKE 'RCAS-09-75%' OR sku ILIKE 'RCAS0975%')
      AND organization_id = org.id 
      AND deleted = false
    ORDER BY sku
    LIMIT 1
  ) ci ON true
  
  UNION ALL
  
  SELECT 
    'RC3104' as sku_pattern,
    'Top Fix Bracket' as component_name,
    ci.id,
    ci.sku,
    ci.item_name,
    CASE 
      WHEN ci.id IS NOT NULL THEN '✅ FOUND'
      ELSE '❌ NOT FOUND'
    END,
    CASE 
      WHEN ci.sku = 'RC3104' THEN 1
      WHEN ci.sku ILIKE 'RC3104-W%' OR ci.sku ILIKE '%W%' THEN 2
      WHEN ci.sku ILIKE 'RC3104-A%' OR ci.sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  FROM org
  LEFT JOIN LATERAL (
    SELECT id, sku, item_name
    FROM "CatalogItems" 
    WHERE (sku = 'RC3104' OR sku ILIKE 'RC3104-%' OR sku ILIKE '%RC3104%')
      AND organization_id = org.id 
      AND deleted = false
    ORDER BY 
      CASE 
        WHEN sku = 'RC3104' THEN 1
        WHEN sku ILIKE 'RC3104-W%' OR sku ILIKE '%W%' THEN 2
        WHEN sku ILIKE 'RC3104-A%' OR sku ILIKE '%A%' THEN 3
        ELSE 4
      END
    LIMIT 1
  ) ci ON true
)
SELECT 
  sku_pattern,
  component_name,
  status,
  found_sku,
  item_name,
  catalog_item_id,
  priority
FROM sku_tests
ORDER BY 
  CASE 
    WHEN status = '✅ FOUND' THEN 1
    ELSE 2
  END,
  sku_pattern;

