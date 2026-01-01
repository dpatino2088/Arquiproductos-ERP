-- ====================================================
-- Script de Diagnóstico: Verificar Tablas de Staging (Versión con Resultados)
-- ====================================================
-- Este script verifica qué tablas de staging existen
-- y cuántos registros tienen, devolviendo resultados en una tabla
-- ====================================================

-- Crear tabla temporal para resultados
CREATE TEMP TABLE IF NOT EXISTS staging_diagnostic_results (
  tabla text,
  existe boolean,
  registros_validos integer,
  tiene_collection_name boolean,
  tiene_cost_exw boolean,
  mensaje text
);

-- Limpiar resultados anteriores
TRUNCATE TABLE staging_diagnostic_results;

DO $$
DECLARE
  table_exists boolean;
  record_count integer;
  tbl_name text;
  has_collection_name boolean;
  has_cost_exw boolean;
BEGIN
  -- Verificar _stg_catalog_items
  tbl_name := '_stg_catalog_items';
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = tbl_name
  ) INTO table_exists;

  IF table_exists THEN
    BEGIN
      EXECUTE format('SELECT COUNT(*) FROM public.%I WHERE sku IS NOT NULL AND trim(sku) <> ''', tbl_name) INTO record_count;
      
      SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'collection_name'
      ) INTO has_collection_name;
      
      SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'cost_exw'
      ) INTO has_cost_exw;
      
      INSERT INTO staging_diagnostic_results VALUES (
        tbl_name,
        true,
        record_count,
        has_collection_name,
        has_cost_exw,
        format('Tabla existe con %s registros válidos', record_count)
      );
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO staging_diagnostic_results VALUES (
        tbl_name,
        true,
        NULL,
        false,
        false,
        format('Error: %s', SQLERRM)
      );
    END;
  ELSE
    INSERT INTO staging_diagnostic_results VALUES (
      tbl_name,
      false,
      0,
      false,
      false,
      'Tabla NO existe'
    );
  END IF;

  -- Verificar _stg_catalog_update
  tbl_name := '_stg_catalog_update';
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = tbl_name
  ) INTO table_exists;

  IF table_exists THEN
    BEGIN
      EXECUTE format('SELECT COUNT(*) FROM public.%I WHERE sku IS NOT NULL AND trim(sku) <> ''', tbl_name) INTO record_count;
      
      SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'collection_name'
      ) INTO has_collection_name;
      
      SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'cost_exw'
      ) INTO has_cost_exw;
      
      INSERT INTO staging_diagnostic_results VALUES (
        tbl_name,
        true,
        record_count,
        has_collection_name,
        has_cost_exw,
        format('Tabla existe con %s registros válidos', record_count)
      );
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO staging_diagnostic_results VALUES (
        tbl_name,
        true,
        NULL,
        false,
        false,
        format('Error: %s', SQLERRM)
      );
    END;
  ELSE
    INSERT INTO staging_diagnostic_results VALUES (
      tbl_name,
      false,
      0,
      false,
      false,
      'Tabla NO existe'
    );
  END IF;

END $$;

-- Mostrar resultados
SELECT 
  tabla as "Tabla",
  CASE 
    WHEN existe THEN '✅ Sí' 
    ELSE '❌ No' 
  END as "Existe",
  COALESCE(registros_validos::text, 'N/A') as "Registros Válidos",
  CASE 
    WHEN tiene_collection_name THEN '✅ Sí' 
    ELSE '❌ No' 
  END as "Tiene collection_name",
  CASE 
    WHEN tiene_cost_exw THEN '✅ Sí' 
    ELSE '❌ No' 
  END as "Tiene cost_exw",
  mensaje as "Estado"
FROM staging_diagnostic_results
ORDER BY tabla;

-- Mostrar recomendaciones
SELECT 
  CASE 
    WHEN COUNT(*) FILTER (WHERE existe = true AND registros_validos > 0) = 0 THEN
      '⚠️  No se encontraron tablas con datos. Por favor:' || E'\n' ||
      '1. Ve a Supabase Table Editor' || E'\n' ||
      '2. Crea la tabla _stg_catalog_update (o usa el script 61_create_staging_table.sql)' || E'\n' ||
      '3. Importa tu CSV usando "Import data from CSV"' || E'\n' ||
      '4. Asegúrate de que la columna "sku" tenga datos' || E'\n' ||
      '5. Vuelve a ejecutar el script de migración'
    WHEN COUNT(*) FILTER (WHERE existe = true AND registros_validos > 0) > 0 THEN
      '✅ Se encontraron tablas con datos. Puedes ejecutar el script de migración 65_migrate_staging_to_catalogitems.sql'
    ELSE
      '⚠️  Las tablas existen pero no tienen registros válidos'
  END as "Recomendación"
FROM staging_diagnostic_results;








