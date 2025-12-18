-- ====================================================
-- Migration: Update Category Structure - Tubo and Profile
-- ====================================================
-- Reorganiza Components para tener:
-- - Components (padre)
--   - Tubo and Profile (padre intermedio, is_group=true)
--     - Tube (hijo)
--     - Cassette (hijo)
--     - Bottom Bar (hijo)
--     - Side Channel (hijo)
--   - Brackets (hijo directo de Components)
-- ====================================================

DO $$
DECLARE
  org_rec RECORD;
  comp_parent_id uuid;
  tubo_profile_parent_id uuid;
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Actualizando estructura: Tubo and Profile';
  RAISE NOTICE '====================================================';

  FOR org_rec IN 
    SELECT DISTINCT id as organization_id 
    FROM public."Organizations" 
    WHERE deleted = false
    -- O usar ID específico:
    -- SELECT '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
  LOOP
    -- Obtener ID de Components
    SELECT id INTO comp_parent_id 
    FROM public."ItemCategories" 
    WHERE organization_id = org_rec.organization_id 
      AND code = 'COMP' 
      AND is_group = true 
      AND deleted = false 
    LIMIT 1;

    IF comp_parent_id IS NULL THEN
      RAISE NOTICE '⚠️  Components no encontrado para organización: %', org_rec.organization_id;
      CONTINUE;
    END IF;

    RAISE NOTICE 'Components ID: %', comp_parent_id;

    -- Paso 1: Marcar como deleted las subcategorías actuales que serán reorganizadas
    UPDATE public."ItemCategories"
    SET deleted = true
    WHERE organization_id = org_rec.organization_id
      AND parent_category_id = comp_parent_id
      AND code IN ('COMP-TUBE', 'COMP-BOTTOM', 'COMP-SIDE')
      AND deleted = false;

    RAISE NOTICE '✅ Subcategorías antiguas marcadas como deleted';

    -- Paso 2: Crear "Tubo and Profile" como categoría padre intermedia
    INSERT INTO public."ItemCategories" (
      organization_id,
      name,
      code,
      is_group,
      parent_category_id,
      sort_order,
      deleted,
      archived,
      created_at,
      updated_at
    )
    SELECT
      org_rec.organization_id,
      'Tubo and Profile',
      'COMP-TUBO-PROFILE',
      true,  -- ES grupo/padre
      comp_parent_id,  -- Padre es Components
      1,
      false,
      false,
      NOW(),
      NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-TUBO-PROFILE' 
        AND deleted = false
    )
    RETURNING id INTO tubo_profile_parent_id;

    -- Si ya existe, obtener su ID
    IF tubo_profile_parent_id IS NULL THEN
      SELECT id INTO tubo_profile_parent_id 
      FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-TUBO-PROFILE' 
        AND deleted = false 
      LIMIT 1;
    END IF;

    RAISE NOTICE '✅ Creado/Verificado "Tubo and Profile" (ID: %)', tubo_profile_parent_id;

    -- Paso 3: Crear subcategorías de "Tubo and Profile"
    INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) 
    SELECT org_rec.organization_id, 'Tube', 'COMP-TUBE', false, tubo_profile_parent_id, 1, false, false, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-TUBE' 
        AND deleted = false
    );

    INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) 
    SELECT org_rec.organization_id, 'Cassette', 'COMP-CASSETTE', false, tubo_profile_parent_id, 2, false, false, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-CASSETTE' 
        AND deleted = false
    );

    INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) 
    SELECT org_rec.organization_id, 'Bottom Bar', 'COMP-BOTTOM', false, tubo_profile_parent_id, 3, false, false, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-BOTTOM' 
        AND deleted = false
    );

    INSERT INTO public."ItemCategories" (organization_id, name, code, is_group, parent_category_id, sort_order, deleted, archived, created_at, updated_at) 
    SELECT org_rec.organization_id, 'Side Channel', 'COMP-SIDE', false, tubo_profile_parent_id, 4, false, false, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-SIDE' 
        AND deleted = false
    );

    RAISE NOTICE '✅ Creadas subcategorías de Tubo and Profile';

    -- Paso 4: Verificar que Brackets existe como hijo directo de Components
    -- Si no existe, crearlo
    INSERT INTO public."ItemCategories" (
      organization_id,
      name,
      code,
      is_group,
      parent_category_id,
      sort_order,
      deleted,
      archived,
      created_at,
      updated_at
    )
    SELECT 
      org_rec.organization_id,
      'Brackets',
      'COMP-BRACKET',
      false,
      comp_parent_id,
      2,  -- Después de Tubo and Profile
      false,
      false,
      NOW(),
      NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP-BRACKET' 
        AND deleted = false
    );

    RAISE NOTICE '✅ Brackets verificado/creado como hijo directo de Components';
    RAISE NOTICE '✅ Estructura actualizada para organización: %', org_rec.organization_id;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Estructura actualizada';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Nueva estructura:';
  RAISE NOTICE '   Components (padre)';
  RAISE NOTICE '     └─ Tubo and Profile (padre intermedio)';
  RAISE NOTICE '         ├─ Tube';
  RAISE NOTICE '         ├─ Cassette';
  RAISE NOTICE '         ├─ Bottom Bar';
  RAISE NOTICE '         └─ Side Channel';
  RAISE NOTICE '     └─ Brackets (hijo directo)';
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
  AND (
    code = 'COMP' OR
    code LIKE 'COMP-%'
  )
ORDER BY 
  is_group DESC,
  parent_category_id NULLS FIRST,
  sort_order,
  name;
