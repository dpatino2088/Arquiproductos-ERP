-- ====================================================
-- Migration: Evitar NULL en msrp_sale_in/msrp_sale_out al guardar ítem
-- Date: 2026-01-25
-- ====================================================
-- Fixes: "null value in column msrp_sale_in of relation CatalogItemsMSRP violates not-null constraint"
--
-- Causas:
-- 1) El trigger trg_recompute_msrp_on_catalog_item_change solo corría cuando cost_exw > 0,
--    así que ítems con cost_exw=0 nunca tenían fila en CatalogItemsMSRP.
-- 2) sync_catalogitems_to_msrp solo hacía UPDATE; si no existía fila, no la creaba.
--    Si en algún flujo se insertaba una fila sin msrp_sale_in/out, fallaba NOT NULL.
--
-- Cambios:
-- 1) Trigger: ejecutar msrp_compute_for_item también con cost_exw=0 (o null).
--    msrp_compute ya devuelve msrp_sale_in/out=0 en ese caso.
-- 2) sync_catalogitems_to_msrp: upsert. Si no existe fila, INSERT con msrp_sale_in=0,
--    msrp_sale_out=0 y el resto de columnas NOT NULL; si existe, UPDATE solo identidad.
-- ====================================================

-- 1) Recrear el trigger SIN la condición cost_exw > 0 (sí mantener organization_id IS NOT NULL)
DROP TRIGGER IF EXISTS "trg_recompute_msrp_on_catalog_item_change" ON public."CatalogItems";

CREATE TRIGGER "trg_recompute_msrp_on_catalog_item_change"
  AFTER INSERT OR UPDATE OF cost_exw, category_id ON public."CatalogItems"
  FOR EACH ROW
  WHEN (NEW.organization_id IS NOT NULL)
  EXECUTE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"();

-- 2) Actualizar la función del trigger para que llame msrp_compute también con cost_exw=0
CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (TG_OP = 'INSERT') OR
     (TG_OP = 'UPDATE' AND (
       (OLD.cost_exw IS DISTINCT FROM NEW.cost_exw) OR
       (OLD.category_id IS DISTINCT FROM NEW.category_id)
     )) THEN
    -- Llamar siempre que organization_id exista (también con cost_exw=0; msrp_compute pone 0 en msrp_sale_in/out)
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

-- 3) sync_catalogitems_to_msrp: UPSERT para crear fila con msrp_sale_in/out=0 cuando no existe
--    (evita que otro flujo inserte sin esos campos y dispare NOT NULL)
CREATE OR REPLACE FUNCTION public.sync_catalogitems_to_msrp() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_cost numeric(12,4);
  v_total numeric(12,4);
BEGIN
  v_cost := COALESCE(NEW.cost_exw, 0);
  v_total := v_cost;

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    import_tax_cost, shipping_cost, total_cost,
    msrp_sale_in, msrp_sale_out,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct_sale_out,
    material_cost,
    sku, name, collection_name, variant_name, unit_of_measure
  ) VALUES (
    NEW.id, NEW.organization_id, NEW.category_id, v_cost,
    0, 0, v_total,
    0, 0,
    0, 0, 0.35, 0.65,
    v_cost,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name, NEW.unit_of_measure
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure;

  RETURN NEW;
END;
$$;

-- Nota: trg_sync_catalogitems_to_msrp sigue siendo AFTER UPDATE OF (sku, name, ...). No corre en INSERT.
-- En INSERT, trg_recompute crea la fila vía msrp_compute_for_item. El upsert en sync cubre el caso
-- en que se actualiza solo identidad y aún no existía fila (p. ej. ítem con cost_exw=0).

COMMENT ON FUNCTION public.sync_catalogitems_to_msrp() IS
'Sync identidad (sku, name, collection_name, variant_name, unit_of_measure) desde CatalogItems a CatalogItemsMSRP. Si no existe fila, INSERT con msrp_sale_in=0, msrp_sale_out=0 para cumplir NOT NULL.';
