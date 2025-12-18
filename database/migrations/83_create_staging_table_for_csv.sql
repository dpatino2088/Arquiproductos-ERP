-- ====================================================
-- Migration 83: Crear tabla de staging para importar CSV
-- ====================================================
-- Este script crea la tabla _stg_catalog_items
-- para importar el CSV y luego actualizar las categorías
-- ====================================================

-- Crear tabla de staging si no existe
CREATE TABLE IF NOT EXISTS public."_stg_catalog_items" (
  sku text,
  collection_name text,
  variant_name text,
  item_name text,
  item_description text,
  item_type text,
  measure_basis text,
  uom text,
  is_fabric text, -- Text porque puede venir como "TRUE"/"FALSE" del CSV
  roll_width_m text, -- Text para manejar valores numéricos como texto
  cost_exw text, -- Text para manejar valores numéricos como texto
  active text, -- Text porque puede venir como "TRUE"/"FALSE" del CSV
  discontinued text, -- Text porque puede venir como "TRUE"/"FALSE" del CSV
  manufacturer text,
  item_category_id text, -- Esta es la columna que usaremos para mapear categorías
  family text
);

-- Comentarios para documentar la tabla
COMMENT ON TABLE public."_stg_catalog_items" IS 'Tabla temporal para importar CSV de catalog items antes de migrar a CatalogItems';
COMMENT ON COLUMN public."_stg_catalog_items".sku IS 'SKU del item (usado para hacer match con CatalogItems)';
COMMENT ON COLUMN public."_stg_catalog_items".item_category_id IS 'Nombre de la categoría del CSV (será mapeado a ItemCategories.id)';

-- Crear índice en SKU para mejorar el rendimiento del JOIN
CREATE INDEX IF NOT EXISTS idx_stg_catalog_items_sku 
ON public."_stg_catalog_items"(sku) 
WHERE sku IS NOT NULL AND trim(sku) <> '';

-- Limpiar tabla si ya tiene datos (opcional - descomenta si quieres empezar desde cero)
-- TRUNCATE TABLE public."_stg_catalog_items";

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ TABLA DE STAGING CREADA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Próximos pasos:';
  RAISE NOTICE '   1. Ve a Supabase Table Editor';
  RAISE NOTICE '   2. Selecciona la tabla "_stg_catalog_items"';
  RAISE NOTICE '   3. Haz clic en "Import" y selecciona tu CSV';
  RAISE NOTICE '   4. O usa el comando COPY en SQL Editor:';
  RAISE NOTICE '';
  RAISE NOTICE '   COPY public."_stg_catalog_items"';
  RAISE NOTICE '   FROM ''/ruta/a/tu/archivo.csv''';
  RAISE NOTICE '   WITH (FORMAT csv, HEADER true, DELIMITER '','');';
  RAISE NOTICE '';
  RAISE NOTICE '   5. Después ejecuta el script 82 para actualizar las categorías';
  RAISE NOTICE '';
END $$;

