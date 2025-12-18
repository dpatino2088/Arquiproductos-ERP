-- ====================================================
-- Script para listar NOMBRES de columnas de la tabla temporal
-- ====================================================
-- Este script muestra SOLO los nombres exactos de las columnas
-- de _stg_catalog_items (como están en la base de datos)
-- 
-- INSTRUCCIONES:
-- 1. Ejecuta este script en Supabase SQL Editor
-- 2. Revisa los resultados en la consola/notices
-- 3. Copia los nombres exactos para el script de migración
-- ====================================================

DO $$
DECLARE
  rec RECORD;
  column_count integer;
  column_names text := '';
BEGIN
  RAISE NOTICE '🔍 Listando NOMBRES de columnas de _stg_catalog_items...';
  RAISE NOTICE '';

  -- Verificar que la tabla existe
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE EXCEPTION 'La tabla _stg_catalog_items no existe. Por favor importa el CSV primero.';
  END IF;

  -- Contar columnas
  SELECT COUNT(*) INTO column_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = '_stg_catalog_items';

  RAISE NOTICE '📊 Total de columnas: %', column_count;
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'NOMBRES DE COLUMNAS (en orden):';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';

  -- Listar SOLO los nombres de las columnas
  FOR rec IN 
    SELECT 
      column_name,
      ordinal_position
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = '_stg_catalog_items'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '%2s. %s', rec.ordinal_position, rec.column_name;
  END LOOP;

  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';

  -- Mostrar también la lista en formato SQL (para copiar y pegar)
  RAISE NOTICE '📋 Lista de columnas para usar en SQL:';
  RAISE NOTICE '';
  
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
  INTO column_names
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = '_stg_catalog_items';
  
  RAISE NOTICE '%', column_names;
  RAISE NOTICE '';

  RAISE NOTICE '✅ Listado completado!';

END $$;

