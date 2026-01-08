-- Query simplificada para verificar el organization_id del BOM Template

-- Ver el template completo con organization_id
SELECT 
  id,
  name,
  product_type_id,
  organization_id,
  active,
  deleted
FROM "BOMTemplates"
WHERE id = '184658a6-f6af-4199-bea2-44d29e6a88dc';

-- Ver todos los templates para ese product_type_id
SELECT 
  id,
  name,
  product_type_id,
  organization_id,
  active,
  deleted
FROM "BOMTemplates"
WHERE product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'
  AND deleted = false
  AND active = true;


