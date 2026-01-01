-- ====================================================
-- VERIFICACIÓN BÁSICA: Organizations y ProductTypes
-- ====================================================

-- 1️⃣ Verificar Organizations
SELECT 
    '1️⃣ ORGANIZATIONS' as step,
    id,
    organization_name,
    deleted
FROM "Organizations"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 5;

-- 2️⃣ Verificar ProductTypes (SIN filtro de org para ver todos)
SELECT 
    '2️⃣ ALL PRODUCTTYPES' as step,
    id,
    organization_id,
    code,
    name,
    deleted
FROM "ProductTypes"
WHERE deleted = false
ORDER BY organization_id, code
LIMIT 20;

-- 3️⃣ Verificar ProductTypes para TU org específica
SELECT 
    '3️⃣ PRODUCTTYPES FOR YOUR ORG' as step,
    id,
    code,
    name,
    deleted,
    archived
FROM "ProductTypes"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
ORDER BY code;

-- 4️⃣ Contar CatalogItems por org
SELECT 
    '4️⃣ CATALOGITEMS COUNT' as step,
    organization_id,
    COUNT(*) as total_items,
    COUNT(CASE WHEN is_fabric = true THEN 1 END) as fabric_items,
    COUNT(CASE WHEN deleted = false THEN 1 END) as active_items
FROM "CatalogItems"
GROUP BY organization_id
ORDER BY total_items DESC
LIMIT 5;

-- 5️⃣ Contar links en CatalogItemProductTypes
SELECT 
    '5️⃣ CATALOGITEMPRODUCTTYPES COUNT' as step,
    organization_id,
    COUNT(*) as total_links,
    COUNT(CASE WHEN deleted = false THEN 1 END) as active_links
FROM "CatalogItemProductTypes"
GROUP BY organization_id
LIMIT 5;








