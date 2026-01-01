-- ============================================================================
-- VERIFICAR ESTADO DEL ITEM RCA-04-W
-- ============================================================================

-- 1. Buscar el item por SKU
SELECT 
    '1. Item por SKU' as paso,
    id,
    sku,
    item_name,
    organization_id,
    active,
    deleted,
    archived,
    updated_at,
    created_at,
    CASE 
        WHEN deleted = true THEN '❌ ELIMINADO'
        WHEN archived = true THEN '⚠️ ARCHIVADO'
        WHEN active = false THEN '⚠️ INACTIVO'
        ELSE '✅ ACTIVO'
    END as status
FROM "CatalogItems"
WHERE sku = 'RCA-04-W'
ORDER BY updated_at DESC;

-- 2. Buscar variaciones del SKU (con guiones, sin guiones, etc.)
SELECT 
    '2. Variaciones del SKU' as paso,
    id,
    sku,
    item_name,
    active,
    deleted,
    archived,
    updated_at
FROM "CatalogItems"
WHERE sku ILIKE '%RCA-04%'
   OR sku ILIKE '%RCA04%'
   OR item_name ILIKE '%RCA-04%'
ORDER BY updated_at DESC;

-- 3. Verificar todos los items recientemente actualizados
SELECT 
    '3. Items actualizados recientemente' as paso,
    id,
    sku,
    item_name,
    organization_id,
    active,
    deleted,
    archived,
    updated_at
FROM "CatalogItems"
WHERE updated_at >= NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC
LIMIT 20;

-- 4. Verificar si hay items con organization_id diferente
SELECT 
    '4. Items RCA-04-W por organización' as paso,
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








