-- ====================================================
-- Script de Limpieza ULTIMATE: Eliminar Duplicados con Constraint
-- ====================================================
-- Elimina TODOS los duplicados y agrega constraint único
-- para prevenir futuros duplicados
-- ====================================================

DO $$
DECLARE
  org_rec RECORD;
  comp_parent_id uuid;
  tubo_profile_parent_id uuid;
  motor_parent_id uuid;
  acc_parent_id uuid;
  duplicate_count integer;
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Limpieza ULTIMATE: Eliminar TODOS los duplicados';
  RAISE NOTICE '====================================================';

  FOR org_rec IN 
    SELECT DISTINCT id as organization_id 
    FROM public."Organizations" 
    WHERE deleted = false
    -- O usar ID específico:
    -- SELECT '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
  LOOP
    RAISE NOTICE 'Procesando organización: %', org_rec.organization_id;

    -- Paso 1: Eliminar TODAS las categorías de esta organización
    -- Primero, actualizar referencias en CatalogItems para evitar FK errors
    UPDATE public."CatalogItems"
    SET item_category_id = NULL
    WHERE organization_id = org_rec.organization_id
      AND item_category_id IN (
        SELECT id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id
      );

    -- Eliminar todas las categorías
    DELETE FROM public."ItemCategories"
    WHERE organization_id = org_rec.organization_id;

    RAISE NOTICE '✅ Todas las categorías eliminadas (recreando desde cero)';

    -- Paso 2: Crear categorías hoja (Fabric, Window Film)
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Fabric', 'FABRIC', false, NULL, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Window Film', 'WINDOW-FILM', false, NULL, 2, false, false, NOW(), NOW());

    RAISE NOTICE '✅ Categorías hoja creadas';

    -- Paso 3: Crear Components (padre)
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Components', 'COMP', true, NULL, 3, false, false, NOW(), NOW()
    ) RETURNING id INTO comp_parent_id;

    -- Paso 4: Crear "Tubo and Profile" como padre intermedio bajo Components
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Tubo and Profile', 'COMP-TUBO-PROFILE', true, comp_parent_id, 1, false, false, NOW(), NOW()
    ) RETURNING id INTO tubo_profile_parent_id;

    -- Paso 5: Crear subcategorías de "Tubo and Profile" (UNA SOLA VEZ)
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Tube', 'COMP-TUBE', false, tubo_profile_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Cassette', 'COMP-CASSETTE', false, tubo_profile_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Bottom Bar', 'COMP-BOTTOM', false, tubo_profile_parent_id, 3, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Side Channel', 'COMP-SIDE', false, tubo_profile_parent_id, 4, false, false, NOW(), NOW());

    -- Paso 6: Crear Brackets como hijo directo de Components
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Brackets', 'COMP-BRACKET', false, comp_parent_id, 2, false, false, NOW(), NOW()
    );

    RAISE NOTICE '✅ Components y subcategorías creadas';

    -- Paso 7: Crear Drives & Controls (padre)
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Drives & Controls', 'MOTOR', true, NULL, 4, false, false, NOW(), NOW()
    ) RETURNING id INTO motor_parent_id;

    -- Paso 8: Crear subcategorías de Drives & Controls
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Manual Drives', 'MOTOR-MANUAL', false, motor_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Motorized Drives', 'MOTOR-MOTORIZED', false, motor_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Controls', 'MOTOR-CONTROL', false, motor_parent_id, 3, false, false, NOW(), NOW());

    RAISE NOTICE '✅ Drives & Controls y subcategorías creadas';

    -- Paso 9: Crear Accessories (padre)
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Accessories', 'ACC', true, NULL, 5, false, false, NOW(), NOW()
    ) RETURNING id INTO acc_parent_id;

    -- Paso 10: Crear subcategorías de Accessories
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Remotes', 'ACC-REMOTE', false, acc_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Batteries', 'ACC-BATTERY', false, acc_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Sensors', 'ACC-SENSOR', false, acc_parent_id, 3, false, false, NOW(), NOW());

    RAISE NOTICE '✅ Accessories y subcategorías creadas';

    RAISE NOTICE '✅ Todas las categorías recreadas correctamente para organización: %', org_rec.organization_id;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Agregando constraint único para prevenir duplicados';
  RAISE NOTICE '====================================================';

  -- Paso 11: Agregar constraint único en (organization_id, code) para prevenir duplicados
  -- Primero eliminar constraint si existe
  ALTER TABLE public."ItemCategories" 
    DROP CONSTRAINT IF EXISTS unique_itemcategory_org_code;

  -- Crear constraint único
  ALTER TABLE public."ItemCategories"
    ADD CONSTRAINT unique_itemcategory_org_code 
    UNIQUE (organization_id, code);

  RAISE NOTICE '✅ Constraint único agregado: (organization_id, code)';

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ LIMPIEZA ULTIMATE COMPLETA';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
END $$;

-- Verificar que NO hay duplicados
SELECT 
  'Verificación de duplicados' as check_type,
  code,
  COUNT(*) as count,
  STRING_AGG(id::text, ', ') as ids
FROM public."ItemCategories"
WHERE deleted = false
GROUP BY code, organization_id
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- Si la query anterior no devuelve resultados, significa que no hay duplicados ✅

-- Verificar estructura final completa
SELECT 
  CASE 
    WHEN is_group = true THEN '📁 ' || name || ' (Padre)'
    WHEN parent_category_id IS NULL THEN '📄 ' || name || ' (Hoja)'
    ELSE '  └─ ' || name || ' (Hijo)'
  END as estructura,
  code,
  is_group,
  (SELECT name FROM public."ItemCategories" p WHERE p.id = c.parent_category_id) as parent_name,
  created_at
FROM public."ItemCategories" c
WHERE deleted = false
ORDER BY 
  is_group DESC,
  parent_category_id NULLS FIRST,
  sort_order,
  name;

-- Contar total de categorías activas por organización
SELECT 
  organization_id,
  COUNT(*) as total_count
FROM public."ItemCategories"
WHERE deleted = false
GROUP BY organization_id
ORDER BY organization_id;













