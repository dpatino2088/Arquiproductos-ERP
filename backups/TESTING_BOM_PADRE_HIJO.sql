/**
 * Script de Testing: Flujo BOM PADRE-HIJO
 * 
 * Verifica que el nuevo flujo funciona correctamente después de la migración.
 * Ejecutar DESPUÉS de 20260119_bom_padre_hijo_separation.sql
 */

-- ============================================================================
-- 1. VERIFICAR MIGRACIÓN EXITOSA
-- ============================================================================

-- 1.1. Verificar que BOMTemplateSlots se poblaron
SELECT 
  'BOMTemplates' as table_name,
  COUNT(*) as count
FROM public."BOMTemplates" 
WHERE deleted = false

UNION ALL

SELECT 
  'BOMTemplateSlots' as table_name,
  COUNT(*) as count
FROM public."BOMTemplateSlots"

UNION ALL

SELECT 
  'BOMComponents' as table_name,
  COUNT(*) as count
FROM public."BOMComponents" 
WHERE deleted = false

UNION ALL

SELECT 
  'CatalogItemComponents' as table_name,
  COUNT(*) as count
FROM public."CatalogItemComponents" 
WHERE deleted = false;

-- Esperado:
-- BOMTemplates: X (tus templates existentes)
-- BOMTemplateSlots: >= X (al menos tantos como templates × roles PADRE)
-- BOMComponents: X (sin cambios)
-- CatalogItemComponents: 0 (vacío hasta que agregues HIJOS manualmente)

-- 1.2. Verificar que resolved_part_id es nullable
SELECT 
  column_name, 
  is_nullable, 
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'BOMInstanceLines'
  AND column_name = 'resolved_part_id';

-- Esperado: is_nullable = 'YES'

-- ============================================================================
-- 2. VERIFICAR SLOTS POR TEMPLATE
-- ============================================================================

SELECT 
  bt.code as template_code,
  bt.name as template_name,
  pt.name as product_type,
  COUNT(bts.id) as slots_count,
  STRING_AGG(bts.item_role, ', ' ORDER BY bts.item_role) as roles
FROM public."BOMTemplates" bt
LEFT JOIN public."ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN public."BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
WHERE bt.deleted = false
GROUP BY bt.id, bt.code, bt.name, pt.name
ORDER BY pt.name, bt.code;

-- Esperado: Cada template debe tener varios slots (roles PADRE)

-- ============================================================================
-- 3. EJEMPLO: CREAR RELACIÓN SKU → HIJOS (Manual)
-- ============================================================================

-- Primero, verificar qué SKUs PADRE tienes
SELECT 
  id,
  sku,
  name,
  item_role,
  color
FROM public."CatalogItems"
WHERE organization_id = (SELECT id FROM public."Organizations" WHERE deleted = false LIMIT 1)
  AND item_role IN ('motor', 'drive', 'bracket', 'headbox', 'bottom_bar')
  AND is_active = true
ORDER BY item_role, sku
LIMIT 20;

-- Ejemplo: Si tienes motor 'MTR-01-W', agregar sus HIJOS
-- Reemplaza los IDs con los reales de tu base de datos

/*
-- Obtener IDs de ejemplo (ajusta SKUs a los tuyos)
WITH items AS (
  SELECT id, sku FROM public."CatalogItems"
  WHERE sku IN ('MTR-01-W', 'ADT-01', 'ECP-01-W', 'SCR-M4-10')
    AND organization_id = 'YOUR_ORG_ID'
)
INSERT INTO public."CatalogItemComponents" (
  organization_id,
  parent_item_id,
  child_item_id,
  child_role,
  qty,
  uom,
  required
)
SELECT 
  'YOUR_ORG_ID',
  (SELECT id FROM items WHERE sku = 'MTR-01-W'), -- PADRE: Motor
  (SELECT id FROM items WHERE sku = 'ADT-01'),   -- HIJO: Adapter
  'adapter',
  1,
  'ea',
  true
WHERE EXISTS (SELECT 1 FROM items WHERE sku = 'MTR-01-W')
  AND EXISTS (SELECT 1 FROM items WHERE sku = 'ADT-01')

UNION ALL

SELECT 
  'YOUR_ORG_ID',
  (SELECT id FROM items WHERE sku = 'MTR-01-W'), -- PADRE: Motor
  (SELECT id FROM items WHERE sku = 'ECP-01-W'), -- HIJO: End Cap
  'end_cap',
  2,
  'ea',
  true
WHERE EXISTS (SELECT 1 FROM items WHERE sku = 'MTR-01-W')
  AND EXISTS (SELECT 1 FROM items WHERE sku = 'ECP-01-W')

UNION ALL

SELECT 
  'YOUR_ORG_ID',
  (SELECT id FROM items WHERE sku = 'MTR-01-W'), -- PADRE: Motor
  (SELECT id FROM items WHERE sku = 'SCR-M4-10'), -- HIJO: Screw
  'screw',
  4,
  'ea',
  true
WHERE EXISTS (SELECT 1 FROM items WHERE sku = 'MTR-01-W')
  AND EXISTS (SELECT 1 FROM items WHERE sku = 'SCR-M4-10');
*/

