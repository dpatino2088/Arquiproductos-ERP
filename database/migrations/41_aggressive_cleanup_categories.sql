-- ====================================================
-- Script de Limpieza Agresiva: Eliminar Duplicados
-- ====================================================
-- Elimina físicamente las categorías marcadas como deleted
-- y reorganiza Components con la estructura correcta
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
  RAISE NOTICE 'Limpieza agresiva de duplicados';
  RAISE NOTICE '====================================================';

  FOR org_rec IN 
    SELECT DISTINCT id as organization_id 
    FROM public."Organizations" 
    WHERE deleted = false
    -- O usar ID específico:
    -- SELECT '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
  LOOP
    RAISE NOTICE 'Procesando organización: %', org_rec.organization_id;

    -- Paso 1: Eliminar FÍSICAMENTE todas las categorías marcadas como deleted
    DELETE FROM public."ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND deleted = true;

    RAISE NOTICE '✅ Categorías marcadas como deleted eliminadas físicamente';

    -- Paso 1.5: Eliminar duplicados activos (mantener solo la más reciente por código)
    DELETE FROM public."ItemCategories" ic1
    WHERE ic1.organization_id = org_rec.organization_id
      AND ic1.deleted = false
      AND EXISTS (
        SELECT 1 
        FROM public."ItemCategories" ic2 
        WHERE ic2.organization_id = ic1.organization_id
          AND ic2.code = ic1.code
          AND ic2.deleted = false
          AND ic2.id != ic1.id
          AND ic2.created_at > ic1.created_at
      );

    RAISE NOTICE '✅ Duplicados activos eliminados (manteniendo la más reciente por código)';

    -- Paso 2: Obtener o crear Components
    SELECT id INTO comp_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'COMP' 
      AND is_group = true 
      AND deleted = false 
    LIMIT 1;

    IF comp_parent_id IS NULL THEN
      INSERT INTO public."ItemCategories" (
        organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
      ) VALUES (
        org_rec.organization_id, 'Components', 'COMP', true, NULL, 3, false, false, NOW(), NOW()
      ) RETURNING id INTO comp_parent_id;
      RAISE NOTICE '✅ Components creado';
    END IF;

    -- Paso 3: Eliminar todas las subcategorías de Components (para recrearlas)
    DELETE FROM public."ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND parent_category_id = comp_parent_id
      AND deleted = false;

    RAISE NOTICE '✅ Subcategorías de Components eliminadas';

    -- Paso 4: Crear "Tubo and Profile" como padre intermedio
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Tubo and Profile', 'COMP-TUBO-PROFILE', true, comp_parent_id, 1, false, false, NOW(), NOW()
    ) RETURNING id INTO tubo_profile_parent_id;

    RAISE NOTICE '✅ Tubo and Profile creado (ID: %)', tubo_profile_parent_id;

    -- Paso 5: Crear subcategorías de "Tubo and Profile"
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Tube', 'COMP-TUBE', false, tubo_profile_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Cassette', 'COMP-CASSETTE', false, tubo_profile_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Bottom Bar', 'COMP-BOTTOM', false, tubo_profile_parent_id, 3, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Side Channel', 'COMP-SIDE', false, tubo_profile_parent_id, 4, false, false, NOW(), NOW());

    RAISE NOTICE '✅ Subcategorías de Tubo and Profile creadas';

    -- Paso 6: Crear Brackets como hijo directo de Components
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES (
      org_rec.organization_id, 'Brackets', 'COMP-BRACKET', false, comp_parent_id, 2, false, false, NOW(), NOW()
    );

    RAISE NOTICE '✅ Brackets creado';

    -- Paso 7: Verificar/crear otras categorías principales
    -- Fabric
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    )
    SELECT org_rec.organization_id, 'Fabric', 'FABRIC', false, NULL, 1, false, false, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'FABRIC' 
        AND deleted = false
    );

    -- Window Film
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    )
    SELECT org_rec.organization_id, 'Window Film', 'WINDOW-FILM', false, NULL, 2, false, false, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'WINDOW-FILM' 
        AND deleted = false
    );

    -- Drives & Controls
    SELECT id INTO motor_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'MOTOR' 
      AND is_group = true 
      AND deleted = false 
    LIMIT 1;

    IF motor_parent_id IS NULL THEN
      INSERT INTO public."ItemCategories" (
        organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
      ) VALUES (
        org_rec.organization_id, 'Drives & Controls', 'MOTOR', true, NULL, 4, false, false, NOW(), NOW()
      ) RETURNING id INTO motor_parent_id;
    END IF;

    -- Eliminar subcategorías existentes de Drives & Controls
    DELETE FROM public."ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND parent_category_id = motor_parent_id
      AND deleted = false;

    -- Crear subcategorías de Drives & Controls
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Manual Drives', 'MOTOR-MANUAL', false, motor_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Motorized Drives', 'MOTOR-MOTORIZED', false, motor_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Controls', 'MOTOR-CONTROL', false, motor_parent_id, 3, false, false, NOW(), NOW());

    -- Accessories
    SELECT id INTO acc_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'ACC' 
      AND is_group = true 
      AND deleted = false 
    LIMIT 1;

    IF acc_parent_id IS NULL THEN
      INSERT INTO public."ItemCategories" (
        organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
      ) VALUES (
        org_rec.organization_id, 'Accessories', 'ACC', true, NULL, 5, false, false, NOW(), NOW()
      ) RETURNING id INTO acc_parent_id;
    END IF;

    -- Eliminar subcategorías existentes de Accessories
    DELETE FROM public."ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND parent_category_id = acc_parent_id
      AND deleted = false;

    -- Crear subcategorías de Accessories
    INSERT INTO public."ItemCategories" (
      organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at
    ) VALUES
      (org_rec.organization_id, 'Remotes', 'ACC-REMOTE', false, acc_parent_id, 1, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Batteries', 'ACC-BATTERY', false, acc_parent_id, 2, false, false, NOW(), NOW()),
      (org_rec.organization_id, 'Sensors', 'ACC-SENSOR', false, acc_parent_id, 3, false, false, NOW(), NOW());

    RAISE NOTICE '✅ Todas las categorías recreadas correctamente';
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ LIMPIEZA AGRESIVA COMPLETA';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
END $$;

-- Verificar que no hay duplicados
SELECT 
  name,
  code,
  COUNT(*) as count,
  STRING_AGG(id::text, ', ') as ids
FROM public."ItemCategories"
WHERE deleted = false
GROUP BY name, code
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- Verificar estructura final
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

