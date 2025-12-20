-- ====================================================
-- Migration 62: Add family column to CatalogItems
-- ====================================================
-- Este script agrega la columna family a CatalogItems
-- para almacenar la familia de productos del CSV
-- ====================================================

DO $$
BEGIN
  -- Agregar columna family si no existe
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'family'
  ) THEN
    RAISE NOTICE '📝 Agregando columna family a CatalogItems...';
    
    ALTER TABLE public."CatalogItems"
      ADD COLUMN IF NOT EXISTS family text;

    -- Crear índice para búsquedas por family
    CREATE INDEX IF NOT EXISTS idx_catalog_items_family 
      ON "CatalogItems"(family) 
      WHERE family IS NOT NULL;

    RAISE NOTICE '✅ Columna family agregada a CatalogItems';
  ELSE
    RAISE NOTICE 'ℹ️  La columna family ya existe en CatalogItems';
  END IF;

END $$;





