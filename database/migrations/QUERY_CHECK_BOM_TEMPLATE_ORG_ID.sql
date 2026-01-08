-- Query para verificar el organization_id del BOM Template encontrado
-- y comparar con lo que debería ser

-- 1. Ver el template completo con organization_id
SELECT 
  bt.id,
  bt.name,
  bt.product_type_id,
  bt.organization_id,
  bt.active,
  bt.deleted,
  pt.code as product_type_code,
  pt.name as product_type_name
FROM "BOMTemplates" bt
LEFT JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
WHERE bt.id = '184658a6-f6af-4199-bea2-44d29e6a88dc';

-- 2. Ver todos los templates para ese product_type_id (sin filtrar por organization_id)
SELECT 
  bt.id,
  bt.name,
  bt.product_type_id,
  bt.organization_id,
  bt.active,
  bt.deleted
FROM "BOMTemplates" bt
WHERE bt.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'
  AND bt.deleted = false
  AND bt.active = true;

-- 3. Ver qué organization_id está usando actualmente el usuario
-- (Necesitas reemplazar con tu organization_id actual)
SELECT 
  id,
  name,
  code
FROM "Organizations"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

