-- ====================================================
-- Diagnóstico: Componentes Faltantes y Resolución Incorrecta
-- ====================================================

-- 1. Verificar qué mapeos existen en BomRoleSkuMapping
SELECT 
    '1. Mapeos existentes' as check_name,
    m.component_role,
    m.operating_system_variant,
    m.tube_type,
    m.hardware_color,
    ci.sku,
    ci.item_name,
    m.priority
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
ORDER BY m.component_role, m.priority;

-- 2. Verificar operating_system_drive mapeado
SELECT 
    '2. operating_system_drive mapeos' as check_name,
    m.id,
    m.component_role,
    m.operating_system_variant,
    ci.sku,
    ci.item_name,
    cipt.product_type_id,
    pt.name as product_type_name
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
LEFT JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
WHERE m.deleted = false
    AND m.active = true
    AND m.component_role = 'operating_system_drive'
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid;

-- 3. Buscar CatalogItems para operating_system_drive (excluyendo M-CC-01)
SELECT 
    '3. CatalogItems para operating_system_drive (excluyendo M-CC-01)' as check_name,
    ci.id,
    ci.sku,
    ci.item_name,
    cipt.product_type_id,
    pt.name as product_type_name
FROM "CatalogItems" ci
JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND ci.deleted = false
    AND cipt.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
    AND cipt.deleted = false
    AND (ci.sku ILIKE '%DRIVE%' OR ci.item_name ILIKE '%DRIVE%' OR ci.item_name ILIKE '%BELT%')
    AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%TOOL%' OR ci.item_name ILIKE '%TOOL%')
ORDER BY 
    CASE WHEN ci.item_name ILIKE '%DRIVE%PLUG%' THEN 0 ELSE 1 END,
    ci.created_at DESC;

-- 4. Buscar motor_adapter CatalogItems
SELECT 
    '4. motor_adapter CatalogItems' as check_name,
    ci.id,
    ci.sku,
    ci.item_name,
    cipt.product_type_id,
    pt.name as product_type_name
FROM "CatalogItems" ci
JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND ci.deleted = false
    AND cipt.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
    AND cipt.deleted = false
    AND (ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' OR ci.sku ILIKE '%RC3162%' OR ci.item_name ILIKE '%ADAPTER%MOTOR%')
ORDER BY 
    CASE WHEN ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' THEN 0 ELSE 1 END,
    ci.created_at DESC;

-- 5. Verificar si motor_adapter tiene mapeo
SELECT 
    '5. motor_adapter mapeos' as check_name,
    m.id,
    m.component_role,
    ci.sku,
    ci.item_name
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.component_role = 'motor_adapter'
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid;

-- 6. Buscar bottom_rail_profile CatalogItems
SELECT 
    '6. bottom_rail_profile CatalogItems' as check_name,
    ci.id,
    ci.sku,
    ci.item_name,
    cipt.product_type_id
FROM "CatalogItems" ci
JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND ci.deleted = false
    AND cipt.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
    AND cipt.deleted = false
    AND (ci.sku ILIKE '%BOTTOM%RAIL%' OR ci.item_name ILIKE '%BOTTOM%RAIL%')
ORDER BY ci.created_at DESC
LIMIT 5;

-- 7. Verificar si bottom_rail_profile tiene mapeo
SELECT 
    '7. bottom_rail_profile mapeos' as check_name,
    m.id,
    m.component_role,
    ci.sku,
    ci.item_name
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.component_role = 'bottom_rail_profile'
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid;


