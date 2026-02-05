-- ====================================================
-- MIGRATION 60: Update validate_roll_pricing_mode to use new schema
-- Date: 2026-02-03
--
-- Purpose:
-- - Update trg_catalogitems_validate_roll_pricing_mode to use roll_width_m instead of roll_width
-- - Update trigger definition to fire on roll_width_value/uom instead of roll_width
-- - Allow dropping roll_width legacy column
-- ====================================================

BEGIN;

-- Update function to use roll_width_m (normalized) instead of roll_width
CREATE OR REPLACE FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- If it's a roll, it MUST have a pricing mode
  if coalesce(new.is_roll,false) = true then
    if new.roll_pricing_mode is null then
      new.roll_pricing_mode := 'per_linear_meter';
    end if;

    -- If priced per m2, roll_width_m must be present (>0)
    -- roll_width_m is calculated by trg_catalogitems_sync_roll_dimensions from roll_width_value + roll_width_uom
    if new.roll_pricing_mode = 'per_square_meter' then
      if new.roll_width_m is null or new.roll_width_m <= 0 then
        raise exception 'roll_width is required (>0) when roll_pricing_mode = per_square_meter. Please set roll_width_value and roll_width_uom.';
      end if;
    end if;

  else
    -- Non-roll items should not carry roll pricing mode (keeps data clean)
    new.roll_pricing_mode := null;
  end if;

  return new;
end;
$$;

COMMENT ON FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() IS
'Validates roll pricing mode. Updated to use roll_width_m (normalized) instead of legacy roll_width.';

-- Drop old trigger
DROP TRIGGER IF EXISTS "catalogitems_validate_roll_pricing_mode" ON public."CatalogItems";

-- Recreate trigger with updated column list (no roll_width)
CREATE TRIGGER "catalogitems_validate_roll_pricing_mode"
  BEFORE INSERT OR UPDATE OF "is_roll", "roll_pricing_mode", "roll_width_m", "measure_basis"
  ON public."CatalogItems"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"();

COMMENT ON TRIGGER "catalogitems_validate_roll_pricing_mode" ON public."CatalogItems" IS
'Validates roll pricing mode. Uses roll_width_m (normalized) instead of legacy roll_width.';

-- Also update catalogitems_write_conversions trigger to not depend on roll_width
DROP TRIGGER IF EXISTS "catalogitems_write_conversions" ON public."CatalogItems";

CREATE TRIGGER "catalogitems_write_conversions"
  AFTER INSERT OR UPDATE OF "cost_exw", "unit_of_measure", "roll_width_m", "is_roll", "units_per_purchase_unit"
  ON public."CatalogItems"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trg_catalogitems_write_conversions"();

COMMENT ON TRIGGER "catalogitems_write_conversions" ON public."CatalogItems" IS
'Computes conversions ($/m, $/m², $/ea). Uses roll_width_m instead of legacy roll_width.';

COMMIT;
