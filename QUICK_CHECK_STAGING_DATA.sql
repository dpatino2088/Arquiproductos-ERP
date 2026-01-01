-- ====================================================
-- Verificación Rápida de Datos en Staging
-- ====================================================

-- Verificar _stg_catalog_update
SELECT 
  '_stg_catalog_update' as tabla,
  COUNT(*) as total_registros,
  COUNT(*) FILTER (WHERE sku IS NOT NULL AND trim(sku) <> '') as registros_con_sku_valido,
  COUNT(*) FILTER (WHERE sku IS NULL OR trim(sku) = '') as registros_sin_sku
FROM public."_stg_catalog_update";

-- Verificar _stg_catalog_items (solo si existe)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE NOTICE 'Tabla _stg_catalog_items existe';
  ELSE
    RAISE NOTICE 'Tabla _stg_catalog_items NO existe (esto es normal)';
  END IF;
END $$;

-- Mostrar algunos ejemplos de registros de _stg_catalog_update
SELECT 
  'Ejemplos de _stg_catalog_update' as info,
  sku,
  item_name,
  collection_name,
  cost_exw,
  is_fabric
FROM public."_stg_catalog_update"
WHERE sku IS NOT NULL AND trim(sku) <> ''
LIMIT 5;

