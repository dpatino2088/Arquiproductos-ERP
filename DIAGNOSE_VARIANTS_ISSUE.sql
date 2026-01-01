-- ====================================================
-- DIAGNÓSTICO COMPLETO: VariantsStep Collections/Variants
-- ====================================================
-- Reemplaza el organization_id con tu UUID real
-- ====================================================

-- 1️⃣  VERIFICAR PRODUCT TYPES
SELECT 
    '1️⃣ PRODUCT TYPES' as section,
    id,
    code,
    name,
    deleted
FROM "ProductTypes"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
ORDER BY sort_order, name;

-- 2️⃣  VERIFICAR CATALOGITEMPRODUCTTYPES (Join Table) - Relaciones por ProductType
SELECT 
    '2️⃣ CATALOGITEMPRODUCTTYPES' as section,
    pt.code as product_type_code,
    pt.name as product_type_name,
    COUNT(cipt.id) as items_linked
FROM "ProductTypes" pt
LEFT JOIN "CatalogItemProductTypes" cipt ON (
    cipt.product_type_id = pt.id 
    AND cipt.organization_id = pt.organization_id
    AND cipt.deleted = false
)
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
  AND pt.deleted = false
GROUP BY pt.id, pt.code, pt.name
ORDER BY pt.code;

-- 3️⃣  VERIFICAR FABRIC ITEMS (is_fabric=true)
SELECT 
    '3️⃣ FABRIC ITEMS TOTALES' as section,
    COUNT(*) as total_fabric_items,
    COUNT(DISTINCT collection_name) as unique_collections,
    COUNT(DISTINCT CASE WHEN collection_name IS NOT NULL THEN collection_name END) as collections_with_name
FROM "CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
  AND is_fabric = true
  AND deleted = false;

-- 4️⃣  FABRIC ITEMS POR PRODUCT TYPE
SELECT 
    '4️⃣ FABRIC ITEMS POR PRODUCT TYPE' as section,
    pt.code as product_type_code,
    pt.name as product_type_name,
    COUNT(DISTINCT ci.id) as fabric_items_count,
    COUNT(DISTINCT ci.collection_name) as collections_count,
    string_agg(DISTINCT ci.collection_name, ', ' ORDER BY ci.collection_name) as collection_names
FROM "ProductTypes" pt
LEFT JOIN "CatalogItemProductTypes" cipt ON (
    cipt.product_type_id = pt.id 
    AND cipt.organization_id = pt.organization_id
    AND cipt.deleted = false
)
LEFT JOIN "CatalogItems" ci ON (
    ci.id = cipt.catalog_item_id
    AND ci.organization_id = cipt.organization_id
    AND ci.is_fabric = true
    AND ci.deleted = false
    AND ci.collection_name IS NOT NULL
    AND ci.collection_name != ''
)
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
  AND pt.deleted = false
GROUP BY pt.id, pt.code, pt.name
ORDER BY pt.code;

-- 5️⃣  EJEMPLO: DUAL SHADE - Collections disponibles
SELECT 
    '5️⃣ DUAL SHADE COLLECTIONS' as section,
    ci.collection_name,
    COUNT(*) as variant_count,
    string_agg(ci.variant_name, ', ' ORDER BY ci.variant_name) as variants
FROM "ProductTypes" pt
INNER JOIN "CatalogItemProductTypes" cipt ON (
    cipt.product_type_id = pt.id 
    AND cipt.organization_id = pt.organization_id
    AND cipt.deleted = false
)
INNER JOIN "CatalogItems" ci ON (
    ci.id = cipt.catalog_item_id
    AND ci.organization_id = cipt.organization_id
    AND ci.is_fabric = true
    AND ci.deleted = false
    AND ci.collection_name IS NOT NULL
    AND ci.collection_name != ''
)
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
  AND pt.code = 'DUAL'
  AND pt.deleted = false
GROUP BY ci.collection_name
ORDER BY ci.collection_name;

-- 6️⃣  VERIFICAR SI HAY ITEMS SIN LINKEAR
SELECT 
    '6️⃣ FABRIC ITEMS SIN LINK A PRODUCTTYPE' as section,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.family,
    ci.collection_name,
    ci.variant_name
FROM "CatalogItems" ci
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
  AND ci.is_fabric = true
  AND ci.deleted = false
  AND ci.collection_name IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM "CatalogItemProductTypes" cipt
      WHERE cipt.catalog_item_id = ci.id
        AND cipt.organization_id = ci.organization_id
        AND cipt.deleted = false
  )
LIMIT 10;
