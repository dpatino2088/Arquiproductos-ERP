-- ============================================================================
-- VERIFICAR SI RCA-04-W EXISTE Y POR QUÉ NO APARECE EN LA UI
-- ============================================================================

-- 1. Buscar todos los items RCA-04-*
SELECT 
    'TODOS LOS RCA-04-*' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.updated_at,
    CASE 
        WHEN ci.deleted = true THEN '❌ ELIMINADO'
        WHEN ci.archived = true THEN '⚠️ ARCHIVADO'
        WHEN ci.active = false THEN '⚠️ INACTIVO'
        WHEN ci.organization_id IS NULL THEN '⚠️ SIN organization_id'
        ELSE '✅ DEBERÍA APARECER'
    END as status
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku LIKE 'RCA-04-%'
ORDER BY ci.sku;

-- 2. Verificar específicamente RCA-04-W
SELECT 
    'RCA-04-W ESPECÍFICO' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.item_type,
    ci.measure_basis,
    ci.uom,
    ci.updated_at
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W';

-- 3. Comparar RCA-04-A (que SÍ aparece) con RCA-04-W (que NO aparece)
SELECT 
    'COMPARACIÓN RCA-04-A vs RCA-04-W' as paso,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.item_type,
    ci.measure_basis,
    ci.uom
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;

-- 4. Verificar si hay algún problema con el organization_id
SELECT 
    'VERIFICAR ORGANIZATION_ID' as paso,
    ci.sku,
    ci.organization_id,
    o.organization_name,
    COUNT(*) OVER (PARTITION BY ci.organization_id) as items_in_same_org
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;








