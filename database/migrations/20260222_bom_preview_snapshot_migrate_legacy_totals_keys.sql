-- One-time migration: Remove legacy *_landed keys from bom_preview_snapshot.totals
-- Depends on: 20260220_pricing_functions_remove_landed.sql
--
-- For existing ConfiguredProducts where totals contains:
--   roll_total_cost_landed, bom_total_cost_landed, accessories_total_cost_landed,
--   unit_product_cost_landed, total_cost_landed_without_labor, total_cost_with_labor
-- We copy values to new keys, delete old keys, and write the cleaned totals.
-- New keys: roll_total_cost, bom_total_cost, accessories_total_cost, unit_product_cost, total_cost

DO $$
DECLARE
  v_row RECORD;
  v_totals jsonb;
  v_cleaned jsonb;
  v_updated int := 0;
BEGIN
  FOR v_row IN
    SELECT id, bom_preview_snapshot
    FROM public."ConfiguredProducts"
    WHERE bom_preview_snapshot IS NOT NULL
      AND jsonb_typeof(bom_preview_snapshot->'totals') = 'object'
      AND (
        (bom_preview_snapshot->'totals' ? 'roll_total_cost_landed')
        OR (bom_preview_snapshot->'totals' ? 'bom_total_cost_landed')
        OR (bom_preview_snapshot->'totals' ? 'accessories_total_cost_landed')
        OR (bom_preview_snapshot->'totals' ? 'unit_product_cost_landed')
        OR (bom_preview_snapshot->'totals' ? 'total_cost_landed_without_labor')
        OR (bom_preview_snapshot->'totals' ? 'total_cost_with_labor')
      )
  LOOP
    v_totals := v_row.bom_preview_snapshot->'totals';

    -- Build cleaned totals: keep all non-_landed keys, copy _landed -> new, then strip _landed
    v_cleaned := v_totals;

    -- Copy legacy values to new keys when new key is missing (ensure we have values)
    IF NOT (v_cleaned ? 'roll_total_cost') OR (v_cleaned->>'roll_total_cost') IS NULL OR (v_cleaned->>'roll_total_cost') = '' THEN
      v_cleaned := jsonb_set(v_cleaned, '{roll_total_cost}', COALESCE(v_cleaned->'roll_total_cost_landed', '0'::jsonb), true);
    END IF;
    IF NOT (v_cleaned ? 'bom_total_cost') OR (v_cleaned->>'bom_total_cost') IS NULL OR (v_cleaned->>'bom_total_cost') = '' THEN
      v_cleaned := jsonb_set(v_cleaned, '{bom_total_cost}', COALESCE(v_cleaned->'bom_total_cost_landed', '0'::jsonb), true);
    END IF;
    IF NOT (v_cleaned ? 'accessories_total_cost') OR (v_cleaned->>'accessories_total_cost') IS NULL OR (v_cleaned->>'accessories_total_cost') = '' THEN
      v_cleaned := jsonb_set(v_cleaned, '{accessories_total_cost}', COALESCE(v_cleaned->'accessories_total_cost_landed', '0'::jsonb), true);
    END IF;
    IF NOT (v_cleaned ? 'unit_product_cost') OR (v_cleaned->>'unit_product_cost') IS NULL OR (v_cleaned->>'unit_product_cost') = '' THEN
      v_cleaned := jsonb_set(v_cleaned, '{unit_product_cost}', COALESCE(v_cleaned->'unit_product_cost_landed', v_cleaned->'total_cost_landed_without_labor', '0'::jsonb), true);
    END IF;
    IF NOT (v_cleaned ? 'total_cost') OR (v_cleaned->>'total_cost') IS NULL OR (v_cleaned->>'total_cost') = '' THEN
      v_cleaned := jsonb_set(v_cleaned, '{total_cost}', COALESCE(v_cleaned->'total_cost_with_labor', v_cleaned->'total_cost_landed_without_labor', '0'::jsonb), true);
    END IF;

    -- Remove all legacy _landed keys
    v_cleaned := v_cleaned - 'roll_total_cost_landed' - 'bom_total_cost_landed' - 'accessories_total_cost_landed'
      - 'unit_product_cost_landed' - 'total_cost_landed_without_labor' - 'total_cost_with_labor';

    UPDATE public."ConfiguredProducts"
    SET bom_preview_snapshot = jsonb_set(
      bom_preview_snapshot,
      '{totals}',
      v_cleaned,
      true
    ), updated_at = now()
    WHERE id = v_row.id;

    v_updated := v_updated + 1;
  END LOOP;

  RAISE NOTICE 'bom_preview_snapshot migration: updated % rows', v_updated;
END $$;

-- Verification queries (run manually after migration):
-- a) Count rows where totals still contains _landed (should be 0):
--    SELECT count(*) FROM public."ConfiguredProducts" cp
--    WHERE cp.bom_preview_snapshot IS NOT NULL
--      AND jsonb_typeof(cp.bom_preview_snapshot->'totals') = 'object'
--      AND (
--        (cp.bom_preview_snapshot->'totals' ? 'roll_total_cost_landed')
--        OR (cp.bom_preview_snapshot->'totals' ? 'bom_total_cost_landed')
--        OR (cp.bom_preview_snapshot->'totals' ? 'accessories_total_cost_landed')
--        OR (cp.bom_preview_snapshot->'totals' ? 'unit_product_cost_landed')
--        OR (cp.bom_preview_snapshot->'totals' ? 'total_cost_landed_without_labor')
--        OR (cp.bom_preview_snapshot->'totals' ? 'total_cost_with_labor')
--      );
-- b) Sample row with totals (expect total_cost, roll_total_cost, bom_total_cost, etc.):
--    SELECT id, bom_preview_snapshot->'totals' AS totals
--    FROM public."ConfiguredProducts"
--    WHERE bom_preview_snapshot IS NOT NULL AND bom_preview_snapshot->'totals' != '{}'::jsonb LIMIT 1;
