-- ====================================================
-- DIAGNÓSTICO ESTRUCTURADO: cut_length_mm NULL
-- ====================================================
-- Ejecutar fases en orden para identificar root cause
-- ====================================================

-- ====================================================
-- FASE 0: Elegir un BOM instance "reciente" y válido
-- ====================================================
SELECT 
  bi.id AS bom_instance_id,
  bi.sale_order_line_id,
  bi.bom_template_id,
  bt.name AS template_name,
  bi.status,
  bi.created_at
FROM "BomInstances" bi
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE bi.deleted = false
ORDER BY bi.created_at DESC
LIMIT 10;

-- ⚠️ SELECCIONA UN bom_instance_id donde:
--    bom_template_id IS NOT NULL
--    template_name IS NOT NULL
--    Guárdalo como v_bom_instance_id

-- ====================================================
-- FASE 1: Confirmar síntoma (líneas con cuts NULL)
-- ====================================================
-- ⚠️ REEMPLAZA '<v_bom_instance_id>' con el ID seleccionado
SELECT
  bil.id,
  bil.resolved_sku,
  bil.part_role,
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<v_bom_instance_id>'
  AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;

-- ✅ Expected: 
--    - Debe existir part_role='tube'
--    - Debe existir bottom_rail_profile (si aplica)
--    - Hoy probablemente cut_length_mm IS NULL

-- ====================================================
-- FASE 2: Verificar inputs (dimensiones accesibles)
-- ====================================================
-- ⚠️ REEMPLAZA '<v_bom_instance_id>' con el ID seleccionado
SELECT 
  bi.id AS bom_instance_id,
  sol.id AS sale_order_line_id,
  sol.width_m,
  sol.height_m,
  sol.qty,
  sol.product_type,
  sol.drive_type,
  ql.width_m AS ql_width_m,
  ql.height_m AS ql_height_m
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE bi.id = '<v_bom_instance_id>';

-- ✅ Expected: width_m y height_m NOT NULL
--    Si están NULL → ese es el root cause (no hay insumos)

-- ====================================================
-- FASE 3: Verificar reglas en template (BOMComponents)
-- ====================================================
-- ⚠️ REEMPLAZA '<v_bom_instance_id>' con el ID seleccionado
SELECT
  bc.id,
  bc.sequence_order,
  bc.component_role,
  bc.affects_role,
  bc.cut_axis,
  bc.cut_delta_mm,
  bc.cut_delta_scope,
  ci.sku AS component_sku
FROM "BOMComponents" bc
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bc.bom_template_id = (
  SELECT bom_template_id FROM "BomInstances" WHERE id = '<v_bom_instance_id>'
)
AND bc.deleted = false
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis <> 'none'
ORDER BY bc.sequence_order;

-- ✅ Expected: al menos una regla que afecte:
--    - affects_role = 'tube' y cut_axis='length'
--    - affects_role = 'bottom_rail_profile' y cut_axis='length' (si aplica)

-- ====================================================
-- FASE 4: Verificar roles en BomInstanceLines vs BOMComponents
-- ====================================================
-- ⚠️ REEMPLAZA '<v_bom_instance_id>' con el ID seleccionado
SELECT 
  'BomInstanceLines part_role' AS source,
  COUNT(DISTINCT bil.part_role) AS unique_roles,
  string_agg(DISTINCT bil.part_role, ', ' ORDER BY bil.part_role) AS roles_list
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<v_bom_instance_id>'
AND bil.deleted = false

UNION ALL

SELECT 
  'BOMComponents affects_role' AS source,
  COUNT(DISTINCT bc.affects_role) AS unique_roles,
  string_agg(DISTINCT bc.affects_role, ', ' ORDER BY bc.affects_role) AS roles_list
FROM "BOMComponents" bc
WHERE bc.bom_template_id = (
  SELECT bom_template_id FROM "BomInstances" WHERE id = '<v_bom_instance_id>'
)
AND bc.deleted = false
AND bc.affects_role IS NOT NULL;

-- ✅ Expected: Los roles deben coincidir (tube, bottom_rail_profile, etc.)
--    IMPORTANTE: BomInstanceLines usa 'part_role', BOMComponents usa 'affects_role'

