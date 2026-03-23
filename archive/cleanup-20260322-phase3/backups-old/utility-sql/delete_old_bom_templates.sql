/**
 * DELETE físico de BOM Templates viejos (V3)
 * 
 * ADVERTENCIA: Esto eliminará físicamente los templates.
 * Solo ejecutar si NO hay BOMInstances activos dependiendo de ellos.
 */

BEGIN;

DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_templates_to_delete text[] := ARRAY[
    'ROLLER_MANUAL_M', 'ROLLER_MANUAL_DOBLE_M', 'ROLLER_MOTORIZADA_M', 
    'ROLLER_MOTORIZADA_DOBLE_M', 'MOTORIZADA_SENCILLA_L', 'MOTORIZADA_DOBLE_L',
    'DOBLE_SHADE_MOTORIZADA', 'TRIPLE_SHADE', 'TRIPLE_SHADE_DOBLE',
    'PA_O_FIJO_RIPPLE_Y_PLEAT', 'RIEL_MANUAL_RIPPLE', 'RIEL_MANUAL_PLEAT',
    'RIEL_MOTORIZADO_RIPPLE', 'RIEL_MOTORIZADO_PLEAT', 'DOBLE_SHADE'
  ];
  v_template_ids uuid[];
  v_active_instances_count integer;
BEGIN

-- 1. Obtener IDs de templates a borrar
SELECT ARRAY_AGG(id) INTO v_template_ids
FROM public."BOMTemplates"
WHERE organization_id = v_org
  AND code = ANY(v_templates_to_delete);

IF v_template_ids IS NULL OR array_length(v_template_ids, 1) = 0 THEN
  RAISE NOTICE 'No templates found to delete';
  RETURN;
END IF;

RAISE NOTICE 'Found % templates to delete', array_length(v_template_ids, 1);

-- 2. Verificar si hay BOMInstances (activos o no)
SELECT COUNT(*) INTO v_active_instances_count
FROM public."BOMInstances"
WHERE bom_template_id = ANY(v_template_ids);

IF v_active_instances_count > 0 THEN
  RAISE NOTICE 'Found % BOMInstances depending on these templates', v_active_instances_count;
  RAISE NOTICE 'Deleting BOMInstanceLines first...';
  
  -- DELETE BOMInstanceLines (CASCADE from BOMInstances)
  DELETE FROM public."BOMInstanceLines"
  WHERE bom_instance_id IN (
    SELECT id FROM public."BOMInstances" 
    WHERE bom_template_id = ANY(v_template_ids)
  );
  
  RAISE NOTICE 'Deleting BOMInstances...';
  
  -- DELETE BOMInstances físicamente
  DELETE FROM public."BOMInstances"
  WHERE bom_template_id = ANY(v_template_ids);
  
  RAISE NOTICE 'Deleted % BOMInstances', v_active_instances_count;
END IF;

-- 3. DELETE BOMComponents
DELETE FROM public."BOMComponents"
WHERE bom_template_id = ANY(v_template_ids);

RAISE NOTICE 'Deleted BOMComponents';

-- 4. DELETE BOMTemplateSlots (si existen)
DELETE FROM public."BOMTemplateSlots"
WHERE bom_template_id = ANY(v_template_ids);

RAISE NOTICE 'Deleted BOMTemplateSlots';

-- 5. DELETE BOMTemplates (ahora sin FK bloqueando)
DELETE FROM public."BOMTemplates"
WHERE id = ANY(v_template_ids);

RAISE NOTICE 'Deleted % BOMTemplates', array_length(v_template_ids, 1);
RAISE NOTICE 'Templates deleted successfully. Ready to run bom_templates_v4_padre_hijo.sql';

END;
$$;

COMMIT;

-- Verificar que se borraron
SELECT 
  'Templates remaining' as status,
  COUNT(*) as count
FROM public."BOMTemplates"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND code IN (
    'ROLLER_MANUAL_M', 'ROLLER_MANUAL_DOBLE_M', 'ROLLER_MOTORIZADA_M', 
    'ROLLER_MOTORIZADA_DOBLE_M', 'MOTORIZADA_SENCILLA_L', 'MOTORIZADA_DOBLE_L',
    'DOBLE_SHADE_MOTORIZADA', 'TRIPLE_SHADE', 'TRIPLE_SHADE_DOBLE',
    'PA_O_FIJO_RIPPLE_Y_PLEAT', 'RIEL_MANUAL_RIPPLE', 'RIEL_MANUAL_PLEAT',
    'RIEL_MOTORIZADO_RIPPLE', 'RIEL_MOTORIZADO_PLEAT', 'DOBLE_SHADE'
  );

-- Esperado: count = 0
