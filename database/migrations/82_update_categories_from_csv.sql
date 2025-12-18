-- ====================================================
-- Migration 82: Actualizar categorías desde CSV
-- ====================================================
-- Este script actualiza las categorías de CatalogItems
-- basándose en el CSV importado en la tabla de staging
-- ====================================================
-- IMPORTANTE: Primero debes importar el CSV a una tabla de staging
-- usando Supabase Table Editor o el comando COPY
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer := 0;
  total_updated integer := 0;
  
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
  accessories_id uuid;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ACTUALIZACIÓN DE CATEGORÍAS DESDE CSV';
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
  
  -- Accessories (grupo padre - para items que solo dicen "Accessories")
  SELECT id INTO accessories_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id AND code = 'ACC' AND deleted = false AND is_group = true LIMIT 1;
  
  RAISE NOTICE '   ✅ IDs obtenidos';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Verificar si existe tabla de staging y actualizar
  -- ====================================================
  RAISE NOTICE 'PASO 2: Verificando tabla de staging...';
  
  DECLARE
    staging_count integer := 0;
    use_stg_items boolean := false;
  BEGIN
    -- Intentar _stg_catalog_items primero
    BEGIN
      SELECT COUNT(*) INTO staging_count
      FROM public."_stg_catalog_items"
      WHERE sku IS NOT NULL AND trim(sku) <> '';
      use_stg_items := true;
      RAISE NOTICE '   ✅ Encontrada tabla _stg_catalog_items con % registros', staging_count;
    EXCEPTION WHEN OTHERS THEN
      -- Intentar _stg_catalog_update
      BEGIN
        SELECT COUNT(*) INTO staging_count
        FROM public."_stg_catalog_update"
        WHERE sku IS NOT NULL AND trim(sku) <> '';
        use_stg_items := false;
        RAISE NOTICE '   ✅ Encontrada tabla _stg_catalog_update con % registros', staging_count;
      EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR: No se encontró tabla de staging. Por favor importa el CSV primero a _stg_catalog_items o _stg_catalog_update';
      END;
    END;
    
    IF staging_count = 0 THEN
      RAISE WARNING '';
      RAISE WARNING '========================================';
      RAISE WARNING '⚠️  TABLA DE STAGING VACÍA';
      RAISE WARNING '========================================';
      RAISE WARNING '';
      RAISE WARNING 'La tabla de staging existe pero está vacía.';
      RAISE WARNING '';
      RAISE WARNING 'Para importar el CSV:';
      RAISE WARNING '   1. Ve a Supabase Dashboard → Table Editor';
      RAISE WARNING '   2. Selecciona la tabla "_stg_catalog_items"';
      RAISE WARNING '   3. Haz clic en "Insert" → "Import from CSV"';
      RAISE WARNING '   4. Selecciona tu archivo CSV';
      RAISE WARNING '   5. Marca "Header row" y haz clic en "Import"';
      RAISE WARNING '';
      RAISE WARNING 'O ejecuta el script 85 para ver más instrucciones.';
      RAISE WARNING '';
      RAISE EXCEPTION 'ERROR: La tabla de staging está vacía. Por favor importa el CSV primero usando Table Editor.';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- PASO 3: Actualizar categorías basándose en el CSV
    -- ====================================================
    RAISE NOTICE 'PASO 3: Actualizando categorías desde CSV...';
    
    -- Mapeo de valores del CSV a códigos de categorías
    IF use_stg_items THEN
    -- Actualizar desde _stg_catalog_items
    UPDATE public."CatalogItems" ci
    SET item_category_id = CASE
      -- Fabric
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'fabric' THEN fabric_id
      -- Hardware
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'hardware' THEN comp_hardware_id
      -- Brackets
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'brackets' THEN comp_bracket_id
      -- Cassette
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'cassette' THEN comp_cassette_id
      -- Tube
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'tube' THEN comp_tube_id
      -- Chains
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'chains' THEN comp_chain_id
      -- Side Channel
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'side channel' THEN comp_side_id
      -- Batteries
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'batteries' THEN acc_battery_id
      -- Remotes
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'remotes' THEN acc_remote_id
      -- Sensors
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'sensors' THEN acc_sensor_id
      -- Tool
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'tool' THEN acc_tool_id
      -- Manual Drives
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'manual drives' THEN motor_manual_id
      -- Motorized Drives
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'motorized drives' THEN motor_motorized_id
      -- Controls
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'controls' THEN motor_control_id
      -- Service
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'service' THEN service_id
      -- Componets (typo en CSV) -> Hardware como fallback
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'componets' THEN comp_hardware_id
      -- Accessories (grupo) -> usar Hardware como fallback (o puedes crear una categoría hoja específica)
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'accessories' THEN comp_hardware_id
      -- FALSE o valores inválidos -> NULL (se asignarán después)
      ELSE NULL
    END,
    updated_at = NOW()
    FROM public."_stg_catalog_items" s
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.sku = trim(s.sku)
      AND s.sku IS NOT NULL
      AND trim(s.sku) <> ''
      AND s.item_category_id IS NOT NULL
      AND trim(s.item_category_id) <> ''
      AND LOWER(trim(s.item_category_id)) NOT IN ('false', 'coulisse', 'item_category_id');
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    total_updated := total_updated + updated_count;
    RAISE NOTICE '   ✅ Actualizados % items desde _stg_catalog_items', updated_count;
    
  ELSE
    -- Actualizar desde _stg_catalog_update
    UPDATE public."CatalogItems" ci
    SET item_category_id = CASE
      -- Fabric
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'fabric' THEN fabric_id
      -- Hardware
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'hardware' THEN comp_hardware_id
      -- Brackets
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'brackets' THEN comp_bracket_id
      -- Cassette
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'cassette' THEN comp_cassette_id
      -- Tube
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'tube' THEN comp_tube_id
      -- Chains
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'chains' THEN comp_chain_id
      -- Side Channel
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'side channel' THEN comp_side_id
      -- Batteries
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'batteries' THEN acc_battery_id
      -- Remotes
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'remotes' THEN acc_remote_id
      -- Sensors
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'sensors' THEN acc_sensor_id
      -- Tool
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'tool' THEN acc_tool_id
      -- Manual Drives
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'manual drives' THEN motor_manual_id
      -- Motorized Drives
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'motorized drives' THEN motor_motorized_id
      -- Controls
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'controls' THEN motor_control_id
      -- Service
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'service' THEN service_id
      -- Componets (typo en CSV) -> Hardware como fallback
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'componets' THEN comp_hardware_id
      -- Accessories (grupo) -> usar Hardware como fallback
      WHEN LOWER(trim(COALESCE(s.item_category_id, ''))) = 'accessories' THEN comp_hardware_id
      -- FALSE o valores inválidos -> NULL
      ELSE NULL
    END,
    updated_at = NOW()
    FROM public."_stg_catalog_update" s
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.sku = trim(s.sku)
      AND s.sku IS NOT NULL
      AND trim(s.sku) <> ''
      AND s.item_category_id IS NOT NULL
      AND trim(s.item_category_id) <> ''
      AND LOWER(trim(s.item_category_id)) NOT IN ('false', 'coulisse', 'item_category_id');
    
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      total_updated := total_updated + updated_count;
      RAISE NOTICE '   ✅ Actualizados % items desde _stg_catalog_update', updated_count;
    END IF;
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 4: Asignar Fabric a items con is_fabric = true que no tienen categoría
  -- ====================================================
  IF fabric_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = fabric_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND is_fabric = true;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fabric (por is_fabric): % items', updated_count;
      total_updated := total_updated + updated_count;
    END IF;
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
    RAISE NOTICE '✅ ACTUALIZACIÓN COMPLETADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Resumen:';
    RAISE NOTICE '   - Total items: %', total_items;
    RAISE NOTICE '   - Items actualizados: %', total_updated;
    RAISE NOTICE '   - Sin categoría: % items', remaining_uncategorized;
    RAISE NOTICE '';
    
    IF remaining_uncategorized > 0 THEN
      RAISE WARNING '   ⚠️  Aún quedan % items sin categoría', remaining_uncategorized;
      RAISE WARNING '   💡 Estos items no tenían categoría válida en el CSV';
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

