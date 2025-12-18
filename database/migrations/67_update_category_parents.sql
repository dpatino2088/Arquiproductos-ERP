-- ====================================================
-- Migration 67: Update Category Parents
-- ====================================================
-- Este script actualiza los parent_category_id de las categorías
-- basándose en sus códigos para establecer la jerarquía correcta
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
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Actualizando padres de categorías';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Obtener IDs de las categorías padre
  -- ====================================================
  RAISE NOTICE '📋 Obteniendo IDs de categorías padre...';
  
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
    RAISE NOTICE '   ✅ Components (COMP) ID: %', comp_parent_id;
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
    RAISE NOTICE '   ✅ Accessories (ACC) ID: %', acc_parent_id;
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
    RAISE NOTICE '   ✅ Drives & Controls (MOTOR) ID: %', motor_parent_id;
  END IF;

  -- Fabric (FABRIC o FAB) - buscar solo si es grupo/padre
  SELECT id INTO fab_parent_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND (code = 'FABRIC' OR code = 'FAB')
    AND is_group = true  -- Solo buscar si es grupo/padre
    AND deleted = false
  LIMIT 1;
  
  -- Si no hay grupo FAB, buscar si hay una categoría FABRIC que podamos usar como padre
  -- pero solo si no existe como grupo
  IF fab_parent_id IS NULL THEN
    SELECT id INTO fab_parent_id
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND code = 'FABRIC'
      AND deleted = false
    LIMIT 1;
  END IF;
  
  IF fab_parent_id IS NULL THEN
    RAISE WARNING '   ⚠️  Fabric (FABRIC/FAB) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Fabric (FABRIC/FAB) ID: %', fab_parent_id;
  END IF;

  -- Tubo and Profile (COMP-TUBO-PROFILE) - padre intermedio
  SELECT id INTO tubo_profile_id
  FROM public."ItemCategories"
  WHERE organization_id = target_org_id
    AND code = 'COMP-TUBO-PROFILE'
    AND deleted = false
  LIMIT 1;
  
  IF tubo_profile_id IS NULL THEN
    RAISE WARNING '   ⚠️  Tubo and Profile (COMP-TUBO-PROFILE) no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Tubo and Profile (COMP-TUBO-PROFILE) ID: %', tubo_profile_id;
  END IF;

  -- ====================================================
  -- STEP 2: LIMPIEZA AGRESIVA - Resetear TODOS los parent_category_id
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🧹 LIMPIEZA AGRESIVA: Reseteando TODOS los parent_category_id...';
  
  -- LIMPIAR ABSOLUTAMENTE TODOS los parent_category_id de TODAS las categorías
  -- sin excepciones (excepto las que están deleted)
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND deleted = false
    AND parent_category_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ LIMPIEZA COMPLETA: Reseteados % parent_category_id', updated_count;
  ELSE
    RAISE NOTICE '   ✅ No había parent_category_id que limpiar';
  END IF;
  
  RAISE NOTICE '   ℹ️  Todas las categorías ahora tienen parent_category_id = NULL';
  RAISE NOTICE '   ℹ️  Empezando desde cero...';

  -- ====================================================
  -- STEP 3: Actualizar categorías de Components
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando categorías de Components...';
  
  IF comp_parent_id IS NOT NULL THEN
    -- Tubo and Profile debe tener Components como padre
    IF tubo_profile_id IS NOT NULL THEN
      UPDATE public."ItemCategories"
      SET parent_category_id = comp_parent_id,
          updated_at = NOW()
      WHERE organization_id = target_org_id
        AND id = tubo_profile_id
        AND (parent_category_id IS NULL OR parent_category_id != comp_parent_id);
      
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      IF updated_count > 0 THEN
        RAISE NOTICE '   ✅ Tubo and Profile actualizado';
      END IF;
    END IF;

    -- Brackets debe tener Components como padre (hijo directo)
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND code = 'COMP-BRACKET'
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != comp_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Brackets actualizado';
    END IF;
  END IF;

  -- Categorías hijas de Tubo and Profile
  IF tubo_profile_id IS NOT NULL THEN
    -- Cassette
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'COMP-CASSETTE' OR LOWER(name) = 'cassette')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != tubo_profile_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Cassette actualizado';
    END IF;

    -- Side Channel
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'COMP-SIDE' OR LOWER(name) = 'side channel')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != tubo_profile_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Side Channel actualizado';
    END IF;

    -- Bottom Bar
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'COMP-BOTTOM' OR LOWER(name) = 'bottom bar')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != tubo_profile_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Bottom Bar actualizado';
    END IF;

    -- Tube
    UPDATE public."ItemCategories"
    SET parent_category_id = tubo_profile_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'COMP-TUBE' OR LOWER(name) = 'tube')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != tubo_profile_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tube actualizado';
    END IF;
  END IF;

  -- Categorías adicionales de Components
  IF comp_parent_id IS NOT NULL THEN
    -- Chains (probablemente hijo de Components)
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (LOWER(name) = 'chains' OR LOWER(name) = 'chain' OR code LIKE 'COMP-CHAIN%' OR code LIKE 'CHAIN%')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != comp_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Chains actualizado';
    END IF;

    -- Hardware (probablemente hijo de Components)
    UPDATE public."ItemCategories"
    SET parent_category_id = comp_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (LOWER(name) = 'hardware' OR code LIKE 'COMP-HARDWARE%' OR code LIKE 'HARDWARE%')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != comp_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Hardware actualizado';
    END IF;
  END IF;

  -- ====================================================
  -- STEP 4: Actualizar categorías de Accessories
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando categorías de Accessories...';
  
  IF acc_parent_id IS NOT NULL THEN
    -- Accessories (si existe como categoría hoja, debe tener ACC como padre)
    -- IMPORTANTE: No actualizar si es la misma categoría (evitar self-parent)
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND LOWER(name) = 'accessories'
      AND is_group = false
      AND deleted = false
      AND id != acc_parent_id  -- CRÍTICO: No actualizar si es la misma categoría
      AND (parent_category_id IS NULL OR parent_category_id != acc_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Accessories actualizado';
    END IF;

    -- Batteries
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'ACC-BATTERY' OR LOWER(name) = 'batteries')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != acc_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Batteries actualizado';
    END IF;

    -- Remotes
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'ACC-REMOTE' OR LOWER(name) = 'remotes')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != acc_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Remotes actualizado';
    END IF;

    -- Sensors
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'ACC-SENSOR' OR LOWER(name) = 'sensors')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != acc_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Sensors actualizado';
    END IF;

    -- Tool (probablemente hijo de Accessories)
    UPDATE public."ItemCategories"
    SET parent_category_id = acc_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (LOWER(name) = 'tool' OR LOWER(name) = 'tools' OR code LIKE 'ACC-TOOL%' OR code LIKE 'TOOL%')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != acc_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Tool actualizado';
    END IF;
  END IF;

  -- ====================================================
  -- STEP 5: Actualizar categorías de Drives & Controls (MOTOR)
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando categorías de Drives & Controls...';
  
  IF motor_parent_id IS NOT NULL THEN
    -- Manual Drives
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'MOTOR-MANUAL' OR LOWER(name) = 'manual drives')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != motor_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Manual Drives actualizado';
    END IF;

    -- Motorized Drives
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'MOTOR-MOTORIZED' OR LOWER(name) = 'motorized drives')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != motor_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Motorized Drives actualizado';
    END IF;

    -- Controls
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'MOTOR-CONTROL' OR LOWER(name) = 'controls')
      AND deleted = false
      AND (parent_category_id IS NULL OR parent_category_id != motor_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Controls actualizado';
    END IF;

    -- Motors (si existe como categoría hoja, debe tener MOTOR como padre)
    -- IMPORTANTE: No actualizar si es la misma categoría (evitar self-parent)
    UPDATE public."ItemCategories"
    SET parent_category_id = motor_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND LOWER(name) = 'motors'
      AND is_group = false
      AND deleted = false
      AND id != motor_parent_id  -- CRÍTICO: No actualizar si es la misma categoría
      AND (parent_category_id IS NULL OR parent_category_id != motor_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Motors actualizado';
    END IF;
  END IF;

  -- ====================================================
  -- STEP 6: Actualizar categorías de Fabrics
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando categorías de Fabrics...';
  
  IF fab_parent_id IS NOT NULL THEN
    -- Fabric (si existe como categoría hoja diferente, debe tener FAB como padre)
    -- IMPORTANTE: No actualizar si es la misma categoría (evitar self-parent)
    UPDATE public."ItemCategories"
    SET parent_category_id = fab_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (LOWER(name) = 'fabric' OR LOWER(name) = 'fabrics')
      AND is_group = false
      AND deleted = false
      AND id != fab_parent_id  -- CRÍTICO: No actualizar si es la misma categoría
      AND (parent_category_id IS NULL OR parent_category_id != fab_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fabric/Fabrics actualizado';
    END IF;

    -- Window Film
    UPDATE public."ItemCategories"
    SET parent_category_id = fab_parent_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND (code = 'WINDOW-FILM' OR LOWER(name) = 'window film')
      AND deleted = false
      AND id != fab_parent_id  -- Asegurar que no sea la misma categoría
      AND (parent_category_id IS NULL OR parent_category_id != fab_parent_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Window Film actualizado';
    END IF;
  END IF;

  -- ====================================================
  -- STEP 7: Actualizar categoría Servicio (independiente o hijo)
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando categoría Servicio...';
  
  -- Servicio puede ser una categoría independiente (sin padre) o hijo de Accessories
  -- Por ahora la dejamos sin padre (independiente)
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND (LOWER(name) = 'servicio' OR LOWER(name) = 'service' OR code LIKE 'SERVICE%' OR code LIKE 'SERVICIO%')
    AND deleted = false
    AND parent_category_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ Servicio actualizado (sin padre - independiente)';
  END IF;

  -- ====================================================
  -- STEP 8: Asegurar que las categorías padre NO tengan parent_category_id
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Limpiando parent_category_id de categorías padre...';
  
  UPDATE public."ItemCategories"
  SET parent_category_id = NULL,
      updated_at = NOW()
  WHERE organization_id = target_org_id
    AND is_group = true
    AND parent_category_id IS NOT NULL
    AND deleted = false;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ % categorías padre limpiadas', updated_count;
  ELSE
    RAISE NOTICE '   ✅ Todas las categorías padre ya están limpias';
  END IF;

  -- ====================================================
  -- STEP 9: Resumen final
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Actualización completada';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen de jerarquía:';
  
  DECLARE
    cat_count integer;
    cat_name text;
    cat_code text;
    cat_parent text;
  BEGIN
    -- Mostrar estructura de Components
    RAISE NOTICE '';
    RAISE NOTICE 'Components (COMP):';
    FOR cat_count IN
      SELECT COUNT(*) FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND code LIKE 'COMP%'
        AND deleted = false
    LOOP
      RAISE NOTICE '   Total categorías COMP: %', cat_count;
    END LOOP;
    
    -- Mostrar estructura de Accessories
    RAISE NOTICE '';
    RAISE NOTICE 'Accessories (ACC):';
    FOR cat_count IN
      SELECT COUNT(*) FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND code LIKE 'ACC%'
        AND deleted = false
    LOOP
      RAISE NOTICE '   Total categorías ACC: %', cat_count;
    END LOOP;
    
    -- Mostrar estructura de Drives & Controls
    RAISE NOTICE '';
    RAISE NOTICE 'Drives & Controls (MOTOR):';
    FOR cat_count IN
      SELECT COUNT(*) FROM public."ItemCategories"
      WHERE organization_id = target_org_id
        AND code LIKE 'MOTOR%'
        AND deleted = false
    LOOP
      RAISE NOTICE '   Total categorías MOTOR: %', cat_count;
    END LOOP;
  END;

  RAISE NOTICE '';
  RAISE NOTICE '📋 Para ver la estructura completa, ejecuta:';
  RAISE NOTICE '   SELECT name, code, is_group,';
  RAISE NOTICE '          (SELECT name FROM "ItemCategories" p WHERE p.id = c.parent_category_id) as parent';
  RAISE NOTICE '   FROM "ItemCategories" c';
  RAISE NOTICE '   WHERE organization_id = ''%'' AND deleted = false', target_org_id;
  RAISE NOTICE '   ORDER BY code, sort_order;';
  RAISE NOTICE '';

END $$;

-- Query para verificar la estructura final
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
ORDER BY 
  code,
  is_group DESC,
  parent_category_id NULLS FIRST,
  sort_order,
  name;

