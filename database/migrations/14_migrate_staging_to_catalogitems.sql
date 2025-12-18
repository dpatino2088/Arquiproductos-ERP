-- ====================================================
-- Script para eliminar todo CatalogItems y migrar desde staging
-- ====================================================
-- Este script:
-- 1. Elimina las referencias en tablas relacionadas (CatalogItemProductTypes, QuoteLines, etc.)
-- 2. Elimina todos los registros de CatalogItems para la organización
-- 3. Inserta todos los datos desde _stg_catalog_items tal cual están
-- 
-- Mapeo de columnas:
-- - cost_price_exw (staging) → cost_exw (CatalogItems)
-- - item_description (staging) → description (CatalogItems)
-- - collection (staging) → collection_name (CatalogItems) DIRECTAMENTE (sin FK)
-- - manufacturer (staging) → manufacturer_id (CatalogItems) via JOIN
-- - category (staging) → item_category_id (CatalogItems) via JOIN
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  deleted_count integer;
  inserted_count integer;
  staging_count integer;
  existing_count integer;
  duplicate_count integer;
  rec RECORD;
  duplicate_skus RECORD;
BEGIN
  RAISE NOTICE '🗑️  Eliminando todos los CatalogItems y referencias de la organización...';
  RAISE NOTICE '   Target Organization ID: %', target_org_id;

  -- ====================================================
  -- STEP 1: Crear staging table si no existe
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE NOTICE '📋 Creando tabla _stg_catalog_items...';
    
    CREATE TABLE IF NOT EXISTS public."_stg_catalog_items" (
      -- Identificadores
      sku text,
      variant_name text,
      item_name text,
      item_description text,
      
      -- Tipos y medidas
      item_type text,
      measure_basis text,
      uom text,
      
      -- Fabric specific
      is_fabric text, -- Se convierte a boolean después
      roll_widt text, -- Se convierte a numeric después (roll_width_m)
      
      -- Pricing (puede venir como fabric_prici o cost_price_exw)
      fabric_prici text, -- Se convierte a numeric después (cost_exw)
      cost_price_exw text, -- Alternativa para cost_exw
      
      -- Status
      active text, -- Se convierte a boolean después
      discontinued text, -- Se convierte a boolean después
      
      -- Relaciones
      manufacturer text,
      category text,
      family text, -- Para agrupar productos (opcional)
      
      -- Collections (para fabrics, puede venir del CSV o derivarse)
      collection text,
      
      -- Metadata adicional (opcional)
      default_margin_pct text, -- Se convierte a numeric después
      msrp text -- Se convierte a numeric después
    );

    RAISE NOTICE '✅ Tabla _stg_catalog_items creada';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANTE: La tabla está vacía.';
    RAISE NOTICE '   Por favor importa el CSV antes de continuar:';
    RAISE NOTICE '   1. Ve a Supabase Table Editor';
    RAISE NOTICE '   2. Selecciona _stg_catalog_items';
    RAISE NOTICE '   3. Haz clic en "Import data from CSV"';
    RAISE NOTICE '   4. Sube tu archivo CSV';
    RAISE NOTICE '   5. Vuelve a ejecutar este script';
    RAISE NOTICE '';
    RAISE EXCEPTION 'La tabla _stg_catalog_items está vacía. Por favor importa el CSV primero.';
  END IF;

  -- Verificar que la tabla tiene datos
  SELECT COUNT(*) INTO staging_count
  FROM public."_stg_catalog_items"
  WHERE sku IS NOT NULL AND trim(sku) <> '';
  
  IF staging_count = 0 THEN
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  La tabla _stg_catalog_items está vacía.';
    RAISE NOTICE '   Por favor importa el CSV:';
    RAISE NOTICE '   1. Ve a Supabase Table Editor';
    RAISE NOTICE '   2. Selecciona _stg_catalog_items';
    RAISE NOTICE '   3. Haz clic en "Import data from CSV"';
    RAISE NOTICE '   4. Sube tu archivo CSV';
    RAISE NOTICE '   5. Vuelve a ejecutar este script';
    RAISE NOTICE '';
    RAISE EXCEPTION 'La tabla _stg_catalog_items está vacía. Por favor importa el CSV primero.';
  ELSE
    RAISE NOTICE '✅ Tabla _stg_catalog_items tiene % registros', staging_count;
  END IF;

  -- ====================================================
  -- STEP 2: Eliminar referencias en CatalogItemProductTypes (si existe)
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItemProductTypes'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🗑️  Eliminando referencias en CatalogItemProductTypes...';
    
    DELETE FROM public."CatalogItemProductTypes" cipt
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = cipt.catalog_item_id
        AND ci.organization_id = target_org_id
    );

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Eliminados % registros de CatalogItemProductTypes', deleted_count;
  ELSE
    RAISE NOTICE 'ℹ️  La tabla CatalogItemProductTypes no existe, saltando...';
  END IF;

  -- ====================================================
  -- STEP 3: Eliminar referencias en QuoteLines (si existe catalog_item_id)
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines' 
    AND column_name = 'catalog_item_id'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🗑️  Eliminando referencias en QuoteLines...';
    
    UPDATE public."QuoteLines" ql
    SET catalog_item_id = NULL
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = ql.catalog_item_id
        AND ci.organization_id = target_org_id
    );

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Actualizadas % QuoteLines (catalog_item_id = NULL)', deleted_count;
  END IF;

  -- ====================================================
  -- STEP 4: Eliminar todos los CatalogItems de la organización (si la tabla existe)
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🗑️  Eliminando todos los CatalogItems...';
    
    DELETE FROM public."CatalogItems"
    WHERE organization_id = target_org_id;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Eliminados % CatalogItems', deleted_count;
  ELSE
    RAISE NOTICE 'ℹ️  La tabla CatalogItems no existe, se creará con los datos nuevos';
  END IF;

  -- ====================================================
  -- STEP 5: Verificar que CatalogItems existe antes de insertar
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) THEN
    RAISE EXCEPTION 'La tabla CatalogItems no existe. Por favor ejecuta primero 18_create_catalogitems_with_collection_name.sql';
  END IF;

  -- ====================================================
  -- STEP 6: Verificar SKUs duplicados en staging
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Verificando SKUs duplicados en staging...';
  
  -- Verificar SKUs duplicados en staging
  duplicate_count := 0;
  FOR duplicate_skus IN (
    SELECT sku, COUNT(*) as count
    FROM public."_stg_catalog_items"
    WHERE sku IS NOT NULL AND trim(sku) <> ''
    GROUP BY sku
    HAVING COUNT(*) > 1
    ORDER BY count DESC
    LIMIT 10
  ) LOOP
    RAISE WARNING 'SKU duplicado en CSV: % (% veces)', duplicate_skus.sku, duplicate_skus.count;
    duplicate_count := duplicate_count + 1;
  END LOOP;
  
  IF duplicate_count > 0 THEN
    RAISE WARNING 'Se encontraron % SKUs duplicados en el CSV. Se usarán los últimos valores.', duplicate_count;
  ELSE
    RAISE NOTICE 'No se encontraron SKUs duplicados en el CSV';
  END IF;

  -- ====================================================
  -- STEP 7: Verificar SKUs existentes en CatalogItems
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Verificando SKUs existentes en CatalogItems...';
  
  -- Verificar SKUs existentes en CatalogItems
  SELECT COUNT(*) INTO existing_count
  FROM public."CatalogItems" ci
  INNER JOIN public."_stg_catalog_items" s
    ON ci.organization_id = target_org_id
    AND ci.sku = trim(s.sku)
    AND ci.deleted = false;
  
  IF existing_count > 0 THEN
    RAISE WARNING 'Se encontraron % SKUs que ya existen en CatalogItems. Se actualizarán.', existing_count;
  ELSE
    RAISE NOTICE 'No hay SKUs existentes. Se insertarán nuevos registros.';
  END IF;

  -- ====================================================
  -- STEP 8: Insertar/Actualizar datos desde staging
  -- ====================================================
  -- Nota: Usamos INSERT ... ON CONFLICT DO UPDATE para manejar duplicados
  -- Esto actualiza los registros existentes o inserta nuevos
  RAISE NOTICE '';
  RAISE NOTICE '📥 Insertando/Actualizando datos desde staging table...';

  -- Usar DISTINCT ON para eliminar duplicados del staging antes de insertar
  -- Esto toma solo la última fila por SKU (basado en el orden natural de la tabla)
  INSERT INTO public."CatalogItems" (
    organization_id, 
    sku, 
    item_name,
    description,
    manufacturer_id, 
    item_category_id,
    collection_name,
    variant_name,
    item_type, 
    measure_basis, 
    uom,
    is_fabric, 
    roll_width_m, 
    fabric_pricing_mode,
    active, 
    discontinued, 
    cost_exw,
    family
  )
  SELECT DISTINCT ON (trim(COALESCE(s.sku, '')))
    target_org_id,
    trim(COALESCE(s.sku, '')),
    trim(COALESCE(s.item_name, '')),
    trim(COALESCE(s.item_description, '')),
    m.id,
    ic.id,
    CASE 
      WHEN COALESCE(
        CASE 
          WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE NULL
        END, 
        false
      ) = TRUE
        AND COALESCE(s.collection, '') <> ''
        AND trim(COALESCE(s.collection, '')) <> ''
      THEN trim(s.collection)
      ELSE NULL
    END,
    CASE 
      WHEN COALESCE(
        CASE 
          WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE NULL
        END, 
        false
      ) = TRUE
        AND COALESCE(s.variant_name, '') <> ''
        AND trim(COALESCE(s.variant_name, '')) <> ''
      THEN trim(s.variant_name)
      ELSE NULL
    END,
    COALESCE(s.item_type, ''),
    COALESCE(s.measure_basis, 'unit'),
    COALESCE(s.uom, 'PCS'),
    COALESCE(
      CASE 
        WHEN s.is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
        WHEN s.is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
        ELSE NULL
      END, 
      false
    ),
    CASE 
      WHEN COALESCE(s.roll_widt, '') = '' OR trim(COALESCE(s.roll_widt, '')) = '' THEN NULL
      WHEN trim(s.roll_widt) ~ '^[0-9]+\.?[0-9]*$' THEN s.roll_widt::numeric
      ELSE NULL
    END,
    NULL, -- fabric_pricing_mode (no viene del staging)
    COALESCE(
      CASE 
        WHEN s.active::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
        WHEN s.active::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
        ELSE NULL
      END, 
      true
    ),
    COALESCE(
      CASE 
        WHEN s.discontinued::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
        WHEN s.discontinued::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
        ELSE NULL
      END, 
      false
    ),
    CASE 
      -- Priorizar fabric_prici si existe, sino cost_price_exw
      WHEN COALESCE(s.fabric_prici, '') <> '' AND trim(s.fabric_prici) <> '' THEN
        CASE 
          WHEN trim(s.fabric_prici) ~ '^[0-9]+\.?[0-9]*$' THEN s.fabric_prici::numeric
          ELSE 0
        END
      WHEN COALESCE(s.cost_price_exw, '') <> '' AND trim(s.cost_price_exw) <> '' THEN
        CASE 
          WHEN trim(s.cost_price_exw) ~ '^[0-9]+\.?[0-9]*$' THEN s.cost_price_exw::numeric
          ELSE 0
        END
      ELSE 0
    END,
    trim(COALESCE(s.family, ''))  -- family
  FROM public."_stg_catalog_items" s
  LEFT JOIN public."Manufacturers" m
    ON lower(m.name) = lower(trim(COALESCE(s.manufacturer, '')))
  LEFT JOIN public."ItemCategories" ic
    ON lower(ic.name) = lower(trim(COALESCE(s.category, '')))
  WHERE s.sku IS NOT NULL 
    AND trim(COALESCE(s.sku, '')) <> ''
  ORDER BY trim(COALESCE(s.sku, '')), s.ctid DESC  -- ctid para tomar la última fila en caso de duplicados
  ON CONFLICT (organization_id, sku) 
  WHERE deleted = false
  DO UPDATE SET
    item_name = EXCLUDED.item_name,
    description = EXCLUDED.description,
    manufacturer_id = EXCLUDED.manufacturer_id,
    item_category_id = EXCLUDED.item_category_id,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    item_type = EXCLUDED.item_type,
    measure_basis = EXCLUDED.measure_basis,
    uom = EXCLUDED.uom,
    is_fabric = EXCLUDED.is_fabric,
    roll_width_m = EXCLUDED.roll_width_m,
    fabric_pricing_mode = EXCLUDED.fabric_pricing_mode,
    active = EXCLUDED.active,
    discontinued = EXCLUDED.discontinued,
    cost_exw = EXCLUDED.cost_exw,
    family = EXCLUDED.family,
    updated_at = NOW();

  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RAISE NOTICE '✅ Insertados/Actualizados % CatalogItems desde staging', inserted_count;

  -- ====================================================
  -- STEP 7: Verificación
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verificación:';
  
  SELECT COUNT(*) INTO inserted_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id;
  
  RAISE NOTICE '   Total CatalogItems en la base de datos: %', inserted_count;

  SELECT COUNT(*) INTO inserted_count
  FROM public."_stg_catalog_items"
  WHERE sku IS NOT NULL AND trim(sku) <> '';
  
  RAISE NOTICE '   Total registros en staging table: %', inserted_count;

  -- ====================================================
  -- STEP 8: Mostrar ejemplos
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📋 Ejemplos de CatalogItems insertados:';
  FOR rec IN 
    SELECT 
      ci.sku,
      ci.item_name,
      ci.variant_name,
      ci.collection_name,
      ci.is_fabric,
      ci.cost_exw,
      CASE 
        WHEN ci.is_fabric AND ci.collection_name IS NOT NULL AND ci.variant_name IS NOT NULL
        THEN ci.collection_name || ' ' || ci.variant_name
        ELSE ci.item_name
      END as display_name
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = target_org_id
    ORDER BY ci.sku
    LIMIT 10
  LOOP
    RAISE NOTICE '   - SKU: %, Item: %, Collection: %, Variant: %, is_fabric: %, cost_exw: %, Display: %', 
      rec.sku, rec.item_name, rec.collection_name, rec.variant_name, rec.is_fabric, rec.cost_exw, rec.display_name;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migración completada!';

END $$;

