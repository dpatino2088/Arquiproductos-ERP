-- ====================================================
-- Migration 73: Recrear TODAS las Categorías desde Cero
-- ====================================================
-- Este script crea todas las categorías con las relaciones correctas
-- Úsalo DESPUÉS de borrar manualmente las categorías
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  comp_parent_id uuid;
  acc_parent_id uuid;
  motor_parent_id uuid;
  fab_parent_id uuid;
  tubo_profile_id uuid;
  created_id uuid;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RECREANDO CATEGORÍAS DESDE CERO';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Crear Categorías Padre Principales
  -- ====================================================
  RAISE NOTICE 'PASO 1: Creando categorías padre principales...';
  
  -- Components (COMP)
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Components', 'COMP', true, 1, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO comp_parent_id;
  
  IF comp_parent_id IS NULL THEN
    SELECT id INTO comp_parent_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP' AND deleted = false LIMIT 1;
  END IF;
  RAISE NOTICE '   ✅ Components (ID: %)', comp_parent_id;

  -- Accessories (ACC)
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Accessories', 'ACC', true, 2, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO acc_parent_id;
  
  IF acc_parent_id IS NULL THEN
    SELECT id INTO acc_parent_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC' AND deleted = false LIMIT 1;
  END IF;
  RAISE NOTICE '   ✅ Accessories (ID: %)', acc_parent_id;

  -- Drives & Controls (MOTOR)
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Drives & Controls', 'MOTOR', true, 3, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO motor_parent_id;
  
  IF motor_parent_id IS NULL THEN
    SELECT id INTO motor_parent_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR' AND deleted = false LIMIT 1;
  END IF;
  RAISE NOTICE '   ✅ Drives & Controls (ID: %)', motor_parent_id;

  -- Fabric (FABRIC) - categoría hoja, sin hijos
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Fabric', 'FABRIC', false, NULL, 4, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO fab_parent_id;
  
  IF fab_parent_id IS NULL THEN
    SELECT id INTO fab_parent_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'FABRIC' AND deleted = false LIMIT 1;
  END IF;
  RAISE NOTICE '   ✅ Fabric (categoría hoja, sin hijos) (ID: %)', fab_parent_id;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Crear Tubo and Profile (padre intermedio)
  -- ====================================================
  RAISE NOTICE 'PASO 2: Creando Tubo and Profile...';
  
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Tubo and Profile', 'COMP-TUBO-PROFILE', true, comp_parent_id, 1, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO tubo_profile_id;
  
  IF tubo_profile_id IS NULL THEN
    SELECT id INTO tubo_profile_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-TUBO-PROFILE' AND deleted = false LIMIT 1;
  END IF;
  RAISE NOTICE '   ✅ Tubo and Profile → Components (ID: %)', tubo_profile_id;
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 3: Crear Hijos de Components
  -- ====================================================
  RAISE NOTICE 'PASO 3: Creando hijos de Components...';
  
  -- Brackets
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Brackets', 'COMP-BRACKET', false, comp_parent_id, 1, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Brackets → Components';

  -- Chains
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Chains', 'COMP-CHAIN', false, comp_parent_id, 2, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Chains → Components';

  -- Hardware
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Hardware', 'COMP-HARDWARE', false, comp_parent_id, 3, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Hardware → Components';

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 4: Crear Hijos de Tubo and Profile
  -- ====================================================
  RAISE NOTICE 'PASO 4: Creando hijos de Tubo and Profile...';
  
  -- Cassette
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Cassette', 'COMP-CASSETTE', false, tubo_profile_id, 1, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Cassette → Tubo and Profile';

  -- Side Channel
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Side Channel', 'COMP-SIDE', false, tubo_profile_id, 2, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Side Channel → Tubo and Profile';

  -- Bottom Bar
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Bottom Bar', 'COMP-BOTTOM', false, tubo_profile_id, 3, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Bottom Bar → Tubo and Profile';

  -- Tube
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Tube', 'COMP-TUBE', false, tubo_profile_id, 4, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Tube → Tubo and Profile';

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 5: Crear Hijos de Accessories
  -- ====================================================
  RAISE NOTICE 'PASO 5: Creando hijos de Accessories...';
  
  -- Batteries
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Batteries', 'ACC-BATTERY', false, acc_parent_id, 1, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Batteries → Accessories';

  -- Remotes
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Remotes', 'ACC-REMOTE', false, acc_parent_id, 2, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Remotes → Accessories';

  -- Sensors
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Sensors', 'ACC-SENSOR', false, acc_parent_id, 3, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Sensors → Accessories';

  -- Tool
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Tool', 'ACC-TOOL', false, acc_parent_id, 4, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Tool → Accessories';

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 6: Crear Hijos de Drives & Controls
  -- ====================================================
  RAISE NOTICE 'PASO 6: Creando hijos de Drives & Controls...';
  
  -- Manual Drives
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Manual Drives', 'MOTOR-MANUAL', false, motor_parent_id, 1, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Manual Drives → Drives & Controls';

  -- Motorized Drives
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Motorized Drives', 'MOTOR-MOTORIZED', false, motor_parent_id, 2, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Motorized Drives → Drives & Controls';

  -- Controls
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Controls', 'MOTOR-CONTROL', false, motor_parent_id, 3, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Controls → Drives & Controls';

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 7: Crear Window Film (categoría hoja independiente)
  -- ====================================================
  RAISE NOTICE 'PASO 7: Creando Window Film (categoría hoja independiente)...';
  
  -- Window Film (sin padre, categoría hoja independiente)
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Window Film', 'WINDOW-FILM', false, NULL, 5, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Window Film (categoría hoja, sin padre)';

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 8: Crear Servicio (sin padre)
  -- ====================================================
  RAISE NOTICE 'PASO 8: Creando Servicio (independiente)...';
  
  INSERT INTO public."ItemCategories" (
    organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
  )
  VALUES (
    target_org_id, 'Servicio', 'SERVICE', false, NULL, 6, false, false, NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;
  RAISE NOTICE '   ✅ Servicio (sin padre)';

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 9: Actualizar CatalogItems con nuevos IDs (si tienen item_category_id)
  -- ====================================================
  RAISE NOTICE 'PASO 9: Verificando CatalogItems...';
  
  DECLARE
    items_with_category integer;
    items_without_category integer;
  BEGIN
    -- Contar items con categoría
    SELECT COUNT(*) INTO items_with_category
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NOT NULL;
    
    -- Contar items sin categoría
    SELECT COUNT(*) INTO items_without_category
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL;
    
    RAISE NOTICE '   ℹ️  CatalogItems con item_category_id: %', items_with_category;
    RAISE NOTICE '   ℹ️  CatalogItems sin item_category_id: %', items_without_category;
    RAISE NOTICE '   ⚠️  NOTA: Los CatalogItems con item_category_id inválido necesitarán actualizarse manualmente';
    RAISE NOTICE '   ℹ️  Puedes actualizarlos después usando el nombre o código de la categoría';
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ CATEGORÍAS RECREADAS EXITOSAMENTE';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Estructura creada:';
  RAISE NOTICE '   Components (padre)';
  RAISE NOTICE '     ├─ Tubo and Profile (padre intermedio)';
  RAISE NOTICE '     │   ├─ Cassette';
  RAISE NOTICE '     │   ├─ Side Channel';
  RAISE NOTICE '     │   ├─ Bottom Bar';
  RAISE NOTICE '     │   └─ Tube';
  RAISE NOTICE '     ├─ Brackets';
  RAISE NOTICE '     ├─ Chains';
  RAISE NOTICE '     └─ Hardware';
  RAISE NOTICE '   Accessories (padre)';
  RAISE NOTICE '     ├─ Batteries';
  RAISE NOTICE '     ├─ Remotes';
  RAISE NOTICE '     ├─ Sensors';
  RAISE NOTICE '     └─ Tool';
  RAISE NOTICE '   Drives & Controls (padre)';
  RAISE NOTICE '     ├─ Manual Drives';
  RAISE NOTICE '     ├─ Motorized Drives';
  RAISE NOTICE '     └─ Controls';
  RAISE NOTICE '   Fabric (categoría hoja, sin hijos)';
  RAISE NOTICE '   Window Film (categoría hoja, sin padre)';
  RAISE NOTICE '   Servicio (independiente)';
  RAISE NOTICE '';

END $$;

-- Query de verificación final
SELECT 
  name,
  code,
  CASE 
    WHEN parent_category_id IS NULL THEN 'NULL (Padre/Hoja)'
    ELSE (SELECT name FROM public."ItemCategories" p WHERE p.id = c.parent_category_id)
  END as parent_name,
  is_group,
  deleted
FROM public."ItemCategories" c
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
ORDER BY 
  code,
  name;

