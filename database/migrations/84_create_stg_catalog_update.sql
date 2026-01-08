-- ====================================================
-- Migration 84: Create _stg_catalog_update table
-- ====================================================
-- Este script crea la tabla _stg_catalog_update para importar CSV
-- con todas las columnas necesarias según el CSV final
-- ====================================================

DO $$
BEGIN
  -- Crear tabla staging si no existe
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_update'
  ) THEN
    RAISE NOTICE '📋 Creando tabla _stg_catalog_update...';
    
    CREATE TABLE IF NOT EXISTS public."_stg_catalog_update" (
      -- Identificadores
      sku text,
      collection_name text,
      variant_name text,
      item_name text,
      item_description text,
      
      -- Tipos y medidas
      item_type text,
      measure_basis text,
      uom text,
      
      -- Fabric specific
      is_fabric text, -- Se convierte a boolean después
      roll_width_m text, -- Text para manejar valores numéricos como texto
      
      -- Pricing
      cost_exw text, -- Text para manejar valores numéricos como texto
      
      -- Status
      active text, -- Se convierte a boolean después
      discontinued text, -- Se convierte a boolean después
      
      -- Relaciones
      manufacturer text,
      category text, -- Nombre de la categoría (será mapeado a ItemCategories)
      family text -- Para agrupar productos (opcional)
    );

    -- Crear índice en SKU para mejorar el rendimiento
    CREATE INDEX IF NOT EXISTS idx_stg_catalog_update_sku 
    ON public."_stg_catalog_update"(sku) 
    WHERE sku IS NOT NULL AND trim(sku) <> '';

    RAISE NOTICE '✅ Tabla _stg_catalog_update creada';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Próximos pasos:';
    RAISE NOTICE '   1. Ve a Supabase Table Editor';
    RAISE NOTICE '   2. Selecciona la tabla _stg_catalog_update';
    RAISE NOTICE '   3. Haz clic en "Import data from CSV"';
    RAISE NOTICE '   4. Sube tu archivo CSV (catalog_items_import_DP_COLLECTIONS_VARIANT FINALFINAL.csv)';
    RAISE NOTICE '   5. Ejecuta el script 65_migrate_staging_to_catalogitems.sql';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE 'ℹ️  La tabla _stg_catalog_update ya existe';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Verificando datos en staging...';
    
    DECLARE
      row_count integer;
      valid_sku_count integer;
    BEGIN
      SELECT COUNT(*) INTO row_count
      FROM public."_stg_catalog_update";
      
      SELECT COUNT(*) INTO valid_sku_count
      FROM public."_stg_catalog_update"
      WHERE sku IS NOT NULL AND trim(sku) <> '';
      
      RAISE NOTICE '   Total de registros en staging: %', row_count;
      RAISE NOTICE '   Registros con SKU válido: %', valid_sku_count;
      
      IF valid_sku_count = 0 THEN
        RAISE NOTICE '   ⚠️  La tabla está vacía o no tiene SKUs válidos. Por favor importa el CSV.';
      ELSE
        RAISE NOTICE '   ✅ La tabla tiene datos. Puedes ejecutar la migración.';
      END IF;
    END;
  END IF;

END $$;










