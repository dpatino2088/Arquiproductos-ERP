-- ====================================================
-- MIGRATION 59 V2: Migrate roll_width legacy to new schema (SAFE)
-- Date: 2026-02-03
--
-- Purpose:
-- - Check if roll_width column exists before migrating
-- - Migrate data from roll_width (legacy, in meters) to roll_width_value + roll_width_uom
-- - Set roll_length = 29.965 yd for all rolls
-- - Drop roll_width column after migration (if exists)
-- - Update triggers and functions to use only new schema
-- ====================================================

BEGIN;

-- Step 1: Migrate existing roll_width data to new schema (only if column exists)
DO $$
BEGIN
  -- Check if roll_width column exists
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CatalogItems'
      AND column_name = 'roll_width'
  ) THEN
    -- Migrate roll_width to roll_width_value/uom (only if value is missing)
    UPDATE public."CatalogItems"
    SET
      roll_width_value = roll_width,
      roll_width_uom = 'm'  -- roll_width legacy is in meters
    WHERE is_roll = true
      AND roll_width IS NOT NULL
      AND roll_width > 0
      AND (roll_width_value IS NULL OR roll_width_value = 0);

    RAISE NOTICE 'Migrated % rows from roll_width to roll_width_value', 
      (SELECT count(*) FROM public."CatalogItems" 
       WHERE is_roll = true AND roll_width_value IS NOT NULL);
  ELSE
    RAISE NOTICE 'Column roll_width does not exist, skipping migration step 1a';
  END IF;
END $$;

-- Step 1b: Set roll_length for ALL rolls that don't have it yet
UPDATE public."CatalogItems"
SET
  roll_length_value = 29.965,  -- Standard roll length
  roll_length_uom = 'yd'       -- Length in yards as per business rule
WHERE is_roll = true
  AND (roll_length_value IS NULL OR roll_length_value = 0);

-- Step 2: Update trigger trg_catalogitems_write_conversions to use only new schema
CREATE OR REPLACE FUNCTION "public"."trg_catalogitems_write_conversions"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  v_per_m  numeric := NULL;
  v_per_m2 numeric := NULL;
  v_per_ea numeric := NULL;
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
  -- Use roll_width_m (normalized) from sync trigger
  IF coalesce(NEW.is_roll,false) = true AND NEW.roll_width_m IS NOT NULL AND v_per_m IS NOT NULL THEN
    v_per_m2 := v_per_m / NEW.roll_width_m;
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
    NEW.roll_width_m, -- Use normalized width (not legacy roll_width)
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

COMMENT ON FUNCTION "public"."trg_catalogitems_write_conversions"() IS
'Updated to use roll_width_m (normalized) instead of legacy roll_width column.';

-- Step 3: Drop legacy roll_width column (only if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CatalogItems'
      AND column_name = 'roll_width'
  ) THEN
    ALTER TABLE public."CatalogItems"
    DROP COLUMN roll_width;
    
    RAISE NOTICE 'Dropped legacy roll_width column';
  ELSE
    RAISE NOTICE 'Column roll_width already dropped, skipping';
  END IF;
END $$;

COMMENT ON TABLE public."CatalogItems" IS
'Updated schema: roll_width legacy column removed. Use roll_width_value + roll_width_uom + roll_width_m (normalized).';

COMMIT;
