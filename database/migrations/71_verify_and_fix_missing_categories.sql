-- ====================================================
-- Migration 71: Verificar y Corregir Categorías Faltantes
-- ====================================================
-- Este script te dice EXACTAMENTE qué falta y qué está bien
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  comp_parent_id uuid;
  acc_parent_id uuid;
  motor_parent_id uuid;
  fab_parent_id uuid;
  tubo_profile_id uuid;
  missing_count integer := 0;
  wrong_parent_count integer := 0;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICACIÓN DE CATEGORÍAS HIJAS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Obtener IDs de padres
  SELECT id INTO comp_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'COMP' AND is_group = true AND deleted = false LIMIT 1;
  
  SELECT id INTO acc_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'ACC' AND is_group = true AND deleted = false LIMIT 1;
  
  SELECT id INTO motor_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'MOTOR' AND is_group = true AND deleted = false LIMIT 1;
  
  SELECT id INTO fab_parent_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'FABRIC' AND deleted = false LIMIT 1;
  
  SELECT id INTO tubo_profile_id FROM public."ItemCategories"
  WHERE organization_id = target_org_id AND code = 'COMP-TUBO-PROFILE' AND deleted = false LIMIT 1;

  -- ====================================================
  -- VERIFICAR CATEGORÍAS REQUERIDAS
  -- ====================================================
  RAISE NOTICE '📋 CATEGORÍAS QUE DEBEN EXISTIR:';
  RAISE NOTICE '';

  -- Components → Brackets
  DECLARE
    brackets_id uuid;
  BEGIN
    SELECT id INTO brackets_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-BRACKET' AND deleted = false LIMIT 1;
    
    IF brackets_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Brackets (COMP-BRACKET)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = brackets_id) != comp_parent_id THEN
      RAISE WARNING '   ⚠️  Brackets tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Brackets → Components (CORRECTO)';
    END IF;
  END;

  -- Components → Chains
  DECLARE
    chains_id uuid;
  BEGIN
    SELECT id INTO chains_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND (code LIKE '%CHAIN%' OR LOWER(name) LIKE '%chain%')
      AND deleted = false
    LIMIT 1;
    
    IF chains_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Chains';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = chains_id) != comp_parent_id THEN
      RAISE WARNING '   ⚠️  Chains tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Chains → Components (CORRECTO)';
    END IF;
  END;

  -- Components → Hardware
  DECLARE
    hardware_id uuid;
  BEGIN
    SELECT id INTO hardware_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND (code LIKE '%HARDWARE%' OR LOWER(name) LIKE '%hardware%')
      AND deleted = false
    LIMIT 1;
    
    IF hardware_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Hardware';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = hardware_id) != comp_parent_id THEN
      RAISE WARNING '   ⚠️  Hardware tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Hardware → Components (CORRECTO)';
    END IF;
  END;

  -- Tubo and Profile → Cassette
  DECLARE
    cassette_id uuid;
  BEGIN
    SELECT id INTO cassette_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-CASSETTE' AND deleted = false LIMIT 1;
    
    IF cassette_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Cassette (COMP-CASSETTE)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = cassette_id) != tubo_profile_id THEN
      RAISE WARNING '   ⚠️  Cassette tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Cassette → Tubo and Profile (CORRECTO)';
    END IF;
  END;

  -- Tubo and Profile → Side Channel
  DECLARE
    side_channel_id uuid;
  BEGIN
    SELECT id INTO side_channel_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-SIDE' AND deleted = false LIMIT 1;
    
    IF side_channel_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Side Channel (COMP-SIDE)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = side_channel_id) != tubo_profile_id THEN
      RAISE WARNING '   ⚠️  Side Channel tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Side Channel → Tubo and Profile (CORRECTO)';
    END IF;
  END;

  -- Tubo and Profile → Bottom Bar
  DECLARE
    bottom_bar_id uuid;
  BEGIN
    SELECT id INTO bottom_bar_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-BOTTOM' AND deleted = false LIMIT 1;
    
    IF bottom_bar_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Bottom Bar (COMP-BOTTOM)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = bottom_bar_id) != tubo_profile_id THEN
      RAISE WARNING '   ⚠️  Bottom Bar tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Bottom Bar → Tubo and Profile (CORRECTO)';
    END IF;
  END;

  -- Tubo and Profile → Tube
  DECLARE
    tube_id uuid;
  BEGIN
    SELECT id INTO tube_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-TUBE' AND deleted = false LIMIT 1;
    
    IF tube_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Tube (COMP-TUBE)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = tube_id) != tubo_profile_id THEN
      RAISE WARNING '   ⚠️  Tube tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Tube → Tubo and Profile (CORRECTO)';
    END IF;
  END;

  -- Accessories → Batteries
  DECLARE
    batteries_id uuid;
  BEGIN
    SELECT id INTO batteries_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-BATTERY' AND deleted = false LIMIT 1;
    
    IF batteries_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Batteries (ACC-BATTERY)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = batteries_id) != acc_parent_id THEN
      RAISE WARNING '   ⚠️  Batteries tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Batteries → Accessories (CORRECTO)';
    END IF;
  END;

  -- Accessories → Remotes
  DECLARE
    remotes_id uuid;
  BEGIN
    SELECT id INTO remotes_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-REMOTE' AND deleted = false LIMIT 1;
    
    IF remotes_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Remotes (ACC-REMOTE)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = remotes_id) != acc_parent_id THEN
      RAISE WARNING '   ⚠️  Remotes tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Remotes → Accessories (CORRECTO)';
    END IF;
  END;

  -- Accessories → Sensors
  DECLARE
    sensors_id uuid;
  BEGIN
    SELECT id INTO sensors_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-SENSOR' AND deleted = false LIMIT 1;
    
    IF sensors_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Sensors (ACC-SENSOR)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = sensors_id) != acc_parent_id THEN
      RAISE WARNING '   ⚠️  Sensors tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Sensors → Accessories (CORRECTO)';
    END IF;
  END;

  -- Accessories → Tool
  DECLARE
    tool_id uuid;
  BEGIN
    SELECT id INTO tool_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND (code LIKE '%TOOL%' OR LOWER(name) LIKE '%tool%')
      AND deleted = false
    LIMIT 1;
    
    IF tool_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Tool';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = tool_id) != acc_parent_id THEN
      RAISE WARNING '   ⚠️  Tool tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Tool → Accessories (CORRECTO)';
    END IF;
  END;

  -- Drives & Controls → Manual Drives
  DECLARE
    manual_drives_id uuid;
  BEGIN
    SELECT id INTO manual_drives_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR-MANUAL' AND deleted = false LIMIT 1;
    
    IF manual_drives_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Manual Drives (MOTOR-MANUAL)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = manual_drives_id) != motor_parent_id THEN
      RAISE WARNING '   ⚠️  Manual Drives tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Manual Drives → Drives & Controls (CORRECTO)';
    END IF;
  END;

  -- Drives & Controls → Motorized Drives
  DECLARE
    motorized_drives_id uuid;
  BEGIN
    SELECT id INTO motorized_drives_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR-MOTORIZED' AND deleted = false LIMIT 1;
    
    IF motorized_drives_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Motorized Drives (MOTOR-MOTORIZED)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = motorized_drives_id) != motor_parent_id THEN
      RAISE WARNING '   ⚠️  Motorized Drives tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Motorized Drives → Drives & Controls (CORRECTO)';
    END IF;
  END;

  -- Drives & Controls → Controls
  DECLARE
    controls_id uuid;
  BEGIN
    SELECT id INTO controls_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR-CONTROL' AND deleted = false LIMIT 1;
    
    IF controls_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Controls (MOTOR-CONTROL)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = controls_id) != motor_parent_id THEN
      RAISE WARNING '   ⚠️  Controls tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Controls → Drives & Controls (CORRECTO)';
    END IF;
  END;

  -- Fabric → Window Film
  DECLARE
    window_film_id uuid;
  BEGIN
    SELECT id INTO window_film_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'WINDOW-FILM' AND deleted = false LIMIT 1;
    
    IF window_film_id IS NULL THEN
      RAISE WARNING '   ❌ FALTA: Window Film (WINDOW-FILM)';
      missing_count := missing_count + 1;
    ELSIF (SELECT parent_category_id FROM public."ItemCategories" WHERE id = window_film_id) != fab_parent_id THEN
      RAISE WARNING '   ⚠️  Window Film tiene padre INCORRECTO';
      wrong_parent_count := wrong_parent_count + 1;
    ELSE
      RAISE NOTICE '   ✅ Window Film → Fabric (CORRECTO)';
    END IF;
  END;

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RESUMEN:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '   Categorías faltantes: %', missing_count;
  RAISE NOTICE '   Categorías con padre incorrecto: %', wrong_parent_count;
  RAISE NOTICE '';
  
  IF missing_count = 0 AND wrong_parent_count = 0 THEN
    RAISE NOTICE '✅ TODO ESTÁ CORRECTO!';
  ELSIF missing_count > 0 THEN
    RAISE WARNING '⚠️  FALTAN % CATEGORÍAS - Necesitas crearlas o están marcadas como deleted', missing_count;
  ELSIF wrong_parent_count > 0 THEN
    RAISE WARNING '⚠️  % CATEGORÍAS TIENEN PADRE INCORRECTO - Ejecuta el script 69 para corregirlas', wrong_parent_count;
  END IF;
  
  RAISE NOTICE '';

END $$;

