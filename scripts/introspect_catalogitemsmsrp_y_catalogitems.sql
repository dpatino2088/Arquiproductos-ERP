-- =====================================================
-- Introspect: CatalogItemsMSRP y CatalogItems
-- Para el informe INFORME_MSRP_SALE_IN_NOT_NULL_Y_LEGACY.md
-- Ejecutar en la BD donde ocurre el error y pegar resultados.
-- =====================================================

-- 1) Columnas de CatalogItemsMSRP (existente vs legacy, NOT NULL)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP'
ORDER BY ordinal_position;

-- 2) Constraints UNIQUE/PRIMARY KEY en CatalogItemsMSRP (para ON CONFLICT)
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public."CatalogItemsMSRP"'::regclass
  AND contype IN ('p','u');

-- 3) Triggers en CatalogItemsMSRP (por si alguno modifica msrp_sale_in)
SELECT tgname, tgtype, tgenabled, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public."CatalogItemsMSRP"'::regclass
  AND NOT tgisinternal;

-- 4) Columnas de CatalogItems (para legacy vs usadas en Edit Item)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'CatalogItems'
ORDER BY ordinal_position;

-- 5) Triggers en CatalogItems que tocan MSRP o sync
SELECT tgname, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public."CatalogItems"'::regclass
  AND NOT tgisinternal
  AND (pg_get_triggerdef(oid) ILIKE '%msrp%' OR pg_get_triggerdef(oid) ILIKE '%sync_catalogitems%');