-- ============================================================================
-- 4. TESTING: Generar BOM con nueva función
-- ============================================================================

-- 4.1. Crear quote de prueba
DO $$
DECLARE
  v_org_id uuid;
  v_quote_id uuid;
  v_line_id uuid;
  v_product_type_id uuid;
  v_fabric_item_id uuid;
  v_motor_item_id uuid;
  v_bom_instance_id uuid;
BEGIN
  -- Obtener org_id
  SELECT id INTO v_org_id FROM public."Organizations" WHERE deleted = false LIMIT 1;
  
  -- Obtener product_type_id (Roller Shade)
  SELECT id INTO v_product_type_id 
  FROM public."ProductTypes" 
  WHERE organization_id = v_org_id 
    AND (code = 'roller_shade' OR name ILIKE '%roller%')
  LIMIT 1;
  
  -- Obtener fabric item
  SELECT id INTO v_fabric_item_id
  FROM public."CatalogItems"
  WHERE organization_id = v_org_id
    AND is_roll = true
    AND is_active = true
  LIMIT 1;
  
  -- Obtener motor item
  SELECT id INTO v_motor_item_id
  FROM public."CatalogItems"
  WHERE organization_id = v_org_id
    AND item_role = 'motor'
    AND is_active = true
  LIMIT 1;

  IF v_org_id IS NULL OR v_product_type_id IS NULL OR v_fabric_item_id IS NULL THEN
    RAISE EXCEPTION 'Missing required data (org_id, product_type, or fabric)';
  END IF;

  -- Crear quote
  INSERT INTO public."Quotes" (organization_id, quote_no, status)
  VALUES (v_org_id, 'TEST-BOM-' || to_char(now(), 'YYYYMMDD-HH24MISS'), 'draft')
  RETURNING id INTO v_quote_id;

  -- Crear quote line (usando columnas reales del dump 2026-01-19)
  INSERT INTO public."QuoteLines" (
    organization_id,
    quote_id,
    catalog_item_id,
    quantity,
    width_m,
    height_m,
    sqm,
    msrp,
    net_price
  ) VALUES (
    v_org_id,
    v_quote_id,
    v_fabric_item_id,
    1,
    1.5, -- 1.5m width
    2.0, -- 2.0m height
    3.0, -- 1.5 × 2.0 = 3.0 sqm
    100, -- MSRP por sqm
    100  -- net_price por sqm
  )
  RETURNING id INTO v_line_id;

  -- ✅ Simular opciones de configuración (kind='option')
  -- NOTA: component_role debe ser un rol válido de la lista permitida
  -- Las opciones de configuración (color, size, etc) van en el payload
  -- Por ahora, omitimos este paso ya que no es crítico para testing de BOM
  -- El BOM se genera con las selecciones de SKU (kind='selection')

  -- ✅ NUEVO: Simular selección de SKU PADRE (kind='selection')
  IF v_motor_item_id IS NOT NULL THEN
    INSERT INTO public."QuoteLineComponents" (
      organization_id,
      quote_line_id,
      kind,
      component_role,
      catalog_item_id,
      payload,
      source
    ) VALUES (
      v_org_id,
      v_line_id,
      'selection', -- ✅ NUEVO kind
      'motor',
      v_motor_item_id,
      jsonb_build_object('sku', (SELECT sku FROM public."CatalogItems" WHERE id = v_motor_item_id)),
      'configured_component'
    );
  END IF;

  -- Generar BOM usando nueva función
  BEGIN
    SELECT public.generate_bom_from_slots(v_org_id, v_line_id, v_product_type_id)
    INTO v_bom_instance_id;

    RAISE NOTICE 'SUCCESS: BOM Instance created: %', v_bom_instance_id;
    RAISE NOTICE 'Quote ID: %, QuoteLine ID: %', v_quote_id, v_line_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'ERROR generating BOM: %', SQLERRM;
      -- No fallar, solo informar
  END;

  -- Mostrar resultados
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Test Quote Created:';
  RAISE NOTICE 'Organization: %', v_org_id;
  RAISE NOTICE 'Quote ID: %', v_quote_id;
  RAISE NOTICE 'QuoteLine ID: %', v_line_id;
  RAISE NOTICE 'BOM Instance ID: %', v_bom_instance_id;
  RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- 5. VERIFICAR RESULTADO DEL BOM GENERADO
-- ============================================================================

-- 5.1. Ver última instancia creada
SELECT 
  bi.id as instance_id,
  bi.quote_line_id,
  bt.code as template_code,
  bt.name as template_name,
  COUNT(bil.id) as lines_count
FROM public."BOMInstances" bi
JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
GROUP BY bi.id, bi.quote_line_id, bt.code, bt.name
ORDER BY bi.created_at DESC
LIMIT 5;

