-- ====================================================
-- Script de Diagnóstico: Verificar Tablas de Staging
-- ====================================================
-- Este script verifica qué tablas de staging existen
-- y cuántos registros tienen
-- ====================================================

DO $$
DECLARE
  table_exists boolean;
  record_count integer;
  tbl_name text;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Diagnóstico de Tablas de Staging';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

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
      RAISE NOTICE '✅ Tabla % existe', tbl_name;
      RAISE NOTICE '   Registros con SKU válido: %', record_count;
      
      -- Verificar columnas importantes
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'collection_name'
      ) THEN
        RAISE NOTICE '   ✅ Columna collection_name existe';
      ELSE
        RAISE NOTICE '   ⚠️  Columna collection_name NO existe';
      END IF;
      
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'cost_exw'
      ) THEN
        RAISE NOTICE '   ✅ Columna cost_exw existe';
      ELSE
        RAISE NOTICE '   ⚠️  Columna cost_exw NO existe';
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '   ⚠️  Error al contar registros: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE '❌ Tabla % NO existe', tbl_name;
  END IF;

  RAISE NOTICE '';

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
      RAISE NOTICE '✅ Tabla % existe', tbl_name;
      RAISE NOTICE '   Registros con SKU válido: %', record_count;
      
      -- Verificar columnas importantes
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'collection_name'
      ) THEN
        RAISE NOTICE '   ✅ Columna collection_name existe';
      ELSE
        RAISE NOTICE '   ⚠️  Columna collection_name NO existe';
      END IF;
      
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = tbl_name
        AND column_name = 'cost_exw'
      ) THEN
        RAISE NOTICE '   ✅ Columna cost_exw existe';
      ELSE
        RAISE NOTICE '   ⚠️  Columna cost_exw NO existe';
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '   ⚠️  Error al contar registros: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE '❌ Tabla % NO existe', tbl_name;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Instrucciones:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Si ninguna tabla existe o está vacía:';
  RAISE NOTICE '1. Ve a Supabase Table Editor';
  RAISE NOTICE '2. Crea la tabla _stg_catalog_update (o usa el script 61_create_staging_table.sql)';
  RAISE NOTICE '3. Importa tu CSV usando "Import data from CSV"';
  RAISE NOTICE '4. Asegúrate de que la columna "sku" tenga datos';
  RAISE NOTICE '5. Vuelve a ejecutar el script de migración';
  RAISE NOTICE '';

END $$;

