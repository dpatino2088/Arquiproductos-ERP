/**
 * RESET COMPLETO Y LIMPIO DEL SISTEMA BOM
 * 
 * Ejecuta esto para empezar de cero con el sistema PADRE-HIJO correcto
 * 
 * Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
 */

BEGIN;

DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_deleted_slots integer := 0;
  v_deleted_children integer := 0;
BEGIN

RAISE NOTICE '========================================';
RAISE NOTICE 'RESET BOM SYSTEM - STARTING';
RAISE NOTICE '========================================';

-- 1. Borrar todos los slots existentes
DELETE FROM public."BOMTemplateSlots"
WHERE organization_id = v_org;

GET DIAGNOSTICS v_deleted_slots = ROW_COUNT;
RAISE NOTICE 'Deleted % BOMTemplateSlots', v_deleted_slots;

-- 2. Borrar todos los children existentes
DELETE FROM public."CatalogItemComponents"
WHERE organization_id = v_org;

GET DIAGNOSTICS v_deleted_children = ROW_COUNT;
RAISE NOTICE 'Deleted % CatalogItemComponents', v_deleted_children;

-- 3. NO borrar BOMComponents - los usaremos como referencia para migrar

RAISE NOTICE '========================================';
RAISE NOTICE 'RESET COMPLETE';
RAISE NOTICE 'Next: Run populate script';
RAISE NOTICE '========================================';

END;
$$;

COMMIT;

-- Verificación
SELECT 
  'BOMTemplateSlots' as table_name,
  COUNT(*) as count
FROM public."BOMTemplateSlots"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
UNION ALL
SELECT 
  'CatalogItemComponents' as table_name,
  COUNT(*) as count
FROM public."CatalogItemComponents"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
UNION ALL
SELECT 
  'BOMTemplates' as table_name,
  COUNT(*) as count
FROM public."BOMTemplates"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND deleted = false
UNION ALL
SELECT 
  'BOMComponents' as table_name,
  COUNT(*) as count
FROM public."BOMComponents"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND deleted = false;
