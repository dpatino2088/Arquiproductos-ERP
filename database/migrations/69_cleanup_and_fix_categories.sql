-- ====================================================
-- Migration 69: Cleanup Duplicates and Fix Category Parents
-- ====================================================
-- PASO A PASO:
-- 1. Marcar duplicados como deleted (mantener solo el primero de cada código)
-- 2. Limpiar TODOS los parent_category_id
-- 3. Establecer relaciones correctas desde cero
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  comp_parent_id uuid;
  acc_parent_id uuid;
  motor_parent_id uuid;
  fab_parent_id uuid;
  tubo_profile_id uuid;
  updated_count integer;
  deleted_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'LIMPIEZA COMPLETA Y REESTABLECIMIENTO';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: ELIMINAR DUPLICADOS (marcar como deleted)
  -- ====================================================
  RAISE NOTICE 'PASO 1: Eliminando duplicados...';
  RAISE NOTICE '   (Manteniendo solo el primer registro de cada código)';
  
  -- Marcar como deleted todos los duplicados (excepto el primero de cada código)
  WITH duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY code ORDER BY created_at ASC) as rn
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND code IS NOT NULL
      AND trim(code) <> ''
  )
  UPDATE public."ItemCategories" ic
  SET deleted = true,
      updated_at = NOW()
  FROM duplicates d
  WHERE ic.id = d.id
    AND d.rn > 1;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Marcados como deleted: % duplicados', deleted_count;
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Obtener IDs de categorías padre (solo las que NO están deleted)
  -- ====================================================
  RAISE NOTICE 'PASO 2: Obteniendo IDs de categorías padre...';
  
  -- Components (COMP)
  SELECT id INTO comp_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'COMP'
    AND is_group = true
    AND deleted = false
  LIMIT 1;
  
  IF comp_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Components (COMP) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Components ID: %', comp_parent_id;
  END IF;

  -- Accessories (ACC)
  SELECT id INTO acc_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'ACC'
    AND is_group = true
    AND deleted = false
  LIMIT 1;
  
  IF acc_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Accessories (ACC) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Accessories ID: %', acc_parent_id;
  END IF;

  -- Drives & Controls (MOTOR)
  SELECT id INTO motor_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'MOTOR'
    AND is_group = true
    AND deleted = false
  LIMIT 1;
  
  IF motor_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Drives & Controls (MOTOR) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Drives & Controls ID: %', motor_parent_id;
  END IF;

  -- Fabric (FABRIC)
  SELECT id INTO fab_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'FABRIC'
    AND deleted = false
  ORDER BY is_group DESC, created_at ASC
  LIMIT 1;
  
  IF fab_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Fabric (FABRIC) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Fabric ID: %', fab_parent_id;
  END IF;

  -- Tubo and Profile
  SELECT id INTO tubo_profile_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'COMP-TUBO-PROFILE'
    AND deleted = false
  LIMIT 1;
  
  IF tubo_profile_id IS NULL THEN
    RAISE WARNING '   ⚠️  Tubo and Profile no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Tubo and Profile ID: %', tubo_profile_id;
  END IF;
  
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 3: LIMPIAR TODOS los parent_category_id
  -- ====================================================
  RAISE NOTICE 'PASO 3: Limpiando TODOS los parent_category_id...';
  
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND deleted = false;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Limpiados % parent_category_id', updated_count;
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 4: Establecer relaciones padre-hijo
  -- ====================================================
  RAISE NOTICE 'PASO 4: Estableciendo relaciones padre-hijo...';
  
  -- 4.1: Tubo and Profile → Components
  IF comp_parent_id IS NOT NULL AND tubo_profile_id IS NOT NULL THEN
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE id = tubo_profile_id;
    RAISE NOTICE '   ✅ Tubo and Profile → Components';
  END IF;

  -- 4.2: Hijos de Components
  IF comp_parent_id IS NOT NULL THEN
    -- Brackets
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'COMP-BRACKET'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Brackets → Components';
    END IF;

    -- Chains
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE id IN (
      SELECT id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (LOWER(name) = 'chains' OR LOWER(name) = 'chain' OR code LIKE '%CHAIN%')
        AND deleted = false
        AND parent_category_id IS NULL
      LIMIT 1
    );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Chains → Components';
    END IF;

    -- Hardware
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE id IN (
      SELECT id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (LOWER(name) = 'hardware' OR code LIKE '%HARDWARE%')
        AND deleted = false
        AND parent_category_id IS NULL
      LIMIT 1
    );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Hardware → Components';
    END IF;
  END IF;

  -- 4.3: Hijos de Tubo and Profile
  IF tubo_profile_id IS NOT NULL THEN
    -- Cassette
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'COMP-CASSETTE'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Cassette → Tubo and Profile';
    END IF;

    -- Side Channel
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'COMP-SIDE'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Side Channel → Tubo and Profile';
    END IF;

    -- Bottom Bar
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'COMP-BOTTOM'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Bottom Bar → Tubo and Profile';
    END IF;

    -- Tube
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'COMP-TUBE'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tube → Tubo and Profile';
    END IF;
  END IF;

  -- 4.4: Hijos de Accessories
  IF acc_parent_id IS NOT NULL THEN
    -- Batteries
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'ACC-BATTERY'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Batteries → Accessories';
    END IF;

    -- Remotes
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'ACC-REMOTE'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Remotes → Accessories';
    END IF;

    -- Sensors
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'ACC-SENSOR'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Sensors → Accessories';
    END IF;

    -- Tool
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE id IN (
      SELECT id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (LOWER(name) = 'tool' OR LOWER(name) = 'tools' OR code LIKE '%TOOL%')
        AND deleted = false
        AND parent_category_id IS NULL
      LIMIT 1
    );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tool → Accessories';
    END IF;
  END IF;

  -- 4.5: Hijos de Drives & Controls
  IF motor_parent_id IS NOT NULL THEN
    -- Manual Drives
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'MOTOR-MANUAL'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Manual Drives → Drives & Controls';
    END IF;

    -- Motorized Drives
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'MOTOR-MOTORIZED'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Motorized Drives → Drives & Controls';
    END IF;

    -- Controls
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'MOTOR-CONTROL'
      AND deleted = false
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Controls → Drives & Controls';
    END IF;
  END IF;

  -- 4.6: Hijos de Fabric
  IF fab_parent_id IS NOT NULL THEN
    -- Window Film
    UPDATE public."ItemCategories"
    SET parent_category_id = fab_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'WINDOW-FILM'
      AND deleted = false
      AND id != fab_parent_id  -- Evitar self-parent
      AND parent_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Window Film → Fabric';
    END IF;
  END IF;

  -- 4.7: Servicio (sin padre)
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND (LOWER(name) = 'servicio' OR LOWER(name) = 'service' OR code LIKE '%SERVICE%')
    AND deleted = false
    AND parent_category_id IS NOT NULL;
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ Servicio (sin padre)';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 5: Asegurar que categorías padre principales NO tengan padre
  -- ====================================================
  RAISE NOTICE 'PASO 5: Limpiando parent_category_id de categorías padre principales...';
  
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND code IN ('COMP', 'ACC', 'MOTOR', 'FABRIC', 'FAB')
    AND is_group = true
    AND deleted = false
    AND parent_category_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ Limpiados % categorías padre principales', updated_count;
  END IF;

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ PROCESO COMPLETADO';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen:';
  RAISE NOTICE '   - Duplicados eliminados: %', deleted_count;
  RAISE NOTICE '   - Relaciones establecidas correctamente';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Verifica los resultados ejecutando:';
  RAISE NOTICE '   SELECT name, code, parent_category_id, deleted';
  RAISE NOTICE '   FROM "ItemCategories"';
  RAISE NOTICE '   WHERE organization_id = ''%''', target_org_id;
  RAISE NOTICE '   AND deleted = false';
  RAISE NOTICE '   ORDER BY code, name;';
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
  deleted
FROM public."ItemCategories" c
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
ORDER BY 
  deleted ASC,
  code,
  name;

