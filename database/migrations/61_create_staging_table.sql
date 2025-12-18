-- ====================================================
-- Migration 61: Create Staging Table for CSV Import
-- ====================================================
-- Este script crea la tabla _stg_catalog_items para importar CSV
-- La tabla tiene todas las columnas necesarias para el CSV
-- ====================================================

DO $$
BEGIN
  -- Crear tabla staging si no existe
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE NOTICE '📋 Creando tabla _stg_catalog_items...';
    
    CREATE TABLE IF NOT EXISTS public."_stg_catalog_items" (
      -- Identificadores
      sku text,
      variant_name text,
      item_name text,
      item_description text,
      
      -- Tipos y medidas
      item_type text,
      measure_basis text,
      uom text,
      
      -- Fabric specific
      is_fabric text, -- Se convierte a boolean después
      roll_widt text, -- Se convierte a numeric después (roll_width_m)
      
      -- Pricing (puede venir como fabric_prici o cost_price_exw)
      fabric_prici text, -- Se convierte a numeric después (cost_exw)
      cost_price_exw text, -- Alternativa para cost_exw
      
      -- Status
      active text, -- Se convierte a boolean después
      discontinued text, -- Se convierte a boolean después
      
      -- Relaciones
      manufacturer text,
      category text,
      family text, -- Para agrupar productos (opcional)
      
      -- Collections (para fabrics, puede venir del CSV o derivarse)
      collection text,
      
      -- Metadata adicional (opcional)
      default_margin_pct text, -- Se convierte a numeric después
      msrp text -- Se convierte a numeric después
    );

    RAISE NOTICE '✅ Tabla _stg_catalog_items creada';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Próximos pasos:';
    RAISE NOTICE '   1. Ve a Supabase Table Editor';
    RAISE NOTICE '   2. Selecciona la tabla _stg_catalog_items';
    RAISE NOTICE '   3. Haz clic en "Import data from CSV"';
    RAISE NOTICE '   4. Sube tu archivo CSV';
    RAISE NOTICE '   5. Ejecuta el script 14_migrate_staging_to_catalogitems.sql';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE 'ℹ️  La tabla _stg_catalog_items ya existe';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Verificando datos en staging...';
    
    DECLARE
      row_count integer;
    BEGIN
      SELECT COUNT(*) INTO row_count
      FROM public."_stg_catalog_items";
      
      RAISE NOTICE '   Total de registros en staging: %', row_count;
      
      IF row_count = 0 THEN
        RAISE NOTICE '   ⚠️  La tabla está vacía. Por favor importa el CSV.';
      ELSE
        RAISE NOTICE '   ✅ La tabla tiene datos. Puedes ejecutar la migración.';
      END IF;
    END;
  END IF;

END $$;

