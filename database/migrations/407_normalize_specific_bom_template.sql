-- ====================================================
-- Migration: Normalizar BOMTemplate Específico
-- ====================================================
-- Template: 184658a6-f6af-4199-bea2-44d29e6a88dc
-- ProductType: 318a8c9a-da17-43c4-925e-4f6dec6c7596
-- ====================================================
-- Objetivos:
-- 1) Normalizar roles a snake_case
-- 2) Convertir UOM ft -> m
-- 3) Eliminar duplicados auto-select por role
-- 4) Eliminar fabric fija del template (viene de QuoteLineComponents)
-- ====================================================

DO $$
DECLARE
  v_template_id uuid := '184658a6-f6af-4199-bea2-44d29e6a88dc'::uuid;
  v_updated_count int := 0;
  v_deleted_count int := 0;
BEGIN
  -- 0) Confirmación rápida del template
  IF NOT EXISTS (
    SELECT 1 FROM "BOMTemplates"
    WHERE id = v_template_id
    AND deleted = false
  ) THEN
    RAISE EXCEPTION 'BOMTemplate % not found or deleted', v_template_id;
  END IF;
  
  RAISE NOTICE '✅ Normalizando BOMTemplate: %', v_template_id;
  
  -- 1) Roles a snake_case
  UPDATE "BOMComponents"
  SET 
    component_role = lower(regexp_replace(component_role, '\s+', '_', 'g')),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role IS NOT NULL
    AND component_role != lower(regexp_replace(component_role, '\s+', '_', 'g'));
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Normalizados % roles a snake_case', v_updated_count;
  END IF;
  
  -- 2) UOM: prohibir ft en template -> convertir a m
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
  
  -- 3) Eliminar duplicados auto-select por (component_role)
  --    (mantiene el más viejo, borra el resto)
  WITH duplicates AS (
    SELECT id,
           row_number() OVER (
             PARTITION BY component_role
             ORDER BY created_at ASC, id ASC
           ) AS rn
    FROM "BOMComponents"
    WHERE bom_template_id = v_template_id
      AND deleted = false
      AND (auto_select = true OR component_item_id IS NULL)
  )
  UPDATE "BOMComponents"
  SET 
    deleted = true,
    updated_at = now()
  WHERE id IN (SELECT id FROM duplicates WHERE rn > 1);
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  IF v_deleted_count > 0 THEN
    RAISE NOTICE '✅ Eliminados % componentes auto-select duplicados', v_deleted_count;
  END IF;
  
  -- 4) EVITAR FABRIC DUPLICADA:
  --    Si el template tiene fabric fija (component_item_id NOT NULL),
  --    se debe eliminar para que la tela venga solo desde QuoteLineComponents
  UPDATE "BOMComponents"
  SET 
    deleted = true,
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'fabric'
    AND component_item_id IS NOT NULL;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  IF v_deleted_count > 0 THEN
    RAISE NOTICE '✅ Eliminadas % componentes fabric fijos del template (vienen de QuoteLineComponents)', v_deleted_count;
  END IF;
  
  -- 5) ✅ FIX: Corregir qty_type y sku_resolution_rule para auto-select components
  --    Asegurar que usen valores válidos del enum bom_qty_type
  --    tube -> qty_type='per_width', sku_resolution_rule='CATEGORY_FIRST_MATCH', uom='m'
  --    fabric -> qty_type='per_area', sku_resolution_rule='CATEGORY_FIRST_MATCH', uom='m2'
  --    end_cap/drive_manual/bracket -> qty_type='fixed', sku_resolution_rule='ROLE_AND_COLOR' (o 'CATEGORY_FIRST_MATCH'), uom='ea'
  
  -- 5A) tube: per_width
  UPDATE "BOMComponents"
  SET 
    qty_type = 'per_width'::bom_qty_type,
    sku_resolution_rule = COALESCE(sku_resolution_rule, 'CATEGORY_FIRST_MATCH'),
    uom = COALESCE(NULLIF(uom, 'ft'), 'm'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'tube'
    AND (auto_select = true OR component_item_id IS NULL)
    AND (qty_type IS NULL OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area'));
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Corregidos % componentes tube: qty_type=per_width', v_updated_count;
  END IF;
  
  -- 5B) fabric: per_area
  UPDATE "BOMComponents"
  SET 
    qty_type = 'per_area'::bom_qty_type,
    sku_resolution_rule = COALESCE(sku_resolution_rule, 'CATEGORY_FIRST_MATCH'),
    uom = COALESCE(NULLIF(uom, 'ft'), 'm2'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role = 'fabric'
    AND (auto_select = true OR component_item_id IS NULL)
    AND (qty_type IS NULL OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area'));
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Corregidos % componentes fabric: qty_type=per_area, uom=m2', v_updated_count;
  END IF;
  
  -- 5C) end_cap, drive_manual, bracket: fixed
  UPDATE "BOMComponents"
  SET 
    qty_type = 'fixed'::bom_qty_type,
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      CASE 
        WHEN sku_resolution_rule IS NULL THEN 'ROLE_AND_COLOR'
        ELSE sku_resolution_rule
      END
    ),
    uom = COALESCE(NULLIF(uom, 'ft'), 'ea'),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND component_role IN ('end_cap', 'drive_manual', 'bracket')
    AND (auto_select = true OR component_item_id IS NULL)
    AND (qty_type IS NULL OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area'));
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Corregidos % componentes (end_cap/drive_manual/bracket): qty_type=fixed', v_updated_count;
  END IF;
  
  -- 5D) Otros roles auto-select: asegurar qty_type válido
  UPDATE "BOMComponents"
  SET 
    qty_type = COALESCE(
      CASE 
        WHEN qty_type::text IN ('fixed', 'per_width', 'per_area') THEN qty_type::bom_qty_type
        ELSE 'fixed'::bom_qty_type
      END,
      'fixed'::bom_qty_type
    ),
    sku_resolution_rule = COALESCE(
      NULLIF(sku_resolution_rule, ''),
      CASE 
        WHEN sku_resolution_rule IS NULL THEN 'CATEGORY_FIRST_MATCH'
        ELSE sku_resolution_rule
      END
    ),
    updated_at = now()
  WHERE bom_template_id = v_template_id
    AND deleted = false
    AND (auto_select = true OR component_item_id IS NULL)
    AND (qty_type IS NULL OR qty_type::text NOT IN ('fixed', 'per_width', 'per_area'));
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Corregidos % componentes auto-select adicionales: qty_type validado', v_updated_count;
  END IF;
  
  RAISE NOTICE '✅ Normalización completada para template: %', v_template_id;
  
END $$;

-- ====================================================
-- Query de Validación Post-Migración
-- ====================================================
SELECT 
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

