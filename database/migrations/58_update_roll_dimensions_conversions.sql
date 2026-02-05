-- =========================================
-- Migration 58: Update roll dimensions for conversions
-- =========================================
-- Update trg_catalogitems_write_conversions to use roll_width_m (normalized)
-- with fallback to roll_width (legacy) for backward compatibility
-- =========================================

BEGIN;

-- =========================================
-- STEP 1: Update trigger function to use roll_width_m
-- =========================================
CREATE OR REPLACE FUNCTION public.trg_catalogitems_write_conversions()
RETURNS trigger
LANGUAGE plpgsql
AS $_$
DECLARE
  v_per_m  numeric := NULL;
  v_per_m2 numeric := NULL;
  v_per_ea numeric := NULL;
  v_effective_width_m numeric := NULL;
BEGIN
  IF NEW.cost_exw IS NULL OR NEW.unit_of_measure IS NULL THEN
    RETURN NEW;
  END IF;

  -- =========================
  -- LINEAR ($/m)
  -- =========================
  IF lower(NEW.unit_of_measure) IN ('m','meter','meters') THEN
    v_per_m := NEW.cost_exw;

  ELSIF lower(NEW.unit_of_measure) = 'ft' THEN
    v_per_m := NEW.cost_exw / 0.3048;

  ELSIF lower(NEW.unit_of_measure) = 'yd' THEN
    v_per_m := NEW.cost_exw / 0.9144;
  END IF;

  -- =========================
  -- ROLL AREA ($/m2)
  -- =========================
  -- Use roll_width_m (normalized) if available, fallback to roll_width (legacy)
  IF coalesce(NEW.is_roll, false) = true AND v_per_m IS NOT NULL THEN
    v_effective_width_m := COALESCE(NEW.roll_width_m, NEW.roll_width);
    
    IF v_effective_width_m IS NOT NULL AND v_effective_width_m > 0 THEN
      v_per_m2 := v_per_m / v_effective_width_m;
    END IF;
  END IF;

  -- =========================
  -- UNIT ($/ea)
  -- =========================
  IF lower(NEW.unit_of_measure) IN ('ea','pcs','pc','unit','piece') THEN
    v_per_ea := NEW.cost_exw;

  ELSIF lower(NEW.unit_of_measure) IN ('pack','set','box','case','bag')
        AND NEW.units_per_purchase_unit IS NOT NULL
        AND NEW.units_per_purchase_unit > 0 THEN
    v_per_ea := NEW.cost_exw / NEW.units_per_purchase_unit;
  END IF;

  -- =========================
  -- UPSERT
  -- =========================
  INSERT INTO public."CatalogItemConversions" (
    catalog_item_id,
    organization_id,
    cost_exw_input,
    unit_of_measure_input,
    roll_width_input,
    cost_exw_per_m,
    cost_exw_per_m2,
    cost_exw_per_ea,
    computed_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.cost_exw,
    NEW.unit_of_measure,
    v_effective_width_m, -- Use normalized width for consistency
    v_per_m,
    v_per_m2,
    v_per_ea,
    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw_input = EXCLUDED.cost_exw_input,
    unit_of_measure_input = EXCLUDED.unit_of_measure_input,
    roll_width_input = EXCLUDED.roll_width_input,
    cost_exw_per_m = EXCLUDED.cost_exw_per_m,
    cost_exw_per_m2 = EXCLUDED.cost_exw_per_m2,
    cost_exw_per_ea = EXCLUDED.cost_exw_per_ea,
    computed_at = EXCLUDED.computed_at;

  RETURN NEW;
END;
$_$;

-- =========================================
-- STEP 2: Update trigger to fire on new columns
-- =========================================
DROP TRIGGER IF EXISTS catalogitems_write_conversions ON public."CatalogItems";

CREATE TRIGGER catalogitems_write_conversions
  AFTER INSERT OR UPDATE OF 
    cost_exw, 
    unit_of_measure, 
    roll_width,
    roll_width_value,
    roll_width_uom,
    roll_width_m,
    is_roll, 
    units_per_purchase_unit
  ON public."CatalogItems"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_catalogitems_write_conversions();

COMMIT;
