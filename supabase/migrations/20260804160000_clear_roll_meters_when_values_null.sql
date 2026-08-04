-- When roll_width/length value+uom are cleared, also clear normalized meters.
-- Previously catalogitems_sync_roll_dimensions only wrote meters when values
-- were present, leaving stale roll_width_m/roll_length_m that the UI could
-- resurrect as "Roll Item" on reload.

CREATE OR REPLACE FUNCTION public.catalogitems_sync_roll_dimensions()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- ---- WIDTH -> meters ----
  IF NEW.roll_width_value IS NOT NULL AND NEW.roll_width_uom IS NOT NULL THEN
    NEW.roll_width_m :=
      CASE NEW.roll_width_uom
        WHEN 'm'  THEN NEW.roll_width_value
        WHEN 'yd' THEN NEW.roll_width_value * 0.9144
        WHEN 'ft' THEN NEW.roll_width_value * 0.3048
        WHEN 'in' THEN NEW.roll_width_value * 0.0254
        ELSE NEW.roll_width_m
      END;
  ELSE
    NEW.roll_width_m := NULL;
  END IF;

  -- ---- LENGTH -> meters ----
  IF NEW.roll_length_value IS NOT NULL AND NEW.roll_length_uom IS NOT NULL THEN
    NEW.roll_length_m :=
      CASE NEW.roll_length_uom
        WHEN 'm'  THEN NEW.roll_length_value
        WHEN 'yd' THEN NEW.roll_length_value * 0.9144
        WHEN 'ft' THEN NEW.roll_length_value * 0.3048
        WHEN 'in' THEN NEW.roll_length_value * 0.0254
        ELSE NEW.roll_length_m
      END;
  ELSE
    NEW.roll_length_m := NULL;
  END IF;

  RETURN NEW;
END;
$$;
