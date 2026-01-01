-- ============================================================================
-- VERIFICAR ORGANIZATION_ID Y ITEMS PARA DIAGNÓSTICO
-- ============================================================================

-- 1. Verificar todas las organizaciones disponibles
SELECT 
    'ORGANIZACIONES' as paso,
    o.id,
    o.organization_name,
    o.deleted,
    o.created_at
FROM "Organizations" o
WHERE o.deleted = false
ORDER BY o.created_at DESC;

-- 2. Verificar RCA-04-W con su organización
SELECT 
    'RCA-04-W CON ORGANIZACIÓN' as paso,
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
WHERE ci.sku = 'RCA-04-W';

-- 3. Verificar otros items RCA de la misma organización
SELECT 
    'OTROS ITEMS RCA MISMA ORG' as paso,
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
    WHERE sku = 'RCA-04-W' 
    LIMIT 1
)
    AND ci.sku LIKE 'RCA-%'
    AND ci.deleted = false
ORDER BY ci.sku;

-- 4. Contar items por organización (para ver cuál es la más activa)
SELECT 
    'CONTEO ITEMS POR ORG' as paso,
    ci.organization_id,
    o.organization_name,
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE ci.deleted = false) as active_items,
    COUNT(*) FILTER (WHERE ci.sku LIKE 'RCA-%') as rca_items
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.deleted = false
GROUP BY ci.organization_id, o.organization_name
ORDER BY active_items DESC;








