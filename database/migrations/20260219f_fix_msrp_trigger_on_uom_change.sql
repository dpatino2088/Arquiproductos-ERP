-- ============================================================================
-- Migration F: Expand MSRP recompute trigger to include UOM/measure_basis changes
-- Date: 2026-02-19
--
-- PROBLEMA
-- ─────────────────────────────────────────────────────────────────────────────
-- El trigger trg_recompute_msrp_on_catalog_item_change solo escucha:
--   UPDATE OF "cost_exw", "category_id"
--
-- Cuando el usuario cambia:
--   - unit_of_measure  (ej: 'yd' → 'ea')
--   - measure_basis    (ej: 'linear' → 'unit')
--   - roll_pricing_mode (ej: 'per_linear_meter' → NULL)
--   - roll_width_m / roll_width (afectan conversión m² desde m)
--
-- ... el trigger NO se dispara, y CatalogItemsMSRP queda con:
--   pricing_uom = 'm' (stale, debería ser 'ea')
--   pricing_cost_exw = valor viejo
--   shipping_cost/total_cost/dealer_price/msrp = todos calculados sobre la UOM anterior
--
-- FIX
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Expandir la función trig_recompute_msrp_on_catalog_item_change para detectar
--    cambios en unit_of_measure, measure_basis, roll_pricing_mode, roll_width_m.
-- 2. Recrear el trigger con las columnas adicionales en el UPDATE OF clause.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 1: Actualizar la función del trigger para incluir los nuevos campos
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public."trig_recompute_msrp_on_catalog_item_change"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (TG_OP = 'INSERT') OR
     (TG_OP = 'UPDATE' AND (
       (OLD.cost_exw         IS DISTINCT FROM NEW.cost_exw)     OR
       (OLD.category_id      IS DISTINCT FROM NEW.category_id)  OR
       -- UOM/pricing changes that affect pricing_uom and pricing_cost_exw
       (OLD.unit_of_measure  IS DISTINCT FROM NEW.unit_of_measure)  OR
       (OLD.measure_basis    IS DISTINCT FROM NEW.measure_basis)     OR
       (OLD.roll_pricing_mode IS DISTINCT FROM NEW.roll_pricing_mode) OR
       (OLD.roll_width_m     IS DISTINCT FROM NEW.roll_width_m)      OR
       (OLD.roll_width       IS DISTINCT FROM NEW.roll_width)         OR
       (OLD.units_per_purchase_unit IS DISTINCT FROM NEW.units_per_purchase_unit)
     )) THEN
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."trig_recompute_msrp_on_catalog_item_change"() IS
'Recomputa CatalogItemsMSRP cuando cambian campos que afectan pricing:
cost_exw, category_id, unit_of_measure, measure_basis, roll_pricing_mode,
roll_width_m, roll_width, units_per_purchase_unit.
Llama a msrp_compute_for_item que recalcula pricing_uom, pricing_cost_exw
y todos los costos derivados.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 2: Recrear el trigger incluyendo las nuevas columnas en UPDATE OF
--   Postgres solo dispara el trigger cuando cambia una de las columnas listadas.
--   Añadimos todas las que afectan pricing_uom / pricing_cost_exw.
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS "trg_recompute_msrp_on_catalog_item_change" ON public."CatalogItems";

CREATE TRIGGER "trg_recompute_msrp_on_catalog_item_change"
AFTER INSERT OR UPDATE OF
  "cost_exw",
  "category_id",
  "unit_of_measure",
  "measure_basis",
  "roll_pricing_mode",
  "roll_width_m",
  "roll_width",
  "units_per_purchase_unit"
ON public."CatalogItems"
FOR EACH ROW
WHEN (NEW.organization_id IS NOT NULL)
EXECUTE FUNCTION public."trig_recompute_msrp_on_catalog_item_change"();


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 2B: Reescribir sync_catalogitems_to_msrp_safe para que llame
--   msrp_compute_for_item cuando cambia unit_of_measure, measure_basis o
--   roll_pricing_mode — que afectan pricing_uom y pricing_cost_exw.
--   El trigger ya dispara en unit_of_measure; ahora también recomputa precios.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public."sync_catalogitems_to_msrp_safe"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_new_pricing_uom text;
  v_should_recompute boolean := false;
