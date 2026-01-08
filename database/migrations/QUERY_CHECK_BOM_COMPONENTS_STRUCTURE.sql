-- ====================================================
-- Query: Verificar Estructura de BOMComponents
-- ====================================================
-- Verifica qué columnas tiene BOMComponents para ajustar el código
-- ====================================================

-- Template ID: 184658a6-f6af-4199-bea2-44d29e6a88dc
-- (editar en los queries si es necesario)

-- 1) Verificar columnas disponibles en BOMComponents
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'BOMComponents'
ORDER BY ordinal_position;

-- 2) Verificar valores reales en el template
SELECT 
  component_role,
  uom,
  auto_select,
  component_item_id IS NOT NULL as is_fixed,
  qty_type,
  qty_value,
  qty_per_unit,
  COUNT(*) as count
FROM "BOMComponents"
WHERE bom_template_id = '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid
  AND deleted = false
GROUP BY component_role, uom, auto_select, component_item_id IS NOT NULL, qty_type, qty_value, qty_per_unit
ORDER BY component_role, auto_select DESC, is_fixed DESC;

