-- ====================================================
-- Migration: Normalize BOM Template (Roller Shade)
-- ====================================================
-- Objetivos:
-- 1) Normalizar roles a snake_case
-- 2) Eliminar duplicados auto-select
-- 3) Convertir UOM ft -> m
-- 4) Ajustar category_code por mapeo de role
-- 5) Re-categorizar componentes mal categorizados
-- ====================================================

DO $$
DECLARE
  v_template_id uuid;
  v_updated_count int := 0;
  v_deleted_count int := 0;
BEGIN
  -- 0) Localizar template único activo (roller shade o el más reciente)
  -- ✅ FIX: Usar solo columnas que existen en ProductTypes (name, code)
  SELECT bt.id INTO v_template_id
  FROM "BOMTemplates" bt
  LEFT JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
  WHERE bt.deleted = false
    AND bt.active = true
    AND (
      pt.code ILIKE '%roller%' 
      OR pt.name ILIKE '%roller%'
      OR (pt.code IS NULL AND pt.name IS NULL) -- Si no hay ProductType, buscar por nombre del template
      OR bt.name ILIKE '%roller%'
    )
  ORDER BY bt.created_at DESC
  LIMIT 1;
  
  -- Si no se encuentra, usar el más reciente activo
  IF v_template_id IS NULL THEN
    SELECT id INTO v_template_id
    FROM "BOMTemplates"
    WHERE deleted = false
      AND active = true
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;
  
  -- Si aún no hay template, salir
  IF v_template_id IS NULL THEN
    RAISE NOTICE '⚠️  No se encontró ningún BOM Template activo. Saltando normalización.';
    RETURN;
  END IF;
  
  RAISE NOTICE '✅ Normalizando BOM Template: %', v_template_id;
  
  -- 1) Normalizar component_role a snake_case
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BOMComponents'
      AND column_name = 'component_role'
  ) THEN
    UPDATE "BOMComponents"
    SET 
      component_role = lower(regexp_replace(component_role, '\s+', '_', 'g')),
      updated_at = now()
    WHERE bom_template_id = v_template_id
      AND deleted = false
      AND component_role IS NOT NULL
      AND component_role != lower(regexp_replace(component_role, '\s+', '_', 'g'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Normalizados % roles a snake_case', v_updated_count;
  END IF;
  
  -- 2) Eliminar duplicado drive_manual auto-select (mantener el más antiguo)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BOMComponents'
      AND column_name = 'auto_select'
  ) THEN
    WITH duplicates AS (
      SELECT id,
             row_number() OVER (ORDER BY created_at ASC, id ASC) AS rn
      FROM "BOMComponents"
      WHERE bom_template_id = v_template_id
        AND deleted = false
        AND component_role = 'drive_manual'
        AND (auto_select = true OR component_item_id IS NULL)
    )
    UPDATE "BOMComponents"
    SET 
      deleted = true,
      updated_at = now()
    WHERE id IN (SELECT id FROM duplicates WHERE rn > 1);
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Eliminados % componentes drive_manual duplicados', v_deleted_count;
  END IF;
  
  -- 3) Ajustar category_code por mapeo de role (si existe la columna)
  -- NOTA: category_code no existe en BOMComponents, se calcula en tiempo de generación del BOM
  -- Esta sección se omite porque category_code se mapea en generate_bom_for_manufacturing_order
  
  -- 4) Re-categorizar componentes del "Tube" que tienen role hardware pero deberían ser tube
  -- Buscar por nombre del item o SKU relacionado
  -- ✅ FIX: Solo actualizar component_role, no category_code (que no existe en BOMComponents)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BOMComponents'
      AND column_name = 'component_item_id'
  ) THEN
    UPDATE "BOMComponents" bc
    SET 
      component_role = CASE
        WHEN bc.component_role = 'hardware' AND ci.item_name ILIKE '%tube%' THEN 'tube'
        WHEN bc.component_role = 'hardware' AND ci.item_name ILIKE '%mount%' THEN 'tube'
        WHEN bc.component_role = 'hardware' AND ci.item_name ILIKE '%adapter%' THEN 'tube'
        ELSE bc.component_role
      END,
      updated_at = now()
    FROM "CatalogItems" ci
    WHERE bc.bom_template_id = v_template_id
      AND bc.deleted = false
      AND bc.component_item_id = ci.id
      AND bc.component_role = 'hardware'
      AND (ci.item_name ILIKE '%tube%' 
           OR ci.item_name ILIKE '%mount%' 
           OR ci.item_name ILIKE '%adapter%'
           OR ci.sku ILIKE '%tube%'
           OR ci.sku ILIKE '%mount%'
           OR ci.sku ILIKE '%adapter%');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '✅ Re-categorizados % componentes de hardware a tube (actualizado component_role)', v_updated_count;
    END IF;
  END IF;
  
  -- 5) Convertir UOM ft -> m (solo cambiar uom, no qty porque qty_type puede ser per_width)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BOMComponents'
      AND column_name = 'uom'
  ) THEN
    UPDATE "BOMComponents"
    SET 
      uom = 'm',
      updated_at = now()
    WHERE bom_template_id = v_template_id
      AND deleted = false
      AND uom = 'ft';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '✅ Convertidos % UOM de ft a m', v_updated_count;
    END IF;
  END IF;
  
  RAISE NOTICE '✅ Normalización completada para template: %', v_template_id;
  
END $$;

-- ====================================================
-- Query de validación post-migración
-- ====================================================
-- Ejecutar manualmente para verificar resultados:
-- NOTA: category_code no existe en BOMComponents, se calcula en tiempo de generación del BOM
/*
SELECT
  component_role,
  uom,
  auto_select,
  component_item_id IS NOT NULL as is_fixed,
  count(*) as cnt
FROM "BOMComponents"
WHERE bom_template_id = (
  SELECT id FROM "BOMTemplates"
  WHERE deleted = false AND active = true
  ORDER BY created_at DESC LIMIT 1
)
AND deleted = false
GROUP BY component_role, uom, auto_select, component_item_id IS NOT NULL
ORDER BY component_role, auto_select DESC, is_fixed DESC;
*/

