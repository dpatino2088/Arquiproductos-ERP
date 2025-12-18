-- ====================================================
-- Migration 80: Asignar categorías por patrones (CORRECTO)
-- ====================================================
-- Este script asigna categorías específicas basándose en patrones
-- en el SKU, nombre o descripción de los items
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer := 0;
  
  -- Category IDs
  comp_bracket_id uuid;
  comp_cassette_id uuid;
  comp_side_id uuid;
  comp_bottom_id uuid;
  comp_tube_id uuid;
  comp_chain_id uuid;
  comp_hardware_id uuid;
  acc_battery_id uuid;
  acc_remote_id uuid;
  acc_sensor_id uuid;
  acc_tool_id uuid;
  motor_manual_id uuid;
  motor_motorized_id uuid;
  motor_control_id uuid;
  fabric_id uuid;
  window_film_id uuid;
  service_id uuid;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ASIGNACIÓN DE CATEGORÍAS POR PATRONES';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Obtener IDs de todas las categorías
  -- ====================================================
  RAISE NOTICE 'PASO 1: Obteniendo IDs de categorías...';
  
  SELECT id INTO comp_bracket_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-BRACKET' AND deleted = false LIMIT 1;
  SELECT id INTO comp_cassette_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-CASSETTE' AND deleted = false LIMIT 1;
  SELECT id INTO comp_side_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-SIDE' AND deleted = false LIMIT 1;
  SELECT id INTO comp_bottom_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-BOTTOM' AND deleted = false LIMIT 1;
  SELECT id INTO comp_tube_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-TUBE' AND deleted = false LIMIT 1;
  SELECT id INTO comp_chain_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-CHAIN' AND deleted = false LIMIT 1;
  SELECT id INTO comp_hardware_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'COMP-HARDWARE' AND deleted = false LIMIT 1;
  SELECT id INTO acc_battery_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-BATTERY' AND deleted = false LIMIT 1;
  SELECT id INTO acc_remote_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-REMOTE' AND deleted = false LIMIT 1;
  SELECT id INTO acc_sensor_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-SENSOR' AND deleted = false LIMIT 1;
  SELECT id INTO acc_tool_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC-TOOL' AND deleted = false LIMIT 1;
  SELECT id INTO motor_manual_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR-MANUAL' AND deleted = false LIMIT 1;
  SELECT id INTO motor_motorized_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR-MOTORIZED' AND deleted = false LIMIT 1;
  SELECT id INTO motor_control_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'MOTOR-CONTROL' AND deleted = false LIMIT 1;
  SELECT id INTO fabric_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'FABRIC' AND deleted = false LIMIT 1;
  SELECT id INTO window_film_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'WINDOW-FILM' AND deleted = false LIMIT 1;
  SELECT id INTO service_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'SERVICE' AND deleted = false LIMIT 1;
  
  RAISE NOTICE '   ✅ IDs obtenidos';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Limpiar TODAS las categorías primero
  -- ====================================================
  RAISE NOTICE 'PASO 2: Limpiando todas las categorías...';
  
  UPDATE public."CatalogItems"
  SET item_category_id = NULL, updated_at = NOW()
  WHERE organization_id = target_org_id
    AND deleted = false;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Limpiados % items', updated_count;
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 3: Asignar categorías específicas por patrones
  -- ====================================================
  RAISE NOTICE 'PASO 3: Asignando categorías por patrones...';
  
  -- Service (primero, para evitar conflictos)
  IF service_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = service_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%service%'
        OR LOWER(COALESCE(description, '')) LIKE '%service%'
        OR LOWER(COALESCE(description, '')) LIKE '%servicio%'
        OR item_type = 'service'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Service: % items', updated_count; END IF;
  END IF;

  -- Fabric (por flag)
  IF fabric_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = fabric_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND is_fabric = true;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Fabric: % items', updated_count; END IF;
  END IF;

  -- Window Film
  IF window_film_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = window_film_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%film%'
        OR LOWER(COALESCE(description, '')) LIKE '%window film%'
        OR LOWER(COALESCE(description, '')) LIKE '%film%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Window Film: % items', updated_count; END IF;
  END IF;

  -- Batteries
  IF acc_battery_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = acc_battery_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%battery%'
        OR LOWER(COALESCE(sku, '')) LIKE '%batt%'
        OR LOWER(COALESCE(description, '')) LIKE '%battery%'
        OR LOWER(COALESCE(description, '')) LIKE '%batt%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Batteries: % items', updated_count; END IF;
  END IF;

  -- Remotes
  IF acc_remote_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = acc_remote_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%remote%'
        OR LOWER(COALESCE(description, '')) LIKE '%remote%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Remotes: % items', updated_count; END IF;
  END IF;

  -- Sensors
  IF acc_sensor_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = acc_sensor_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%sensor%'
        OR LOWER(COALESCE(description, '')) LIKE '%sensor%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Sensors: % items', updated_count; END IF;
  END IF;

  -- Tool
  IF acc_tool_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = acc_tool_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%tool%'
        OR LOWER(COALESCE(description, '')) LIKE '%tool%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Tool: % items', updated_count; END IF;
  END IF;

  -- Manual Drives
  IF motor_manual_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = motor_manual_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%manual%'
        OR LOWER(COALESCE(description, '')) LIKE '%manual%'
        OR LOWER(COALESCE(description, '')) LIKE '%manual drive%'
      )
      AND LOWER(COALESCE(sku, '')) NOT LIKE '%motorized%'
      AND LOWER(COALESCE(description, '')) NOT LIKE '%motorized%';
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Manual Drives: % items', updated_count; END IF;
  END IF;

  -- Motorized Drives
  IF motor_motorized_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = motor_motorized_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%motorized%'
        OR LOWER(COALESCE(sku, '')) LIKE '%motor%'
        OR LOWER(COALESCE(description, '')) LIKE '%motorized%'
        OR LOWER(COALESCE(description, '')) LIKE '%motorized drive%'
      )
      AND LOWER(COALESCE(sku, '')) NOT LIKE '%control%'
      AND LOWER(COALESCE(description, '')) NOT LIKE '%control%';
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Motorized Drives: % items', updated_count; END IF;
  END IF;

  -- Controls
  IF motor_control_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = motor_control_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%control%'
        OR LOWER(COALESCE(description, '')) LIKE '%control%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Controls: % items', updated_count; END IF;
  END IF;

  -- Brackets
  IF comp_bracket_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_bracket_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%bracket%'
        OR LOWER(COALESCE(description, '')) LIKE '%bracket%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Brackets: % items', updated_count; END IF;
  END IF;

  -- Cassette
  IF comp_cassette_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_cassette_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%cassette%'
        OR LOWER(COALESCE(description, '')) LIKE '%cassette%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Cassette: % items', updated_count; END IF;
  END IF;

  -- Side Channel
  IF comp_side_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_side_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%side%'
        OR LOWER(COALESCE(description, '')) LIKE '%side channel%'
        OR LOWER(COALESCE(description, '')) LIKE '%side%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Side Channel: % items', updated_count; END IF;
  END IF;

  -- Bottom Bar
  IF comp_bottom_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_bottom_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%bottom%'
        OR LOWER(COALESCE(description, '')) LIKE '%bottom bar%'
        OR LOWER(COALESCE(description, '')) LIKE '%bottom%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Bottom Bar: % items', updated_count; END IF;
  END IF;

  -- Tube
  IF comp_tube_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_tube_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%tube%'
        OR LOWER(COALESCE(description, '')) LIKE '%tube%'
      )
      AND LOWER(COALESCE(sku, '')) NOT LIKE '%cassette%'
      AND LOWER(COALESCE(description, '')) NOT LIKE '%cassette%';
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Tube: % items', updated_count; END IF;
  END IF;

  -- Chains
  IF comp_chain_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_chain_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        LOWER(COALESCE(sku, '')) LIKE '%chain%'
        OR LOWER(COALESCE(description, '')) LIKE '%chain%'
      );
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Chains: % items', updated_count; END IF;
  END IF;

  -- Hardware (último, como fallback para items que no encajan en otras categorías)
  IF comp_hardware_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = comp_hardware_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN RAISE NOTICE '   ✅ Hardware (fallback): % items', updated_count; END IF;
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  DECLARE
    remaining_uncategorized integer;
    total_items integer;
  BEGIN
    SELECT COUNT(*) INTO total_items
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false;
    
    SELECT COUNT(*) INTO remaining_uncategorized
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ ASIGNACIÓN COMPLETADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Resumen:';
    RAISE NOTICE '   - Total items: %', total_items;
    RAISE NOTICE '   - Sin categoría: % items', remaining_uncategorized;
    RAISE NOTICE '';
    
    IF remaining_uncategorized > 0 THEN
      RAISE WARNING '   ⚠️  Aún quedan % items sin categoría', remaining_uncategorized;
    ELSE
      RAISE NOTICE '   ✅ Todos los items tienen categoría asignada';
    END IF;
    RAISE NOTICE '';
  END;

END $$;

-- Query para ver la distribución final
SELECT 
  ic.name as categoria_nombre,
  ic.code as categoria_codigo,
  COUNT(*) as cantidad_items
FROM public."CatalogItems" ci
INNER JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ic.deleted = false
GROUP BY ic.name, ic.code
ORDER BY cantidad_items DESC;

