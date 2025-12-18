-- ====================================================
-- Migration 64: Update CatalogItems with missing data from CSV
-- ====================================================
-- Este script actualiza CatalogItems con los datos faltantes:
-- - variant_name (desde CSV)
-- - roll_width_m (solo para fabrics, solo si tiene valor en CSV)
-- - cost_exw (desde cost_exw del CSV - usar tal cual, para todos los items)
-- - family
-- - item_category_id (basado en category del CSV)
-- 
-- NOTA: collection_name se actualiza desde otro CSV (catalog_items_import_DP_COLLECTIONS_FINAL.csv)
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer;
  rec RECORD;
  collections_count integer;
  staging_count integer;
  use_stg_items boolean := false;
  stg_table_name text;
  stg_items_count integer := 0;
  stg_update_count integer := 0;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Actualizando CatalogItems con datos del CSV';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Verificar tabla de staging y crear si es necesario
  -- ====================================================
  RAISE NOTICE '📋 Verificando tabla de staging...';
  
  -- Verificar si _stg_catalog_items tiene datos (tabla usada en migraciones anteriores)
  BEGIN
    -- Verificar _stg_catalog_items
    SELECT COUNT(*) INTO stg_items_count
    FROM public."_stg_catalog_items"
    WHERE sku IS NOT NULL AND trim(sku) <> '';
  EXCEPTION WHEN OTHERS THEN
    stg_items_count := 0;
  END;
  
  BEGIN
    -- Verificar _stg_catalog_update
    SELECT COUNT(*) INTO stg_update_count
    FROM public."_stg_catalog_update"
    WHERE sku IS NOT NULL AND trim(sku) <> '';
  EXCEPTION WHEN OTHERS THEN
    stg_update_count := 0;
  END;
  
  -- Si _stg_catalog_items tiene datos, usarla
  IF stg_items_count > 0 THEN
    use_stg_items := true;
    staging_count := stg_items_count;
    stg_table_name := '_stg_catalog_items';
    RAISE NOTICE '   ✅ Encontrados % registros en _stg_catalog_items', stg_items_count;
    RAISE NOTICE '   ℹ️  Usando _stg_catalog_items como fuente de datos';
  ELSIF stg_update_count > 0 THEN
    use_stg_items := false;
    staging_count := stg_update_count;
    stg_table_name := '_stg_catalog_update';
    RAISE NOTICE '   ✅ Encontrados % registros en _stg_catalog_update', stg_update_count;
  ELSE
    -- Crear tabla temporal si no existe
    CREATE TABLE IF NOT EXISTS public."_stg_catalog_update" (
      sku text,
      variant_name text,
      item_name text,
      item_description text,
      item_type text,
      measure_basis text,
      uom text,
      is_fabric text,
      roll_width_m text,
      cost_exw text,
      active text,
      discontinued text,
      manufacturer text,
      category text,
      family text
    );
    RAISE NOTICE '   ✅ Tabla _stg_catalog_update creada';
    staging_count := 0;
  END IF;
  
  -- Si no hay datos en ninguna tabla, mostrar instrucciones
  IF staging_count = 0 THEN
    RAISE WARNING '';
    RAISE WARNING '========================================';
    RAISE WARNING '⚠️  ERROR: La tabla _stg_catalog_update está vacía';
    RAISE WARNING '========================================';
    RAISE WARNING '';
    RAISE WARNING 'Por favor sigue estos pasos:';
    RAISE WARNING '1. Ve a Supabase Table Editor';
    RAISE WARNING '2. Selecciona la tabla _stg_catalog_update';
    RAISE WARNING '3. Haz clic en "Import data from CSV"';
    RAISE WARNING '4. Sube el archivo: catalog_items_import_DP_COLLECTIONS_VARIANT FINALFINAL.csv';
    RAISE WARNING '5. Vuelve a ejecutar este script';
    RAISE WARNING '';
    RAISE EXCEPTION 'Script detenido: tabla _stg_catalog_update está vacía. Por favor importa el CSV primero.';
  ELSE
    RAISE NOTICE '   ✅ Tabla _stg_catalog_update tiene % registros', staging_count;
  END IF;

  -- ====================================================
  -- STEP 2: Actualizar roll_width_m (solo para fabrics)
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando roll_width_m (solo para fabrics)...';
  
  -- Actualizar roll_width_m usando la tabla correcta
  IF use_stg_items THEN
    UPDATE public."CatalogItems" ci
    SET roll_width_m = CASE 
        WHEN COALESCE(
          CASE 
            WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
            WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
            ELSE NULL
          END, 
          false
        ) = TRUE
          AND COALESCE(s.roll_width_m, '') <> ''
          AND trim(s.roll_width_m) <> ''
          AND trim(s.roll_width_m) ~ '^[0-9]+\.?[0-9]*$'
        THEN s.roll_width_m::numeric
        ELSE ci.roll_width_m
      END,
      updated_at = NOW()
    FROM public."_stg_catalog_items" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(
        CASE 
          WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE NULL
        END, 
        false
      ) = TRUE
      AND COALESCE(s.roll_width_m, '') <> ''
      AND trim(s.roll_width_m) <> ''
      AND trim(s.roll_width_m) ~ '^[0-9]+\.?[0-9]*$';
  ELSE
    UPDATE public."CatalogItems" ci
    SET roll_width_m = CASE 
        WHEN COALESCE(
          CASE 
            WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
            WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
            ELSE NULL
          END, 
          false
        ) = TRUE
          AND COALESCE(s.roll_width_m, '') <> ''
          AND trim(s.roll_width_m) <> ''
          AND trim(s.roll_width_m) ~ '^[0-9]+\.?[0-9]*$'
        THEN s.roll_width_m::numeric
        ELSE ci.roll_width_m
      END,
      updated_at = NOW()
    FROM public."_stg_catalog_update" s
  WHERE ci.organization_id = target_org_id
    AND ci.sku = trim(s.sku)
    AND ci.deleted = false
    AND COALESCE(
      CASE 
        WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
        WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
        ELSE NULL
      END, 
      false
    ) = TRUE
    AND COALESCE(s.roll_width_m, '') <> ''
    AND trim(s.roll_width_m) <> ''
    AND trim(s.roll_width_m) ~ '^[0-9]+\.?[0-9]*$';

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Actualizados % fabrics con roll_width_m', updated_count;

  -- ====================================================
  -- STEP 3: Actualizar cost_exw (para todos los items)
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando cost_exw...';
  
  IF use_stg_items THEN
    UPDATE public."CatalogItems" ci
    SET cost_exw = CASE 
        WHEN COALESCE(s.cost_exw, '') <> '' 
          AND trim(s.cost_exw) <> ''
          AND trim(s.cost_exw) ~ '^[0-9]+\.?[0-9]*$'
        THEN s.cost_exw::numeric
        ELSE COALESCE(ci.cost_exw, 0)
      END,
      updated_at = NOW()
    FROM public."_stg_catalog_items" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(s.cost_exw, '') <> ''
      AND trim(s.cost_exw) <> ''
      AND trim(s.cost_exw) ~ '^[0-9]+\.?[0-9]*$';
  ELSE
    UPDATE public."CatalogItems" ci
    SET cost_exw = CASE 
        WHEN COALESCE(s.cost_exw, '') <> '' 
          AND trim(s.cost_exw) <> ''
          AND trim(s.cost_exw) ~ '^[0-9]+\.?[0-9]*$'
        THEN s.cost_exw::numeric
        ELSE COALESCE(ci.cost_exw, 0)
      END,
      updated_at = NOW()
    FROM public."_stg_catalog_update" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(s.cost_exw, '') <> ''
      AND trim(s.cost_exw) <> ''
      AND trim(s.cost_exw) ~ '^[0-9]+\.?[0-9]*$';
  END IF;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Actualizados % items con cost_exw', updated_count;

  -- ====================================================
  -- STEP 4: Actualizar variant_name
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando variant_name...';
  
  IF use_stg_items THEN
    UPDATE public."CatalogItems" ci
    SET variant_name = CASE 
        WHEN COALESCE(s.variant_name, '') <> '' 
          AND trim(s.variant_name) <> ''
        THEN trim(s.variant_name)
        ELSE ci.variant_name
      END,
      updated_at = NOW()
    FROM public."_stg_catalog_items" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(s.variant_name, '') <> ''
      AND trim(s.variant_name) <> '';
  ELSE
    UPDATE public."CatalogItems" ci
    SET variant_name = CASE 
        WHEN COALESCE(s.variant_name, '') <> '' 
          AND trim(s.variant_name) <> ''
        THEN trim(s.variant_name)
        ELSE ci.variant_name
      END,
      updated_at = NOW()
    FROM public."_stg_catalog_update" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(s.variant_name, '') <> ''
      AND trim(s.variant_name) <> '';
  END IF;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Actualizados % items con variant_name', updated_count;

  -- ====================================================
  -- STEP 5: Actualizar collection_name desde otro CSV
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando collection_name desde catalog_items_import_DP_COLLECTIONS_FINAL.csv...';
  
  -- Crear tabla temporal para el CSV de collections si no existe
  CREATE TABLE IF NOT EXISTS public."_stg_collections" (
    sku text,
    collection text,
    variant_name text,
    item_name text,
    item_description text,
    item_type text,
    measure_basis text,
    uom text,
    is_fabric text,
    roll_width_m text,
    cost_exw text,
    active text,
    discontinued text,
    manufacturer text,
    category text,
    family text
  );
  
  -- Verificar si la tabla tiene datos
  SELECT COUNT(*) INTO collections_count
  FROM public."_stg_collections"
  WHERE sku IS NOT NULL AND trim(sku) <> '';
  
  IF collections_count = 0 THEN
    RAISE WARNING '';
    RAISE WARNING '   ⚠️  ADVERTENCIA: La tabla _stg_collections está vacía.';
    RAISE WARNING '   collection_name NO se actualizará desde este CSV.';
    RAISE WARNING '   Si necesitas actualizar collection_name:';
    RAISE WARNING '   1. Ve a Supabase Table Editor';
    RAISE WARNING '   2. Selecciona _stg_collections';
    RAISE WARNING '   3. Importa: catalog_items_import_DP_COLLECTIONS_FINAL.csv';
    RAISE WARNING '   4. Vuelve a ejecutar este script';
    RAISE WARNING '';
    RAISE NOTICE '   ℹ️  Continuando sin actualizar collection_name...';
  ELSE
    RAISE NOTICE '   ✅ Tabla _stg_collections tiene % registros', collections_count;
    
    -- Actualizar collection_name desde _stg_collections usando SKU
    UPDATE public."CatalogItems" ci
    SET collection_name = CASE 
        WHEN COALESCE(sc.collection, '') <> '' 
          AND trim(sc.collection) <> ''
        THEN trim(sc.collection)
        ELSE ci.collection_name
      END,
      updated_at = NOW()
    FROM public."_stg_collections" sc
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(sc.sku)
      AND ci.deleted = false
      AND COALESCE(sc.collection, '') <> ''
      AND trim(sc.collection) <> '';
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Actualizados % items con collection_name', updated_count;
  END IF;

  -- ====================================================
  -- STEP 6: Actualizar family
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando family...';
  
  IF use_stg_items THEN
    UPDATE public."CatalogItems" ci
    SET family = trim(COALESCE(s.family, '')),
        updated_at = NOW()
    FROM public."_stg_catalog_items" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(s.family, '') <> '';
  ELSE
    UPDATE public."CatalogItems" ci
    SET family = trim(COALESCE(s.family, '')),
        updated_at = NOW()
    FROM public."_stg_catalog_update" s
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND COALESCE(s.family, '') <> '';
  END IF;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Actualizados % items con family', updated_count;

  -- ====================================================
  -- STEP 7: Actualizar item_category_id basado en category
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔄 Actualizando item_category_id basado en category...';
  
  IF use_stg_items THEN
    UPDATE public."CatalogItems" ci
    SET item_category_id = ic.id,
        updated_at = NOW()
    FROM public."_stg_catalog_items" s
    LEFT JOIN public."ItemCategories" ic
      ON lower(ic.name) = lower(trim(COALESCE(s.category, '')))
      AND ic.organization_id = target_org_id
      AND ic.deleted = false
    WHERE ci.organization_id = target_org_id
      AND ci.sku = trim(s.sku)
      AND ci.deleted = false
      AND ic.id IS NOT NULL;
  ELSE
    UPDATE public."CatalogItems" ci
    SET item_category_id = ic.id,
        updated_at = NOW()
    FROM public."_stg_catalog_update" s
    LEFT JOIN public."ItemCategories" ic
      ON lower(ic.name) = lower(trim(COALESCE(s.category, '')))
      AND ic.organization_id = target_org_id
      AND ic.deleted = false
    WHERE ci.organization_id = target_org_id
    AND ci.sku = trim(s.sku)
    AND ci.deleted = false
    AND COALESCE(s.category, '') <> ''
    AND ic.id IS NOT NULL;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Actualizados % items con item_category_id', updated_count;

  -- ====================================================
  -- STEP 8: Resumen final
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen de actualizaciones:';
  
  DECLARE
    items_with_collection integer;
    items_with_variant integer;
    items_with_family integer;
    items_with_cost_exw integer;
    items_with_roll_width integer;
  BEGIN
    SELECT COUNT(*) INTO items_with_collection
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND collection_name IS NOT NULL
      AND trim(collection_name) <> ''
      AND deleted = false;
    
    SELECT COUNT(*) INTO items_with_variant
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND variant_name IS NOT NULL
      AND trim(variant_name) <> ''
      AND deleted = false;
    
    SELECT COUNT(*) INTO items_with_family
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND family IS NOT NULL
      AND trim(family) <> ''
      AND deleted = false;
    
    SELECT COUNT(*) INTO items_with_cost_exw
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND cost_exw > 0
      AND deleted = false;
    
    SELECT COUNT(*) INTO items_with_roll_width
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND roll_width_m IS NOT NULL
      AND deleted = false;
    
    RAISE NOTICE '   Items con collection_name: %', items_with_collection;
    RAISE NOTICE '   Items con variant_name: %', items_with_variant;
    RAISE NOTICE '   Items con family: %', items_with_family;
    RAISE NOTICE '   Items con cost_exw > 0: %', items_with_cost_exw;
    RAISE NOTICE '   Items con roll_width_m: %', items_with_roll_width;
  END;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Actualización completada!';
  RAISE NOTICE '';

  -- Limpiar tabla temporal (opcional, comentado para debugging)
  -- DROP TABLE IF EXISTS public."_stg_catalog_update";

END $$;

