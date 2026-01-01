-- ============================================================================
-- CORREGIR organization_id DEL ITEM RCA-04-W SI NO COINCIDE
-- ============================================================================

-- 1. Verificar el organization_id actual del item
SELECT 
    '1. Estado actual' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id as item_org_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W';

-- 2. Verificar qué organization_id debería tener (basado en otros items similares)
SELECT 
    '2. Organization_id de items similares' as paso,
    ci.organization_id,
    o.organization_name,
    COUNT(*) as item_count
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku LIKE 'RCA-%'
    AND ci.deleted = false
GROUP BY ci.organization_id, o.organization_name
ORDER BY item_count DESC;

-- 3. Si el organization_id está mal, corregirlo
-- NOTA: Ejecuta esto solo si el organization_id del item no coincide con el de otros items RCA
-- Reemplaza 'ORGANIZATION_ID_CORRECTO' con el ID correcto de la consulta anterior
/*
UPDATE "CatalogItems"
SET 
    organization_id = 'ORGANIZATION_ID_CORRECTO',
    updated_at = NOW()
WHERE sku = 'RCA-04-W'
    AND organization_id != 'ORGANIZATION_ID_CORRECTO';
*/

-- 4. Verificar resultado
SELECT 
    '3. Estado después de corregir' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    CASE 
        WHEN ci.deleted = true THEN '❌ ELIMINADO'
        WHEN ci.archived = true THEN '⚠️ ARCHIVADO'
        WHEN ci.active = false THEN '⚠️ INACTIVO'
        WHEN ci.organization_id IS NULL THEN '⚠️ SIN organization_id'
        ELSE '✅ DEBERÍA APARECER EN UI'
    END as status
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W';








