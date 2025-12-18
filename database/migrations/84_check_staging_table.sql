-- ====================================================
-- Migration 84: Verificar estado de tabla de staging
-- ====================================================

DO $$
DECLARE
  staging_count integer := 0;
  staging_exists boolean := false;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICACIÓN DE TABLA DE STAGING';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Verificar _stg_catalog_items
  BEGIN
    SELECT COUNT(*) INTO staging_count
    FROM public."_stg_catalog_items"
    WHERE sku IS NOT NULL AND trim(sku) <> '';
    staging_exists := true;
    RAISE NOTICE '✅ Tabla _stg_catalog_items existe';
    RAISE NOTICE '   Registros con SKU válido: %', staging_count;
    
    IF staging_count = 0 THEN
      RAISE WARNING '   ⚠️  La tabla está vacía o no tiene SKUs válidos';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '   ⚠️  Tabla _stg_catalog_items NO existe: %', SQLERRM;
  END;

  RAISE NOTICE '';

  -- Verificar _stg_catalog_update
  BEGIN
    SELECT COUNT(*) INTO staging_count
    FROM public."_stg_catalog_update"
    WHERE sku IS NOT NULL AND trim(sku) <> '';
    RAISE NOTICE '✅ Tabla _stg_catalog_update existe';
    RAISE NOTICE '   Registros con SKU válido: %', staging_count;
    
    IF staging_count = 0 THEN
      RAISE WARNING '   ⚠️  La tabla está vacía o no tiene SKUs válidos';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '   ⚠️  Tabla _stg_catalog_update NO existe: %', SQLERRM;
  END;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'INSTRUCCIONES:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Si las tablas están vacías, necesitas:';
  RAISE NOTICE '   1. Ejecutar el script 83 para crear la tabla';
  RAISE NOTICE '   2. Importar el CSV usando Table Editor o COPY';
  RAISE NOTICE '   3. Luego ejecutar el script 82 para actualizar categorías';
  RAISE NOTICE '';

END $$;

-- Mostrar algunos registros de ejemplo si existen
SELECT 
  sku,
  item_name,
  item_category_id,
  item_description
FROM public."_stg_catalog_items"
WHERE sku IS NOT NULL 
  AND trim(sku) <> ''
  AND item_category_id IS NOT NULL
LIMIT 10;

