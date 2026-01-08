-- ====================================================
-- Query: Verificar Normalización de BOMTemplate
-- ====================================================
-- Verifica que el template esté normalizado después de ejecutar
-- la migración 407_normalize_specific_bom_template.sql
-- ====================================================

-- Template ID: 184658a6-f6af-4199-bea2-44d29e6a88dc
-- (editar en los queries si es necesario)

-- 1) Verificar roles están en snake_case
SELECT 
  'Roles no normalizados (deben ser snake_case)' as check_type,
  component_role,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
  AND component_role IS NOT NULL
  AND component_role != lower(regexp_replace(component_role, '\s+', '_', 'g'))
GROUP BY component_role
ORDER BY component_role;

-- 2) Verificar UOM no tiene 'ft' (debe ser 'm')
SELECT 
  'UOM en ft (debe ser m)' as check_type,
  uom,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
  AND uom = 'ft'
GROUP BY uom;

-- 3) Verificar duplicados auto-select por role
SELECT 
  'Duplicados auto-select por role' as check_type,
  component_role,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
  AND (auto_select = true OR component_item_id IS NULL)
GROUP BY component_role
HAVING COUNT(*) > 1
ORDER BY component_role;

-- 4) Verificar fabric fija en template (debe estar eliminada)
SELECT 
  'Fabric fija en template (debe estar eliminada)' as check_type,
  component_role,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
  AND component_role = 'fabric'
  AND component_item_id IS NOT NULL
GROUP BY component_role;

-- 5) Resumen final (lo que quedó)
SELECT 
  'Resumen final' as check_type,
  component_role, 
  uom, 
  auto_select, 
  component_item_id IS NOT NULL as is_fixed,
  COUNT(*) as n
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
GROUP BY component_role, uom, auto_select, component_item_id IS NOT NULL
ORDER BY component_role, auto_select DESC, is_fixed DESC;

