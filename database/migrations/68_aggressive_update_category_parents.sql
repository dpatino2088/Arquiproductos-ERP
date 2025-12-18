-- ====================================================
-- Migration 68: AGGRESSIVE Update Category Parents
-- ====================================================
-- Este script hace una limpieza completa y agresiva:
-- 1. Limpia TODOS los parent_category_id
-- 2. Maneja duplicados (actualiza solo el primero de cada código)
-- 3. Establece las relaciones correctas usando IDs específicos
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
  total_cleaned integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'LIMPIEZA AGRESIVA Y ACTUALIZACIÓN DE PADRES';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Obtener IDs de las categorías padre (solo el primero de cada código)
  -- ====================================================
  RAISE NOTICE '📋 Obteniendo IDs de categorías padre (sin duplicados)...';
  
  -- Components (COMP) - solo el primero
  SELECT id INTO comp_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'COMP'
    AND is_group = true
    AND deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF comp_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Components (COMP) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Components (COMP) ID: %', comp_parent_id;
  END IF;

  -- Accessories (ACC) - solo el primero
  SELECT id INTO acc_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'ACC'
    AND is_group = true
    AND deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF acc_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Accessories (ACC) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Accessories (ACC) ID: %', acc_parent_id;
  END IF;

  -- Drives & Controls (MOTOR) - solo el primero
  SELECT id INTO motor_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'MOTOR'
    AND is_group = true
    AND deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF motor_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Drives & Controls (MOTOR) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Drives & Controls (MOTOR) ID: %', motor_parent_id;
  END IF;

  -- Fabric (FABRIC) - buscar primero como grupo, luego cualquier FABRIC
  SELECT id INTO fab_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'FABRIC'
    AND is_group = true
    AND deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF fab_parent_id IS NULL THEN
    SELECT id INTO fab_parent_id
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND code = 'FABRIC'
      AND deleted = false
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;
  
  IF fab_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Fabric (FABRIC) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Fabric (FABRIC) ID: %', fab_parent_id;
  END IF;

  -- Tubo and Profile (COMP-TUBO-PROFILE) - solo el primero
  SELECT id INTO tubo_profile_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'COMP-TUBO-PROFILE'
    AND deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF tubo_profile_id IS NULL THEN
    RAISE WARNING '   ⚠️  Tubo and Profile (COMP-TUBO-PROFILE) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Tubo and Profile (COMP-TUBO-PROFILE) ID: %', tubo_profile_id;
  END IF;

  -- ====================================================
  -- STEP 2: LIMPIEZA TOTAL - Resetear TODOS los parent_category_id
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🧹 LIMPIEZA TOTAL: Reseteando TODOS los parent_category_id...';
  
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND deleted = false;
  
  GET DIAGNOSTICS total_cleaned = ROW_COUNT;
  RAISE NOTICE '   ✅ LIMPIEZA COMPLETA: Reseteados % parent_category_id', total_cleaned;
  RAISE NOTICE '   ℹ️  Todas las categorías ahora tienen parent_category_id = NULL';
  RAISE NOTICE '   ℹ️  Empezando desde cero...';

  -- ====================================================
  -- STEP 3: Establecer relaciones usando IDs específicos (evitar duplicados)
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Estableciendo relaciones padre-hijo...';
  
  -- 3.1: Tubo and Profile → Components
  IF comp_parent_id IS NOT NULL AND tubo_profile_id IS NOT NULL THEN
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE id = tubo_profile_id;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tubo and Profile → Components';
    END IF;
  END IF;

  -- 3.2: Hijos de Components (usando DISTINCT ON para evitar duplicados)
  IF comp_parent_id IS NOT NULL THEN
    -- Brackets (solo el primero de cada código)
    UPDATE public."ItemCategories" ci
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND code = 'COMP-BRACKET'
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_bracket
    WHERE ci.id = first_bracket.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Brackets → Components (% registros)', updated_count;
    END IF;

    -- Chains (solo el primero)
    UPDATE public."ItemCategories" ci
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (LOWER(name) = 'chains' OR LOWER(name) = 'chain' OR code LIKE 'COMP-CHAIN%' OR code LIKE 'CHAIN%')
        AND deleted = false
      ORDER BY code, created_at ASC
      LIMIT 1
    ) first_chain
    WHERE ci.id = first_chain.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Chains → Components';
    END IF;

    -- Hardware (solo el primero)
    UPDATE public."ItemCategories" ci
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (LOWER(name) = 'hardware' OR code LIKE 'COMP-HARDWARE%' OR code LIKE 'HARDWARE%')
        AND deleted = false
      ORDER BY code, created_at ASC
      LIMIT 1
    ) first_hardware
    WHERE ci.id = first_hardware.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Hardware → Components';
    END IF;
  END IF;

  -- 3.3: Hijos de Tubo and Profile (solo el primero de cada código)
  IF tubo_profile_id IS NOT NULL THEN
    -- Cassette
    UPDATE public."ItemCategories" ci
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'COMP-CASSETTE' OR LOWER(name) = 'cassette')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_cassette
    WHERE ci.id = first_cassette.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Cassette → Tubo and Profile (% registros)', updated_count;
    END IF;

    -- Side Channel
    UPDATE public."ItemCategories" ci
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'COMP-SIDE' OR LOWER(name) = 'side channel')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_side
    WHERE ci.id = first_side.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Side Channel → Tubo and Profile (% registros)', updated_count;
    END IF;

    -- Bottom Bar
    UPDATE public."ItemCategories" ci
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'COMP-BOTTOM' OR LOWER(name) = 'bottom bar')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_bottom
    WHERE ci.id = first_bottom.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Bottom Bar → Tubo and Profile (% registros)', updated_count;
    END IF;

    -- Tube
    UPDATE public."ItemCategories" ci
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'COMP-TUBE' OR LOWER(name) = 'tube')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_tube
    WHERE ci.id = first_tube.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tube → Tubo and Profile (% registros)', updated_count;
    END IF;
  END IF;

  -- 3.4: Hijos de Accessories (solo el primero de cada código)
  IF acc_parent_id IS NOT NULL THEN
    -- Batteries
    UPDATE public."ItemCategories" ci
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'ACC-BATTERY' OR LOWER(name) = 'batteries')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_battery
    WHERE ci.id = first_battery.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Batteries → Accessories';
    END IF;

    -- Remotes
    UPDATE public."ItemCategories" ci
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'ACC-REMOTE' OR LOWER(name) = 'remotes')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_remote
    WHERE ci.id = first_remote.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Remotes → Accessories';
    END IF;

    -- Sensors
    UPDATE public."ItemCategories" ci
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'ACC-SENSOR' OR LOWER(name) = 'sensors')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_sensor
    WHERE ci.id = first_sensor.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Sensors → Accessories';
    END IF;

    -- Tool
    UPDATE public."ItemCategories" ci
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (LOWER(name) = 'tool' OR LOWER(name) = 'tools' OR code LIKE 'ACC-TOOL%' OR code LIKE 'TOOL%')
        AND deleted = false
      ORDER BY code, created_at ASC
      LIMIT 1
    ) first_tool
    WHERE ci.id = first_tool.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tool → Accessories';
    END IF;
  END IF;

  -- 3.5: Hijos de Drives & Controls (solo el primero de cada código)
  IF motor_parent_id IS NOT NULL THEN
    -- Manual Drives
    UPDATE public."ItemCategories" ci
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'MOTOR-MANUAL' OR LOWER(name) = 'manual drives')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_manual
    WHERE ci.id = first_manual.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Manual Drives → Drives & Controls';
    END IF;

    -- Motorized Drives
    UPDATE public."ItemCategories" ci
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'MOTOR-MOTORIZED' OR LOWER(name) = 'motorized drives')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_motorized
    WHERE ci.id = first_motorized.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Motorized Drives → Drives & Controls';
    END IF;

    -- Controls
    UPDATE public."ItemCategories" ci
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'MOTOR-CONTROL' OR LOWER(name) = 'controls')
        AND deleted = false
      ORDER BY code, created_at ASC
    ) first_control
    WHERE ci.id = first_control.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Controls → Drives & Controls';
    END IF;
  END IF;

  -- 3.6: Hijos de Fabric (solo el primero de cada código)
  IF fab_parent_id IS NOT NULL THEN
    -- Window Film
    UPDATE public."ItemCategories" ci
    SET parent_category_id = fab_parent_id,
        updated_at = NOW()
    FROM (
      SELECT DISTINCT ON (code) id
      FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND (code = 'WINDOW-FILM' OR LOWER(name) = 'window film')
        AND deleted = false
        AND id != fab_parent_id  -- Evitar self-parent
      ORDER BY code, created_at ASC
    ) first_window_film
    WHERE ci.id = first_window_film.id
      AND ci.parent_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Window Film → Fabric';
    END IF;
  END IF;

  -- 3.7: Servicio (sin padre - independiente)
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND (LOWER(name) = 'servicio' OR LOWER(name) = 'service' OR code LIKE 'SERVICE%' OR code LIKE 'SERVICIO%')
    AND deleted = false
    AND parent_category_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ Servicio (sin padre - independiente)';
  END IF;

  -- ====================================================
  -- STEP 4: Asegurar que las categorías padre principales NO tengan parent_category_id
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Limpiando parent_category_id de categorías padre principales...';
  
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND is_group = true
    AND code IN ('COMP', 'ACC', 'MOTOR', 'FABRIC', 'FAB')
    AND deleted = false
    AND parent_category_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ % categorías padre principales limpiadas', updated_count;
  END IF;

  -- ====================================================
  -- STEP 5: Resumen final
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ ACTUALIZACIÓN COMPLETA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen:';
  RAISE NOTICE '   - Limpiados: % parent_category_id', total_cleaned;
  RAISE NOTICE '   - Relaciones establecidas correctamente';
  RAISE NOTICE '   - Duplicados manejados (solo el primero de cada código)';
  RAISE NOTICE '';

END $$;

-- Query para verificar la estructura final (sin duplicados)
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
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND id IN (
    SELECT DISTINCT ON (code) id
    FROM public."ItemCategories"
    WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
      AND deleted = false
    ORDER BY code, created_at ASC
  )
ORDER BY 
  code,
  is_group DESC,
  parent_category_id NULLS FIRST,
  sort_order,
  name;

