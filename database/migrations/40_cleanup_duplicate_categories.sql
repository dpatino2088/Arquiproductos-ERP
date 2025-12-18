-- ====================================================
-- Script de Limpieza: Eliminar Duplicados y Reorganizar
-- ====================================================
-- Limpia duplicados y reorganiza Components con:
-- - Components (padre)
--   - Tubo and Profile (padre intermedio)
--     - Tube, Cassette, Bottom Bar, Side Channel
--   - Brackets (hijo directo)
-- ====================================================

DO $$
DECLARE
  org_rec RECORD;
  comp_parent_id uuid;
  tubo_profile_parent_id uuid;
  motor_parent_id uuid;
  acc_parent_id uuid;
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Limpieza de duplicados y reorganización';
  RAISE NOTICE '====================================================';

  FOR org_rec IN 
    SELECT DISTINCT id as organization_id 
    FROM public."Organizations" 
    WHERE deleted = false
    -- O usar ID específico:
    -- SELECT '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
  LOOP
    RAISE NOTICE 'Procesando organización: %', org_rec.organization_id;

    -- Paso 1: Obtener IDs de categorías padre correctas
    SELECT id INTO comp_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'COMP' 
      AND is_group = true 
      AND deleted = false 
    ORDER BY created_at ASC
    LIMIT 1;

    IF comp_parent_id IS NULL THEN
      RAISE NOTICE '⚠️  Components no encontrado, saltando organización: %', org_rec.organization_id;
      CONTINUE;
    END IF;

    -- Paso 2: Marcar como deleted TODAS las categorías existentes (soft delete)
    UPDATE public."ItemCategories"
    SET deleted = true
    WHERE organization_id = org_rec.organization_id
      AND deleted = false;

    RAISE NOTICE '✅ Todas las categorías marcadas como deleted';

    -- Paso 3: Crear categorías hoja (Fabric, Window Film)
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Fabric', 'FABRIC', false, NULL, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Window Film', 'WINDOW-FILM', false, NULL, 2, false, false, NOW(), NOW());

    -- Paso 4: Recrear Components
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Components', 'COMP', true, NULL, 3, false, false, NOW(), NOW()
    ) RETURNING id INTO comp_parent_id;

    -- Paso 5: Recrear Drives & Controls
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Drives & Controls', 'MOTOR', true, NULL, 4, false, false, NOW(), NOW()
    );

    -- Paso 6: Recrear Accessories
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Accessories', 'ACC', true, NULL, 5, false, false, NOW(), NOW()
    );

    -- Paso 7: Crear "Tubo and Profile" como padre intermedio bajo Components
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Tubo and Profile', 'COMP-TUBO-PROFILE', true, comp_parent_id, 1, false, false, NOW(), NOW()
    ) RETURNING id INTO tubo_profile_parent_id;

    -- Paso 8: Crear subcategorías de "Tubo and Profile"
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Tube', 'COMP-TUBE', false, tubo_profile_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Cassette', 'COMP-CASSETTE', false, tubo_profile_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Bottom Bar', 'COMP-BOTTOM', false, tubo_profile_parent_id, 3, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Side Channel', 'COMP-SIDE', false, tubo_profile_parent_id, 4, false, false, NOW(), NOW());

    -- Paso 9: Crear Brackets como hijo directo de Components
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Brackets', 'COMP-BRACKET', false, comp_parent_id, 2, false, false, NOW(), NOW()
    );

    -- Paso 10: Obtener IDs de padres para subcategorías
    SELECT id INTO motor_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'MOTOR' 
      AND is_group = true 
      AND deleted = false 
    LIMIT 1;

    SELECT id INTO acc_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'ACC' 
      AND is_group = true 
      AND deleted = false 
    LIMIT 1;

    -- Paso 11: Crear subcategorías de Drives & Controls
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Manual Drives', 'MOTOR-MANUAL', false, motor_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Motorized Drives', 'MOTOR-MOTORIZED', false, motor_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Controls', 'MOTOR-CONTROL', false, motor_parent_id, 3, false, false, NOW(), NOW());

    -- Paso 12: Crear subcategorías de Accessories
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Remotes', 'ACC-REMOTE', false, acc_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Batteries', 'ACC-BATTERY', false, acc_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Sensors', 'ACC-SENSOR', false, acc_parent_id, 3, false, false, NOW(), NOW());

    RAISE NOTICE '✅ Categorías recreadas correctamente para organización: %', org_rec.organization_id;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ LIMPIEZA Y REORGANIZACIÓN COMPLETA';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Estructura final:';
  RAISE NOTICE '   - Fabric (hoja)';
  RAISE NOTICE '   - Window Film (hoja)';
  RAISE NOTICE '   - Components (padre)';
  RAISE NOTICE '     └─ Tubo and Profile (padre intermedio)';
  RAISE NOTICE '         ├─ Tube';
  RAISE NOTICE '         ├─ Cassette';
  RAISE NOTICE '         ├─ Bottom Bar';
  RAISE NOTICE '         └─ Side Channel';
  RAISE NOTICE '     └─ Brackets (hijo directo)';
  RAISE NOTICE '   - Drives & Controls (padre) → 3 hijos';
  RAISE NOTICE '   - Accessories (padre) → 3 hijos';
  RAISE NOTICE '';
END $$;

-- Verificar resultado
SELECT 
  CASE 
    WHEN is_group = true THEN '📁 ' || name || ' (Padre)'
    WHEN parent_category_id IS NULL THEN '📄 ' || name || ' (Hoja)'
    ELSE '  └─ ' || name || ' (Hijo)'
  END as estructura,
  code,
  is_group,
  (SELECT name FROM public."ItemCategories" p WHERE p.id = c.parent_category_id) as parent_name
FROM public."ItemCategories" c
WHERE deleted = false
ORDER BY 
  is_group DESC,
  parent_category_id NULLS FIRST,
  sort_order,
  name;

