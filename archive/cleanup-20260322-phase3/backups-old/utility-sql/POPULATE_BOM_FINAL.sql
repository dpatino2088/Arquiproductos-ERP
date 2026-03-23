/**
 * POBLACIÓN FINAL Y LIMPIA DE BOM TEMPLATES (PADRE-HIJO)
 * 
 * Este script puebla BOMTemplateSlots basándose en BOMComponents existentes
 * Solo para templates que NO tienen slots aún
 * 
 * Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
 */

BEGIN;

DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_template RECORD;
  v_comp RECORD;
  v_slot_count integer := 0;
  v_padres_roles text[] := ARRAY[
    'motor', 'drive', 'bracket', 'tube', 'bottom_bar', 'headbox', 
    'track', 'carrier', 'belt', 'wand', 'bottom_rail', 'side_channel'
  ];
BEGIN

RAISE NOTICE '========================================';
RAISE NOTICE 'POBLACIÓN FINAL BOM TEMPLATES';
RAISE NOTICE '========================================';

-- Iterar sobre cada template que NO tiene slots
FOR v_template IN 
  SELECT bt.*
  FROM public."BOMTemplates" bt
  WHERE bt.organization_id = v_org 
    AND bt.deleted = false
    AND NOT EXISTS (
      SELECT 1 FROM public."BOMTemplateSlots" bts
      WHERE bts.bom_template_id = bt.id
    )
  ORDER BY bt.code
LOOP
  RAISE NOTICE '';
  RAISE NOTICE 'Template: % (%)', v_template.code, v_template.name;
  
  -- Buscar componentes PADRES de este template
  FOR v_comp IN
    SELECT DISTINCT ON (bc.component_role)
      bc.*
    FROM public."BOMComponents" bc
    WHERE bc.organization_id = v_org
      AND bc.bom_template_id = v_template.id
      AND bc.deleted = false
      AND bc.archived = false
      AND LOWER(TRIM(bc.component_role)) = ANY(v_padres_roles)
    ORDER BY bc.component_role, bc.sort_order ASC
  LOOP
    -- Crear slot para este rol PADRE
    INSERT INTO public."BOMTemplateSlots" (
      organization_id,
      bom_template_id,
      item_role,
      required,
      catalog_item_id,
      qty,
      notes
    ) VALUES (
      v_org,
      v_template.id,
      LOWER(TRIM(v_comp.component_role)),
      true,
      v_comp.component_item_id, -- NULL si usuario debe elegir
      COALESCE(v_comp.qty_value, 1),
      CASE 
        WHEN v_comp.component_item_id IS NOT NULL 
        THEN 'Fixed SKU: ' || (SELECT sku FROM public."CatalogItems" WHERE id = v_comp.component_item_id LIMIT 1)
        ELSE 'User selection required'
      END
    )
    ON CONFLICT DO NOTHING;
    
    v_slot_count := v_slot_count + 1;
    
    RAISE NOTICE '  → % (SKU: %)', 
      LOWER(TRIM(v_comp.component_role)),
      CASE 
        WHEN v_comp.component_item_id IS NOT NULL 
        THEN (SELECT sku FROM public."CatalogItems" WHERE id = v_comp.component_item_id LIMIT 1)
        ELSE 'user choice'
      END;
  END LOOP;
  
END LOOP;

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'POBLACIÓN COMPLETADA';
RAISE NOTICE '- Total slots creados: %', v_slot_count;
RAISE NOTICE '========================================';

END;
$$;

COMMIT;

-- ============================================================================
-- VERIFICACIÓN: Ver templates con sus slots
-- ============================================================================

SELECT 
  bt.code as template_code,
  bt.name as template_name,
  COUNT(DISTINCT bts.id) as slots_count,
  STRING_AGG(
    CONCAT(
      bts.item_role,
      CASE WHEN bts.catalog_item_id IS NOT NULL 
        THEN ' [' || COALESCE((SELECT sku FROM public."CatalogItems" WHERE id = bts.catalog_item_id LIMIT 1), 'N/A') || ']'
        ELSE ' [user choice]'
      END
    ),
    ', '
    ORDER BY bts.item_role
  ) as slots_detail
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
GROUP BY bt.id, bt.code, bt.name
ORDER BY bt.code;

-- Verificar si hay templates sin slots
SELECT 
  code,
  name,
  'NO SLOTS' as status
FROM public."BOMTemplates" bt
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM public."BOMTemplateSlots" bts
    WHERE bts.bom_template_id = bt.id
  );
