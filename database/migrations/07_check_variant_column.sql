-- ====================================================
-- Script para verificar el nombre de la columna variant
-- ====================================================
-- Este script verifica cómo se llama realmente la columna variant
-- en el staging table después de la importación del CSV

DO $$
DECLARE
  column_name text;
  variant_count integer;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔍 Checking variant column name in staging table...';

  -- Verificar si existe el staging table
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE EXCEPTION 'Staging table _stg_catalog_items does not exist. Please import CSV first.';
  END IF;

  -- Buscar la columna variant (puede ser "variant" o "Variant")
  SELECT column_name INTO column_name
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = '_stg_catalog_items'
    AND (lower(column_name) = 'variant');

  IF column_name IS NULL THEN
    RAISE EXCEPTION 'Column variant not found in staging table. Available columns: %', 
      (SELECT string_agg(column_name, ', ') 
       FROM information_schema.columns 
       WHERE table_schema = 'public' 
       AND table_name = '_stg_catalog_items');
  END IF;

  RAISE NOTICE '✅ Found column: "%"', column_name;

  -- Contar registros con variant no nulo
  EXECUTE format('SELECT COUNT(*) FROM public."_stg_catalog_items" WHERE %I IS NOT NULL AND trim(%I) <> ''''', 
    column_name, column_name) INTO variant_count;
  
  RAISE NOTICE '📊 Records with variant value: %', variant_count;

  -- Mostrar algunos ejemplos
  RAISE NOTICE '';
  RAISE NOTICE '📋 Sample records with variant:';
  FOR rec IN 
    EXECUTE format('SELECT sku, %I as variant_value, is_fabric, collection FROM public."_stg_catalog_items" WHERE %I IS NOT NULL AND trim(%I) <> '''' LIMIT 10', 
      column_name, column_name, column_name)
  LOOP
    RAISE NOTICE '  - SKU: %, Variant: %, is_fabric: %, Collection: %', 
      rec.sku, rec.variant_value, rec.is_fabric, rec.collection;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Column check completed!';
  RAISE NOTICE '   Use column name: "%" in your import scripts', column_name;

END $$;





