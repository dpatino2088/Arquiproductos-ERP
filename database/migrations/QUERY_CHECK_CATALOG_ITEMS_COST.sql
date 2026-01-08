-- ====================================================
-- Query: Verificar costos en CatalogItems
-- ====================================================
-- Verificar si los CatalogItems tienen cost_exw definido
-- ====================================================

-- 1) Verificar CatalogItems usados en las líneas recientes
SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ci.cost_exw,
    ci.cost_exw IS NULL AS cost_is_null,
    bil.id AS bom_line_id,
    bil.resolved_sku,
    bil.unit_cost_exw,
    bil.total_cost_exw
FROM "CatalogItems" ci
LEFT JOIN "BomInstanceLines" bil ON bil.resolved_part_id = ci.id
WHERE bil.deleted = false
ORDER BY bil.created_at DESC
LIMIT 20;

-- 2) Contar CatalogItems sin cost_exw
SELECT 
    COUNT(*) AS total_items,
    COUNT(cost_exw) AS items_with_cost,
    COUNT(*) - COUNT(cost_exw) AS items_without_cost
FROM "CatalogItems"
WHERE deleted = false;

-- 3) Verificar costos en items específicos (usar SKUs de la imagen)
SELECT 
    sku,
    item_name,
    cost_exw,
    cost_exw IS NULL AS cost_is_null
FROM "CatalogItems"
WHERE sku IN (
    'RF-BALI-0300',
    'RC3007-W',
    'RF-MOMBASSA-5200',
    'RC3001-GR',
    'RCA-04-A',
    'V15P-08',
    'RC3153-GR',
    'RTU-42'
)
AND deleted = false;