BEGIN
  v_new_pricing_uom := public.derive_pricing_uom(
    NEW.measure_basis, NEW.roll_pricing_mode, NEW.is_roll
  );

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    pricing_cost_exw,
    dealer_price, msrp,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    updated_at
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    COALESCE(NEW.cost_exw, 0),
    0, 0,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name,
    NEW.unit_of_measure,
    v_new_pricing_uom,
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    pricing_uom     = EXCLUDED.pricing_uom,
    category_id     = EXCLUDED.category_id,
    updated_at      = now();

  -- Si cambió unit_of_measure, measure_basis o roll_pricing_mode,
  -- el pricing_uom y pricing_cost_exw en CIM quedaron stale.
  -- Llamar msrp_compute_for_item para recalcular completamente.
  IF TG_OP = 'INSERT' THEN
    v_should_recompute := true;
  ELSIF TG_OP = 'UPDATE' THEN
    v_should_recompute := (
      (OLD.unit_of_measure   IS DISTINCT FROM NEW.unit_of_measure)  OR
      (OLD.measure_basis     IS DISTINCT FROM NEW.measure_basis)     OR
      (OLD.roll_pricing_mode IS DISTINCT FROM NEW.roll_pricing_mode) OR
      (OLD.cost_exw          IS DISTINCT FROM NEW.cost_exw)
    );
  END IF;

  IF v_should_recompute AND COALESCE(NEW.cost_exw, 0) > 0 THEN
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."sync_catalogitems_to_msrp_safe"() IS
'Sync identidad + pricing_uom desde CatalogItems a CatalogItemsMSRP.
Si cambia unit_of_measure, measure_basis, roll_pricing_mode o cost_exw,
llama msrp_compute_for_item para recalcular pricing_cost_exw, dealer_price y msrp.
NO escribe columnas GENERATED.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 3: Backfill — Recompute filas donde pricing_uom no coincide con la
--   deriva actual de measure_basis/roll_pricing_mode.
--   Esto repara los items que ya fueron guardados con UOM distinto antes de este fix.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_item RECORD;
  v_expected_uom text;
BEGIN
  FOR v_item IN
    SELECT ci.id, ci.organization_id,
           ci.measure_basis, ci.is_roll, ci.roll_pricing_mode,
           cim.pricing_uom
    FROM   public."CatalogItems" ci
    JOIN   public."CatalogItemsMSRP" cim
           ON cim.catalog_item_id = ci.id
           AND cim.organization_id = ci.organization_id
    WHERE  ci.cost_exw IS NOT NULL AND ci.cost_exw > 0
  LOOP
    -- Calcular pricing_uom esperado
    v_expected_uom := public.derive_pricing_uom(
      v_item.measure_basis,
      v_item.roll_pricing_mode,
      v_item.is_roll
    );

    -- Solo recompute si pricing_uom está stale
    IF v_item.pricing_uom IS DISTINCT FROM v_expected_uom THEN
      BEGIN
        PERFORM public.msrp_compute_for_item(v_item.id);
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error recomputing item %: %', v_item.id, SQLERRM;
      END;
    END IF;
  END LOOP;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICACIÓN (descomenta para ejecutar)
-- ─────────────────────────────────────────────────────────────────────────────
/*
-- Items donde pricing_uom NO coincide con lo que debería derivarse
SELECT
  ci.sku, ci.name,
  ci.measure_basis, ci.is_roll, ci.roll_pricing_mode,
  cim.pricing_uom                        AS cim_pricing_uom,
  public.derive_pricing_uom(ci.measure_basis, ci.roll_pricing_mode, ci.is_roll)
                                         AS expected_pricing_uom,
  cim.pricing_cost_exw,
  ci.cost_exw,
  ci.unit_of_measure
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  cim.pricing_uom IS DISTINCT FROM
       public.derive_pricing_uom(ci.measure_basis, ci.roll_pricing_mode, ci.is_roll)
ORDER BY ci.sku;
*/

COMMIT;
