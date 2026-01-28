-- ====================================================
-- Migration: Añadir unit_of_measure a CatalogItemsMSRP
-- Date: 2026-01-29
-- ====================================================
-- Fixes: "column unit_of_measure of relation CatalogItemsMSRP does not exist"
--
-- La UI y algunas consultas esperan unit_of_measure en CatalogItemsMSRP.
-- CatalogItems sí tiene unit_of_measure; CatalogItemsMSRP es caché de MSRP
-- y no la tenía. Se añade, se hace backfill desde CatalogItems y se mantiene
-- en sync vía sync_catalogitems_to_msrp y fill_msrp_item_identity.
-- ====================================================

-- 1) Añadir columna
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP' AND column_name = 'unit_of_measure'
  ) THEN
    ALTER TABLE public."CatalogItemsMSRP" ADD COLUMN unit_of_measure text;
    RAISE NOTICE '✅ CatalogItemsMSRP: columna unit_of_measure añadida';
  END IF;
END $$;

-- 2) Backfill desde CatalogItems
UPDATE public."CatalogItemsMSRP" cim
SET unit_of_measure = ci.unit_of_measure
FROM public."CatalogItems" ci
WHERE ci.id = cim.catalog_item_id
  AND cim.unit_of_measure IS DISTINCT FROM ci.unit_of_measure;

-- 3) sync_catalogitems_to_msrp: propagar unit_of_measure cuando cambia en CatalogItems
CREATE OR REPLACE FUNCTION public.sync_catalogitems_to_msrp() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public."CatalogItemsMSRP" cim
  SET
    sku             = NEW.sku,
    name            = NEW.name,
    collection_name = NEW.collection_name,
    variant_name    = NEW.variant_name,
    unit_of_measure = NEW.unit_of_measure
  WHERE cim.catalog_item_id = NEW.id;
  RETURN NEW;
END;
$$;

-- 4) fill_msrp_item_identity: rellenar unit_of_measure desde CatalogItems cuando es null
CREATE OR REPLACE FUNCTION public.fill_msrp_item_identity() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_sku text;
  v_name text;
  v_collection_name text;
  v_variant_name text;
  v_unit_of_measure text;
BEGIN
  IF NEW.sku IS NULL OR NEW.name IS NULL OR NEW.collection_name IS NULL OR NEW.variant_name IS NULL OR NEW.unit_of_measure IS NULL
  THEN
    SELECT ci.sku, ci.name, ci.collection_name, ci.variant_name, ci.unit_of_measure
      INTO v_sku, v_name, v_collection_name, v_variant_name, v_unit_of_measure
      FROM public."CatalogItems" ci
      WHERE ci.id = NEW.catalog_item_id;

    IF NEW.sku IS NULL THEN NEW.sku := v_sku; END IF;
    IF NEW.name IS NULL THEN NEW.name := v_name; END IF;
    IF NEW.collection_name IS NULL THEN NEW.collection_name := v_collection_name; END IF;
    IF NEW.variant_name IS NULL THEN NEW.variant_name := v_variant_name; END IF;
    IF NEW.unit_of_measure IS NULL THEN NEW.unit_of_measure := v_unit_of_measure; END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 5) Incluir unit_of_measure en el trigger para que al cambiar solo UoM en CatalogItems
--    también se propague a CatalogItemsMSRP. (En PG no se puede ALTER TRIGGER OF; hay que DROP/CREATE.)
DROP TRIGGER IF EXISTS "trg_sync_catalogitems_to_msrp" ON "public"."CatalogItems";
CREATE TRIGGER "trg_sync_catalogitems_to_msrp"
  AFTER UPDATE OF "sku", "name", "collection_name", "variant_name", "unit_of_measure"
  ON "public"."CatalogItems"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."sync_catalogitems_to_msrp"();
