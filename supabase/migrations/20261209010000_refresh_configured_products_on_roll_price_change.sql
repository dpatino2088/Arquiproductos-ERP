-- Keep ConfiguredProducts/QuoteLines in sync when roll pricing changes.
-- Prevents stale snapshots after updating roll cost/UOM/width/pricing mode.

CREATE OR REPLACE FUNCTION public.refresh_configured_products_on_roll_price_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_ql RECORD;
BEGIN
  -- Only applies to roll items.
  IF COALESCE(NEW.is_roll, false) = false THEN
    RETURN NEW;
  END IF;

  -- Make sure MSRP row is aligned first (idempotent).
  PERFORM public.msrp_compute_for_item(NEW.id);

  -- Recompute all configured products that consume this roll.
  FOR v_cp IN
    SELECT cp.id
    FROM public."ConfiguredProducts" cp
    WHERE cp.roll_catalog_item_id = NEW.id
      AND COALESCE(cp.deleted, false) = false
  LOOP
    PERFORM public.calculate_configured_product_totals(v_cp.id);
  END LOOP;

  -- Re-sync quote line snapshots for affected configured products.
  FOR v_ql IN
    SELECT ql.id
    FROM public."QuoteLines" ql
    JOIN public."ConfiguredProducts" cp
      ON cp.id = ql.configured_product_id
    WHERE cp.roll_catalog_item_id = NEW.id
  LOOP
    PERFORM public.sync_quote_line_pricing_from_configured_product(v_ql.id, true);
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_refresh_configured_products_on_roll_price_change
ON public."CatalogItems";

CREATE TRIGGER trg_refresh_configured_products_on_roll_price_change
AFTER UPDATE OF
  cost_exw,
  unit_of_measure,
  measure_basis,
  roll_pricing_mode,
  roll_width_value,
  roll_width_uom,
  roll_width_m,
  roll_width
ON public."CatalogItems"
FOR EACH ROW
WHEN (
  COALESCE(NEW.is_roll, false) = true
  AND (
    OLD.cost_exw IS DISTINCT FROM NEW.cost_exw
    OR OLD.unit_of_measure IS DISTINCT FROM NEW.unit_of_measure
    OR OLD.measure_basis IS DISTINCT FROM NEW.measure_basis
    OR OLD.roll_pricing_mode IS DISTINCT FROM NEW.roll_pricing_mode
    OR OLD.roll_width_value IS DISTINCT FROM NEW.roll_width_value
    OR OLD.roll_width_uom IS DISTINCT FROM NEW.roll_width_uom
    OR OLD.roll_width_m IS DISTINCT FROM NEW.roll_width_m
    OR OLD.roll_width IS DISTINCT FROM NEW.roll_width
  )
)
EXECUTE FUNCTION public.refresh_configured_products_on_roll_price_change();
