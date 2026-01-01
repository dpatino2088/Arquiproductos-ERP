-- ============================================================================
-- RESTAURAR ITEM RCA-04-W SI FUE ELIMINADO ACCIDENTALMENTE
-- ============================================================================

-- 1. Verificar estado actual
SELECT 
    'ESTADO ACTUAL' as paso,
    id,
    sku,
    item_name,
    organization_id,
    active,
    deleted,
    archived,
    updated_at
FROM "CatalogItems"
WHERE sku = 'RCA-04-W'
ORDER BY updated_at DESC;

-- 2. Restaurar si está eliminado o archivado
UPDATE "CatalogItems"
SET 
    deleted = false,
    archived = false,
    active = true,
    updated_at = NOW()
WHERE sku = 'RCA-04-W'
    AND (deleted = true OR archived = true OR active = false);

-- 3. Verificar resultado
SELECT 
    'ESTADO DESPUÉS DE RESTAURAR' as paso,
    id,
    sku,
    item_name,
    organization_id,
    active,
    deleted,
    archived,
    updated_at,
    CASE 
        WHEN deleted = true THEN '❌ ELIMINADO'
        WHEN archived = true THEN '⚠️ ARCHIVADO'
        WHEN active = false THEN '⚠️ INACTIVO'
        ELSE '✅ ACTIVO Y VISIBLE'
    END as status
FROM "CatalogItems"
WHERE sku = 'RCA-04-W'
ORDER BY updated_at DESC;








