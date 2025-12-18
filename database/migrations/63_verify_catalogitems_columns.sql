-- ====================================================
-- Migration 63: Verify CatalogItems Columns
-- ====================================================
-- Este script verifica que todas las columnas necesarias existan
-- y las crea si no existen
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Verificando columnas en CatalogItems';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Verificar y agregar collection_name
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'collection_name'
  ) THEN
    RAISE NOTICE '📝 Agregando columna collection_name...';
    ALTER TABLE public."CatalogItems"
      ADD COLUMN collection_name text;
    CREATE INDEX IF NOT EXISTS idx_catalog_items_collection_name 
      ON "CatalogItems"(collection_name) 
      WHERE collection_name IS NOT NULL;
    RAISE NOTICE '✅ Columna collection_name agregada';
  ELSE
    RAISE NOTICE '✅ Columna collection_name ya existe';
  END IF;

  -- Verificar y agregar variant_name
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'variant_name'
  ) THEN
    RAISE NOTICE '📝 Agregando columna variant_name...';
    ALTER TABLE public."CatalogItems"
      ADD COLUMN variant_name text;
    RAISE NOTICE '✅ Columna variant_name agregada';
  ELSE
    RAISE NOTICE '✅ Columna variant_name ya existe';
  END IF;

  -- Verificar y agregar roll_width_m
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'roll_width_m'
  ) THEN
    RAISE NOTICE '📝 Agregando columna roll_width_m...';
    ALTER TABLE public."CatalogItems"
      ADD COLUMN roll_width_m numeric(10, 3);
    RAISE NOTICE '✅ Columna roll_width_m agregada';
  ELSE
    RAISE NOTICE '✅ Columna roll_width_m ya existe';
  END IF;

  -- Verificar y agregar cost_exw
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'cost_exw'
  ) THEN
    RAISE NOTICE '📝 Agregando columna cost_exw...';
    ALTER TABLE public."CatalogItems"
      ADD COLUMN cost_exw numeric(12, 2) NOT NULL DEFAULT 0;
    RAISE NOTICE '✅ Columna cost_exw agregada';
  ELSE
    RAISE NOTICE '✅ Columna cost_exw ya existe';
  END IF;

  -- Verificar y agregar family
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'family'
  ) THEN
    RAISE NOTICE '📝 Agregando columna family...';
    ALTER TABLE public."CatalogItems"
      ADD COLUMN family text;
    CREATE INDEX IF NOT EXISTS idx_catalog_items_family 
      ON "CatalogItems"(family) 
      WHERE family IS NOT NULL;
    RAISE NOTICE '✅ Columna family agregada';
  ELSE
    RAISE NOTICE '✅ Columna family ya existe';
  END IF;

  -- Verificar collection_id (puede ser NULL, solo verificamos que exista)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'collection_id'
  ) THEN
    RAISE NOTICE '📝 Agregando columna collection_id...';
    ALTER TABLE public."CatalogItems"
      ADD COLUMN collection_id uuid;
    RAISE NOTICE '✅ Columna collection_id agregada';
  ELSE
    RAISE NOTICE '✅ Columna collection_id ya existe';
  END IF;

  -- Mostrar resumen de columnas
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen de columnas en CatalogItems:';
  
  DECLARE
    col_name text;
  BEGIN
    FOR col_name IN (
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems'
        AND column_name IN ('collection_name', 'variant_name', 'roll_width_m', 'cost_exw', 'family', 'collection_id')
      ORDER BY column_name
    ) LOOP
      RAISE NOTICE '   ✅ %', col_name;
    END LOOP;
  END;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Verificación completada!';
  RAISE NOTICE '';

END $$;

