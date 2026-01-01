-- ====================================================
-- Migration 65: Migrate from staging table to CatalogItems
-- ====================================================
-- Este script migra todos los datos desde la tabla temporal a CatalogItems
-- Usa INSERT ... ON CONFLICT DO UPDATE para insertar nuevos o actualizar existentes
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  inserted_count integer := 0;
  updated_count integer := 0;
  staging_count integer := 0;
  use_stg_items boolean := false;
  stg_table_name text;
  stg_items_count integer := 0;
  stg_update_count integer := 0;
  has_collection_name_col boolean := false;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migrando datos desde tabla temporal a CatalogItems';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Verificar qué tabla temporal tiene datos
  -- ====================================================
  RAISE NOTICE '📋 Verificando tablas de staging...';
  
  -- Verificar si _stg_catalog_items existe y tiene datos
  BEGIN
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = '_stg_catalog_items'
    ) THEN
      SELECT COUNT(*) INTO stg_items_count
      FROM public."_stg_catalog_items"
      WHERE sku IS NOT NULL AND trim(sku) <> '';
      RAISE NOTICE '   ℹ️  Tabla _stg_catalog_items existe con % registros válidos', stg_items_count;
    ELSE
      RAISE NOTICE '   ⚠️  Tabla _stg_catalog_items NO existe';
      stg_items_count := 0;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '   ⚠️  Error al verificar _stg_catalog_items: %', SQLERRM;
    stg_items_count := 0;
  END;
  
  -- Verificar si _stg_catalog_update existe y tiene datos
  BEGIN
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = '_stg_catalog_update'
    ) THEN
      BEGIN
        -- Contar registros con SKU válido
        SELECT COUNT(*) INTO stg_update_count
        FROM public."_stg_catalog_update"
        WHERE sku IS NOT NULL 
          AND trim(COALESCE(sku, '')) <> '';
        RAISE NOTICE '   ℹ️  Tabla _stg_catalog_update existe con % registros válidos', stg_update_count;
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '   ⚠️  Error al contar registros en _stg_catalog_update: %', SQLERRM;
        RAISE WARNING '   Detalle del error: %', SQLSTATE;
        -- Intentar contar total sin filtro
        BEGIN
          SELECT COUNT(*) INTO stg_update_count
          FROM public."_stg_catalog_update";
          RAISE WARNING '   ℹ️  Total de registros en _stg_catalog_update (sin filtrar SKU): %', stg_update_count;
        EXCEPTION WHEN OTHERS THEN
          RAISE WARNING '   ⚠️  Error al contar total de registros: %', SQLERRM;
          stg_update_count := 0;
        END;
      END;
    ELSE
      RAISE NOTICE '   ⚠️  Tabla _stg_catalog_update NO existe';
      stg_update_count := 0;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '   ⚠️  Error al verificar existencia de _stg_catalog_update: %', SQLERRM;
    stg_update_count := 0;
  END;
  
  -- Priorizar _stg_catalog_items si tiene datos
  IF stg_items_count > 0 THEN
    use_stg_items := true;
    staging_count := stg_items_count;
    stg_table_name := '_stg_catalog_items';
    RAISE NOTICE '';
    RAISE NOTICE '   ✅ Usando _stg_catalog_items como fuente de datos (% registros)', stg_items_count;
  ELSIF stg_update_count > 0 THEN
    use_stg_items := false;
    staging_count := stg_update_count;
    stg_table_name := '_stg_catalog_update';
    RAISE NOTICE '';
    RAISE NOTICE '   ✅ Usando _stg_catalog_update como fuente de datos (% registros)', stg_update_count;
  ELSE
    RAISE WARNING '';
    RAISE WARNING '========================================';
    RAISE WARNING '⚠️  ERROR: No se encontraron datos en las tablas de staging';
    RAISE WARNING '========================================';
    RAISE WARNING '';
    RAISE WARNING 'Diagnóstico:';
    RAISE WARNING '  - _stg_catalog_items: % registros', stg_items_count;
    RAISE WARNING '  - _stg_catalog_update: % registros', stg_update_count;
    RAISE WARNING '';
    RAISE WARNING 'Instrucciones:';
    RAISE WARNING '1. Ve a Supabase Table Editor';
    RAISE WARNING '2. Verifica que exista una de estas tablas:';
    RAISE WARNING '   - _stg_catalog_items';
    RAISE WARNING '   - _stg_catalog_update';
    RAISE WARNING '3. Si no existe, créala primero (usa el script 61_create_staging_table.sql)';
    RAISE WARNING '4. Importa el CSV a la tabla usando "Import data from CSV"';
    RAISE WARNING '5. Asegúrate de que la columna "sku" tenga datos válidos';
    RAISE WARNING '6. Vuelve a ejecutar este script';
    RAISE WARNING '';
    RAISE EXCEPTION 'Script detenido: no se encontraron datos en las tablas de staging.';
  END IF;

  -- ====================================================
  -- STEP 2: Migrar datos usando INSERT ... ON CONFLICT DO UPDATE
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📥 Migrando datos a CatalogItems...';

  IF use_stg_items THEN
    -- Migrar desde _stg_catalog_items
    -- Primero eliminar duplicados usando DISTINCT ON antes de los JOINs
    WITH unique_staging AS (
      SELECT DISTINCT ON (trim(COALESCE(sku, '')))
        trim(COALESCE(sku, '')) as sku,
        trim(COALESCE(collection_name, '')) as collection_name,
        trim(COALESCE(variant_name, '')) as variant_name,
        trim(COALESCE(item_name, '')) as item_name,
        trim(COALESCE(item_description, '')) as item_description,
        trim(COALESCE(item_type, '')) as item_type,
        trim(COALESCE(measure_basis, 'unit')) as measure_basis,
        trim(COALESCE(uom, 'PCS')) as uom,
        CASE 
          WHEN is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE false
        END as is_fabric,
        CASE 
          WHEN COALESCE(roll_width_m, '') <> '' 
            AND trim(roll_width_m) ~ '^[0-9]+\.?[0-9]*$'
          THEN roll_width_m::numeric
          ELSE NULL
        END as roll_width_m,
        CASE 
          WHEN COALESCE(cost_exw, '') <> '' 
            AND trim(cost_exw) ~ '^[0-9]+\.?[0-9]*$'
          THEN cost_exw::numeric
          ELSE 0
        END as cost_exw,
        CASE 
          WHEN active::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN active::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE true
        END as active,
        CASE 
          WHEN discontinued::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN discontinued::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE false
        END as discontinued,
        trim(COALESCE(manufacturer, '')) as manufacturer,
        trim(COALESCE(category, '')) as category,
        trim(COALESCE(family, '')) as family
      FROM public."_stg_catalog_items"
      WHERE sku IS NOT NULL AND trim(sku) <> ''
      ORDER BY trim(COALESCE(sku, '')), ctid DESC
    ),
    staging_data AS (
      SELECT DISTINCT ON (s.sku)
        s.sku,
        s.collection_name,
        s.variant_name,
        s.item_name,
        s.item_description,
        s.item_type,
        s.measure_basis,
        s.uom,
        s.is_fabric,
        s.roll_width_m,
        s.cost_exw,
        s.active,
        s.discontinued,
        COALESCE(m.id, NULL) as manufacturer_id,
        COALESCE(ic.id, NULL) as item_category_id,
        s.family
      FROM unique_staging s
      LEFT JOIN public."Manufacturers" m
        ON lower(m.name) = lower(s.manufacturer)
        AND m.organization_id = target_org_id
        AND m.deleted = false
      LEFT JOIN public."ItemCategories" ic
        ON lower(ic.name) = lower(s.category)
        AND ic.organization_id = target_org_id
        AND ic.deleted = false
      WHERE s.sku IS NOT NULL AND trim(s.sku) <> ''
      ORDER BY s.sku, m.id NULLS LAST, ic.id NULLS LAST
    )
    INSERT INTO public."CatalogItems" (
      organization_id,
      sku,
      collection_name,
      variant_name,
      item_name,
      description,
      item_type,
      measure_basis,
      uom,
      is_fabric,
      roll_width_m,
      cost_exw,
      active,
      discontinued,
      manufacturer_id,
      item_category_id,
      family
    )
    SELECT 
      target_org_id,
      s.sku,
      CASE WHEN s.collection_name <> '' THEN s.collection_name ELSE NULL END,
      CASE WHEN s.variant_name <> '' THEN s.variant_name ELSE NULL END,
      s.item_name,
      s.item_description,
      s.item_type,
      s.measure_basis,
      s.uom,
      s.is_fabric,
      s.roll_width_m,
      s.cost_exw,
      s.active,
      s.discontinued,
      s.manufacturer_id,
      s.item_category_id,
      CASE WHEN s.family <> '' THEN s.family ELSE NULL END
    FROM staging_data s
    WHERE s.sku IS NOT NULL AND trim(s.sku) <> ''
    ON CONFLICT (organization_id, sku) WHERE deleted = false
    DO UPDATE SET
      collection_name = CASE 
        WHEN EXCLUDED.collection_name IS NOT NULL AND trim(EXCLUDED.collection_name) <> '' 
        THEN EXCLUDED.collection_name 
        ELSE CatalogItems.collection_name 
      END,
      variant_name = CASE 
        WHEN EXCLUDED.variant_name IS NOT NULL AND trim(EXCLUDED.variant_name) <> '' 
        THEN EXCLUDED.variant_name 
        ELSE CatalogItems.variant_name 
      END,
      item_name = EXCLUDED.item_name,
      description = EXCLUDED.description,
      item_type = EXCLUDED.item_type,
      measure_basis = EXCLUDED.measure_basis,
      uom = EXCLUDED.uom,
      is_fabric = EXCLUDED.is_fabric,
      roll_width_m = EXCLUDED.roll_width_m,
      cost_exw = EXCLUDED.cost_exw,
      active = EXCLUDED.active,
      discontinued = EXCLUDED.discontinued,
      manufacturer_id = EXCLUDED.manufacturer_id,
      item_category_id = EXCLUDED.item_category_id,
      family = EXCLUDED.family,
      updated_at = NOW();

    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Migrados % registros desde _stg_catalog_items', inserted_count;

  ELSE
    -- Migrar desde _stg_catalog_update
    -- Columnas confirmadas: sku, collection_name, variant_name, item_name, item_description, 
    -- item_type, measure_basis, uom, is_fabric, roll_width_m, cost_exw, active, discontinued, 
    -- manufacturer, category, family
    -- Primero eliminar duplicados usando DISTINCT ON antes de los JOINs
    WITH unique_staging AS (
      SELECT DISTINCT ON (trim(COALESCE(sku, '')))
        trim(COALESCE(sku, '')) as sku,
        trim(COALESCE(collection_name, '')) as collection_name,
        trim(COALESCE(variant_name, '')) as variant_name,
        trim(COALESCE(item_name, '')) as item_name,
        trim(COALESCE(item_description, '')) as item_description,
        trim(COALESCE(item_type, '')) as item_type,
        trim(COALESCE(measure_basis, 'unit')) as measure_basis,
        trim(COALESCE(uom, 'PCS')) as uom,
        CASE 
          WHEN is_fabric::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN is_fabric::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE false
        END as is_fabric,
        CASE 
          WHEN COALESCE(roll_width_m, '') <> '' 
            AND trim(roll_width_m) ~ '^[0-9]+\.?[0-9]*$'
          THEN roll_width_m::numeric
          ELSE NULL
        END as roll_width_m,
        CASE 
          WHEN COALESCE(cost_exw, '') <> '' 
            AND trim(cost_exw) ~ '^[0-9]+\.?[0-9]*$'
          THEN cost_exw::numeric
          ELSE 0
        END as cost_exw,
        CASE 
          WHEN active::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN active::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE true
        END as active,
        CASE 
          WHEN discontinued::text IN ('TRUE', 'true', 'True', '1', 't') THEN true
          WHEN discontinued::text IN ('FALSE', 'false', 'False', '0', 'f', '') THEN false
          ELSE false
        END as discontinued,
        trim(COALESCE(manufacturer, '')) as manufacturer,
        trim(COALESCE(category, '')) as category,
        trim(COALESCE(family, '')) as family
      FROM public."_stg_catalog_update" s
      WHERE s.sku IS NOT NULL AND trim(s.sku) <> ''
      ORDER BY trim(COALESCE(s.sku, '')), s.ctid DESC
    ),
    staging_data AS (
      SELECT DISTINCT ON (s.sku)
        s.sku,
        s.collection_name,
        s.variant_name,
        s.item_name,
        s.item_description,
        s.item_type,
        s.measure_basis,
        s.uom,
        s.is_fabric,
        s.roll_width_m,
        s.cost_exw,
        s.active,
        s.discontinued,
        COALESCE(m.id, NULL) as manufacturer_id,
        COALESCE(ic.id, NULL) as item_category_id,
        s.family
      FROM unique_staging s
      LEFT JOIN public."Manufacturers" m
        ON lower(m.name) = lower(s.manufacturer)
        AND m.organization_id = target_org_id
        AND m.deleted = false
      LEFT JOIN public."ItemCategories" ic
        ON lower(ic.name) = lower(s.category)
        AND ic.organization_id = target_org_id
        AND ic.deleted = false
      WHERE s.sku IS NOT NULL AND trim(s.sku) <> ''
      ORDER BY s.sku, m.id NULLS LAST, ic.id NULLS LAST
    )
    INSERT INTO public."CatalogItems" (
      organization_id,
      sku,
      collection_name,
      variant_name,
      item_name,
      description,
      item_type,
      measure_basis,
      uom,
      is_fabric,
      roll_width_m,
      cost_exw,
      active,
      discontinued,
      manufacturer_id,
      item_category_id,
      family
    )
    SELECT 
      target_org_id,
      s.sku,
      CASE WHEN s.collection_name <> '' THEN s.collection_name ELSE NULL END,
      CASE WHEN s.variant_name <> '' THEN s.variant_name ELSE NULL END,
      s.item_name,
      s.item_description,
      s.item_type,
      s.measure_basis,
      s.uom,
      s.is_fabric,
      s.roll_width_m,
      s.cost_exw,
      s.active,
      s.discontinued,
      s.manufacturer_id,
      s.item_category_id,
      CASE WHEN s.family <> '' THEN s.family ELSE NULL END
    FROM staging_data s
    WHERE s.sku IS NOT NULL AND trim(s.sku) <> ''
    ON CONFLICT (organization_id, sku) WHERE deleted = false
    DO UPDATE SET
      collection_name = CASE 
        WHEN EXCLUDED.collection_name IS NOT NULL AND trim(EXCLUDED.collection_name) <> '' 
        THEN EXCLUDED.collection_name 
        ELSE CatalogItems.collection_name 
      END,
      variant_name = CASE 
        WHEN EXCLUDED.variant_name IS NOT NULL AND trim(EXCLUDED.variant_name) <> '' 
        THEN EXCLUDED.variant_name 
        ELSE CatalogItems.variant_name 
      END,
      item_name = EXCLUDED.item_name,
      description = EXCLUDED.description,
      item_type = EXCLUDED.item_type,
      measure_basis = EXCLUDED.measure_basis,
      uom = EXCLUDED.uom,
      is_fabric = EXCLUDED.is_fabric,
      roll_width_m = EXCLUDED.roll_width_m,
      cost_exw = EXCLUDED.cost_exw,
      active = EXCLUDED.active,
      discontinued = EXCLUDED.discontinued,
      manufacturer_id = EXCLUDED.manufacturer_id,
      item_category_id = EXCLUDED.item_category_id,
      family = EXCLUDED.family,
      updated_at = NOW();

    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Migrados % registros desde _stg_catalog_update', inserted_count;
  END IF;

  -- ====================================================
  -- STEP 3: Resumen final
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Migración completada';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total de registros procesados: %', inserted_count;
  RAISE NOTICE '';

END $$;

