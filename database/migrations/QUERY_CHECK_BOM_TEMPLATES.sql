-- Query para verificar si hay BOM Templates en la base de datos
-- Reemplaza :organization_id y :product_type_id con los valores reales

-- 1. Verificar todos los BOM Templates activos para una organización
SELECT 
  id,
  name,
  product_type_id,
  organization_id,
  active,
  deleted,
  created_at
FROM "BOMTemplates"
WHERE organization_id = 'TU_ORGANIZATION_ID_AQUI'  -- Reemplaza con tu organization_id
  AND deleted = false
  AND active = true
ORDER BY created_at DESC;

-- 2. Verificar BOM Templates para un ProductType específico
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
WHERE bt.organization_id = 'TU_ORGANIZATION_ID_AQUI'  -- Reemplaza con tu organization_id
  AND bt.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'  -- El product_type_id del config
  AND bt.deleted = false
  AND bt.active = true
ORDER BY bt.created_at DESC;

-- 3. Verificar si el ProductType existe
SELECT 
  id,
  code,
  name,
  organization_id,
  deleted
FROM "ProductTypes"
WHERE id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'
  AND deleted = false;

-- 4. Contar todos los BOM Templates (sin filtros)
SELECT 
  COUNT(*) as total_templates,
  COUNT(*) FILTER (WHERE deleted = false AND active = true) as active_templates,
  COUNT(*) FILTER (WHERE organization_id = 'TU_ORGANIZATION_ID_AQUI') as org_templates
FROM "BOMTemplates";


