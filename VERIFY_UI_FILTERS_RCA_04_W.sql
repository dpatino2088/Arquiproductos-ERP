-- ============================================================================
-- VERIFICAR POR QUÉ RCA-04-W NO APARECE EN LA UI
-- ============================================================================

-- 1. Verificar el item completo con todos los campos
SELECT 
    '1. Item completo' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.item_type,
    ci.measure_basis,
    ci.uom,
    ci.is_fabric,
    ci.collection_name,
    ci.variant_name,
    ci.cost_exw,
    ci.msrp,
    ci.updated_at
FROM "CatalogItems" ci
WHERE ci.sku = 'RCA-04-W'
ORDER BY ci.updated_at DESC;

-- 2. Verificar si hay otros items con el mismo SKU pero diferente organization_id
SELECT 
    '2. Items con mismo SKU' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.updated_at
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W'
ORDER BY ci.updated_at DESC;

-- 3. Verificar qué organization_id está usando la UI (necesitas verificar esto en el código)
-- Por ahora, verificamos todas las organizaciones
SELECT 
    '3. Organizaciones disponibles' as paso,
    o.id,
    o.organization_name,
    o.created_at
FROM "Organizations" o
WHERE o.deleted = false
ORDER BY o.created_at DESC;

-- 4. Verificar items recientes de la misma organización
SELECT 
    '4. Items recientes misma organización' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.updated_at
FROM "CatalogItems" ci
WHERE ci.organization_id = (
    SELECT ci2.organization_id 
    FROM "CatalogItems" ci2
    WHERE ci2.sku = 'RCA-04-W' 
    LIMIT 1
)
    AND ci.deleted = false
ORDER BY ci.updated_at DESC
LIMIT 10;

