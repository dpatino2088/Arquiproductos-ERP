-- ====================================================
-- Script para eliminar FK de collection_id y usar collection_name
-- ====================================================
-- Este script:
-- 1. Elimina la FK constraint de collection_id
-- 2. Agrega collection_name como text (si no existe)
-- 3. Mantiene collection_id por compatibilidad (pero sin FK)
-- ====================================================

DO $$
DECLARE
  rec RECORD;
  constraint_name_var text;
  table_exists boolean;
  table_name_var text;
BEGIN
  RAISE NOTICE '🔧 Eliminando FK de collection_id y agregando collection_name...';

  -- ====================================================
  -- STEP 0: Verificar que la tabla existe
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) INTO table_exists;

  IF NOT table_exists THEN
    RAISE EXCEPTION 'La tabla CatalogItems no existe. Por favor crea la tabla primero.';
  END IF;

  RAISE NOTICE '✅ Tabla CatalogItems encontrada';

  -- ====================================================
  -- STEP 1: Eliminar todas las FK constraints relacionadas con collection_id
  -- ====================================================
  FOR rec IN 
    SELECT 
      tc.constraint_name,
      tc.table_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'CatalogItems'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.column_name = 'collection_id'
  LOOP
    EXECUTE format('ALTER TABLE public."CatalogItems" DROP CONSTRAINT IF EXISTS %I CASCADE', rec.constraint_name);
    RAISE NOTICE '✅ Eliminada FK constraint: %', rec.constraint_name;
  END LOOP;

  -- ====================================================
  -- STEP 2: Agregar collection_name si no existe
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public'
      AND table_name = 'CatalogItems' 
      AND column_name = 'collection_name'
  ) THEN
    BEGIN
      EXECUTE 'ALTER TABLE public."CatalogItems" ADD COLUMN collection_name text';
      RAISE NOTICE '✅ Agregada columna collection_name';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '⚠️  Error al agregar collection_name: %', SQLERRM;
      RAISE;
    END;
  ELSE
    RAISE NOTICE 'ℹ️  La columna collection_name ya existe';
  END IF;

  -- ====================================================
  -- STEP 3: Verificación
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verificación:';
  
  -- Verificar que collection_name existe
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public'
      AND table_name = 'CatalogItems' 
      AND column_name = 'collection_name'
  ) THEN
    RAISE NOTICE '   ✅ collection_name existe';
  ELSE
    RAISE WARNING '   ⚠️  collection_name NO existe';
  END IF;

  -- Verificar que no hay FK constraints en collection_id
  SELECT COUNT(*) INTO constraint_name_var
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
  WHERE tc.table_schema = 'public'
    AND tc.table_name = 'CatalogItems'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'collection_id';

  IF constraint_name_var::integer = 0 THEN
    RAISE NOTICE '   ✅ No hay FK constraints en collection_id';
  ELSE
    RAISE WARNING '   ⚠️  Aún existen % FK constraints en collection_id', constraint_name_var;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Cambios completados!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Nota: collection_id se mantiene por compatibilidad pero ya no tiene FK.';
  RAISE NOTICE '   Usa collection_name para almacenar el nombre de la colección directamente.';

END $$;

