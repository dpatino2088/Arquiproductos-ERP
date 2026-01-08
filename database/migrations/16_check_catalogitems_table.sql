-- ====================================================
-- Script de diagnóstico: Verificar si CatalogItems existe
-- ====================================================

DO $$
DECLARE
  rec RECORD;
  table_count integer;
BEGIN
  RAISE NOTICE '🔍 Verificando existencia de tabla CatalogItems...';
  RAISE NOTICE '';

  -- Buscar tablas que contengan "catalog" o "item"
  RAISE NOTICE '📋 Tablas relacionadas con catalog/item:';
  FOR rec IN 
    SELECT 
      table_name,
      table_schema
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND (
        lower(table_name) LIKE '%catalog%' 
        OR lower(table_name) LIKE '%item%'
      )
    ORDER BY table_name
  LOOP
    RAISE NOTICE '   - % (schema: %)', rec.table_name, rec.table_schema;
  END LOOP;

  RAISE NOTICE '';
  
  -- Verificar específicamente CatalogItems
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name = 'CatalogItems';

  IF table_count > 0 THEN
    RAISE NOTICE '✅ La tabla CatalogItems EXISTE';
    
    -- Mostrar columnas
    RAISE NOTICE '';
    RAISE NOTICE '📋 Columnas de CatalogItems:';
    FOR rec IN 
      SELECT 
        column_name,
        data_type,
        is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'CatalogItems'
      ORDER BY ordinal_position
    LOOP
      RAISE NOTICE '   - % (% - nullable: %)', rec.column_name, rec.data_type, rec.is_nullable;
    END LOOP;
  ELSE
    RAISE WARNING '⚠️  La tabla CatalogItems NO EXISTE';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Necesitas crear la tabla primero.';
    RAISE NOTICE '   Busca el script de creación en: create_catalog_and_quotes_tables.sql';
  END IF;

END $$;















