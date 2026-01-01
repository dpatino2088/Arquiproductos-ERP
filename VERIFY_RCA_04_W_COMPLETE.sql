-- ============================================================================
-- VERIFICACIÓN COMPLETA DE RCA-04-W
-- ============================================================================

-- 1. Verificar si RCA-04-W existe y su estado completo
SELECT 
    'ESTADO COMPLETO RCA-04-W' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.discontinued,
    ci.item_type,
    ci.measure_basis,
    ci.uom,
    ci.is_fabric,
    ci.created_at,
    ci.updated_at
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W';

-- 2. Comparar con RCA-04-A (que SÍ aparece)
SELECT 
    'COMPARACIÓN RCA-04-A vs RCA-04-W' as paso,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.discontinued,
    ci.item_type,
    ci.measure_basis,
    ci.uom
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;

-- 3. Verificar todos los items RCA-04-* de la misma organización
SELECT 
    'TODOS LOS RCA-04-* MISMA ORG' as paso,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.discontinued
FROM "CatalogItems" ci
WHERE ci.organization_id = (
    SELECT organization_id 
    FROM "CatalogItems" 
    WHERE sku = 'RCA-04-A' 
    LIMIT 1
)
    AND ci.sku LIKE 'RCA-04-%'
    AND ci.deleted = false
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

-- 5. Simular la query que hace el hook (organization_id + deleted = false)
SELECT 
    'SIMULACIÓN QUERY HOOK' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived
FROM "CatalogItems" ci
WHERE ci.organization_id = (
    SELECT organization_id 
    FROM "CatalogItems" 
    WHERE sku = 'RCA-04-A' 
    LIMIT 1
)
    AND ci.deleted = false
    AND ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;








