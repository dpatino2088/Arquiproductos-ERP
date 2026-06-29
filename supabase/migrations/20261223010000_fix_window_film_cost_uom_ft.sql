-- Fix Window Film cost UOM: cost is per LINEAR FOOT, not per meter.
--
-- BUG: window_film items were seeded from the Madico price sheet with
-- cost_exw = cost_per_ft ($/linear foot) but stored unit_of_measure = 'm'.
-- Since roll_pricing_mode = 'per_square_meter', the MSRP pipeline
-- (compute_pricing_cost_exw) treated cost_exw as $/m and divided by
-- roll_width_m, giving pricing_cost_exw 1/0.3048 = 3.281x too LOW.
-- Result: every film MSRP/dealer/cost was understated ~3.281x, so films
-- were quoted/sold below cost.
--
-- FIX: set unit_of_measure = 'ft' (the true cost basis) so the ft -> m2
-- conversion runs correctly: pricing_cost_exw = (cost_exw / 0.3048) / roll_width_m.
-- Also normalize measure_basis to 'area' (film is sold by area = roll width x length,
-- consistent with roll_pricing_mode = 'per_square_meter'). Films are supply_only and
-- never referenced in BOMComponents, so the measure_basis sync trigger affects 0 rows.
--
-- Only affects items currently in the inconsistent state ('m' + per_square_meter).
-- Items already on 'ft' (e.g. LG Hausys) are left untouched.

DO $$
DECLARE
  v_ids uuid[];
  v_id  uuid;
BEGIN
  SELECT array_agg(id)
  INTO v_ids
  FROM public."CatalogItems"
  WHERE item_role = 'window_film'
    AND roll_pricing_mode = 'per_square_meter'
    AND unit_of_measure = 'm';

  IF v_ids IS NULL THEN
    RAISE NOTICE 'No window_film items to fix.';
    RETURN;
  END IF;

  UPDATE public."CatalogItems"
  SET unit_of_measure = 'ft',
      measure_basis   = 'area'
  WHERE id = ANY(v_ids);

  -- Recompute MSRP from the corrected cost basis.
  FOREACH v_id IN ARRAY v_ids LOOP
    PERFORM public.msrp_compute_for_item(v_id);
  END LOOP;

  RAISE NOTICE 'Fixed % window_film items.', array_length(v_ids, 1);
END $$;