-- 5.2. Ver líneas del BOM (PADRES e HIJOS)
WITH last_instance AS (
  SELECT id 
  FROM public."BOMInstances" 
  WHERE deleted = false 
  ORDER BY created_at DESC 
  LIMIT 1
)
SELECT 
  bil.part_role,
  ci.sku,
  ci.name as item_name,
  bil.qty,
  bil.uom,
  bil.unit_cost_exw,
  bil.total_cost_exw,
  CASE 
    WHEN bil.bom_component_id IS NULL THEN 'HIJO'
    ELSE 'PADRE'
  END as type,
  CASE 
    WHEN bil.resolved_part_id IS NULL THEN 'Sin SKU (pendiente)'
    ELSE 'Con SKU'
  END as status
FROM public."BOMInstanceLines" bil
LEFT JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.bom_instance_id = (SELECT id FROM last_instance)
ORDER BY 
  CASE WHEN bil.bom_component_id IS NULL THEN 2 ELSE 1 END, -- PADRES primero
  bil.part_role;

-- Esperado:
-- - PADRES listados (tube, motor, bottom_bar, etc.)
-- - Algunos con SKU, otros sin SKU (NULL)
-- - HIJOS listados debajo de su PADRE (adapter, end_cap, screw)
-- - HIJOS siempre con SKU

-- ============================================================================
-- 6. COMPARAR: Legacy vs Nueva función
-- ============================================================================

-- 6.1. Ejecutar ambas funciones con misma quote line (en quotes de prueba separadas)

/*
-- Legacy (con heurísticas)
SELECT public.generate_bom_instance_for_quote_line(
  'ORG_ID'::uuid,
  'QUOTE_LINE_ID_1'::uuid,
  'PRODUCT_TYPE_ID'::uuid
);

-- Nueva (sin heurísticas)
SELECT public.generate_bom_from_slots(
  'ORG_ID'::uuid,
  'QUOTE_LINE_ID_2'::uuid,
  'PRODUCT_TYPE_ID'::uuid
);
*/

-- Comparar líneas generadas
/*
SELECT 'Legacy' as method, COUNT(*) as lines_count
FROM public."BOMInstanceLines"
WHERE bom_instance_id = 'LEGACY_INSTANCE_ID'

UNION ALL

SELECT 'Slots-based' as method, COUNT(*) as lines_count
FROM public."BOMInstanceLines"
WHERE bom_instance_id = 'NEW_INSTANCE_ID';
*/

-- ============================================================================
-- 7. LIMPIAR DATOS DE PRUEBA
-- ============================================================================

-- Ejecutar si quieres limpiar el quote de prueba creado arriba

/*
DELETE FROM public."Quotes" 
WHERE quote_no LIKE 'TEST-BOM-%' 
  AND created_at > now() - interval '1 hour';
*/

-- ============================================================================
-- 8. QUERY ÚTIL: Ver configuración completa de una QuoteLine
-- ============================================================================

-- Reemplaza QUOTE_LINE_ID con el ID real
/*
SELECT 
  qlc.component_role,
  qlc.kind,
  qlc.catalog_item_id,
  ci.sku,
  ci.name as item_name,
  qlc.payload
FROM public."QuoteLineComponents" qlc
LEFT JOIN public."CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = 'QUOTE_LINE_ID'
  AND qlc.deleted = false
ORDER BY 
  CASE qlc.kind 
    WHEN 'selection' THEN 1 
    WHEN 'option' THEN 2 
    ELSE 3 
  END,
  qlc.component_role;
*/

-- Esperado:
-- kind='selection': motor, drive, bottom_bar, headbox, etc (con catalog_item_id)
-- kind='option': hardware_color, drive_type, cassette, etc (sin catalog_item_id)

-- ============================================================================
-- 9. VERIFICAR FUNCIÓN HELPER
-- ============================================================================

-- Ver selecciones de SKU PADRE para una quote line
/*
SELECT * FROM public.get_parent_sku_selections(
  'ORG_ID'::uuid,
  'QUOTE_LINE_ID'::uuid
);
*/

-- Esperado: Lista de SKUs PADRE elegidos por el usuario

-- ============================================================================
-- NOTAS
-- ============================================================================

-- ✅ Si todo funciona correctamente:
--   1. BOMTemplateSlots tiene slots (roles PADRE)
--   2. generate_bom_from_slots() genera instancias sin errores
--   3. BOMInstanceLines permite resolved_part_id NULL
--   4. HIJOS se agregan cuando hay relación en CatalogItemComponents

-- ❌ Si hay errores:
--   1. Verificar que migración se ejecutó completa
--   2. Revisar logs de PostgreSQL
--   3. Ejecutar queries individuales para aislar problema

-- 📝 Próximos pasos:
--   1. Poblar CatalogItemComponents con relaciones SKU → HIJOS reales
--   2. Testing desde UI (crear quote line, verificar BOM generado)
--   3. Modificar BOMTemplates UI para editar HIJOS (opcional)
