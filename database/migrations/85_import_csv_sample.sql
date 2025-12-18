-- ====================================================
-- Migration 85: Script de ejemplo para importar CSV
-- ====================================================
-- Este script muestra cómo importar el CSV manualmente
-- usando INSERT statements
-- ====================================================
-- NOTA: Este es solo un ejemplo con las primeras líneas
-- Para importar todo el CSV, usa Table Editor o COPY
-- ====================================================

-- Primero, asegúrate de que la tabla existe (ejecuta script 83 primero)
-- Luego, puedes usar este patrón para insertar datos manualmente:

-- Ejemplo de INSERT (solo para referencia):
/*
INSERT INTO public."_stg_catalog_items" (
  sku, collection_name, variant_name, item_name, item_description,
  item_type, measure_basis, uom, is_fabric, roll_width_m,
  cost_exw, active, discontinued, manufacturer, item_category_id, family
) VALUES
  ('ABC-04-LW', '', 'White', 'Panel blind motor', 'Panel blind motor left white', 'component', 'unit', 'PCS', 'FALSE', '', '61.547', 'TRUE', 'FALSE', 'Coulisse', 'Hardware', 'Roller Shade , Dual Shade , Triple Shade'),
  ('ABC-27-W', '', 'White', 'Wall plate for', 'Wall plate for wall switch white', 'component', 'unit', 'PCS', 'FALSE', '', '13.403', 'TRUE', 'FALSE', 'Coulisse', 'Hardware', 'Roller Shade , Dual Shade , Triple Shade');
*/

-- ====================================================
-- INSTRUCCIONES PARA IMPORTAR CSV EN SUPABASE
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'INSTRUCCIONES PARA IMPORTAR CSV';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'OPCIÓN 1: Table Editor (MÁS FÁCIL)';
  RAISE NOTICE '   1. Ve a Supabase Dashboard → Table Editor';
  RAISE NOTICE '   2. Busca la tabla "_stg_catalog_items"';
  RAISE NOTICE '   3. Haz clic en el botón "Insert" o "Import"';
  RAISE NOTICE '   4. Selecciona "Import from CSV" o "Upload CSV"';
  RAISE NOTICE '   5. Selecciona tu archivo CSV';
  RAISE NOTICE '   6. Asegúrate de marcar "Header row"';
  RAISE NOTICE '   7. Haz clic en "Import"';
  RAISE NOTICE '';
  RAISE NOTICE 'OPCIÓN 2: SQL Editor con COPY (requiere acceso al servidor)';
  RAISE NOTICE '   COPY public."_stg_catalog_items"';
  RAISE NOTICE '   FROM ''/ruta/al/archivo.csv''';
  RAISE NOTICE '   WITH (FORMAT csv, HEADER true, DELIMITER '','');';
  RAISE NOTICE '';
  RAISE NOTICE 'OPCIÓN 3: Usar pgAdmin o psql';
  RAISE NOTICE '   \COPY public."_stg_catalog_items" FROM ''archivo.csv'' CSV HEADER;';
  RAISE NOTICE '';
  RAISE NOTICE 'DESPUÉS DE IMPORTAR:';
  RAISE NOTICE '   Ejecuta el script 84 para verificar';
  RAISE NOTICE '   Luego ejecuta el script 82 para actualizar categorías';
  RAISE NOTICE '';
END $$;

