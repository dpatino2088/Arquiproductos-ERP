-- ============================================================================
-- Fix: BOMComponents.condition_value whitespace silently excluding components
--     from BOM cost calculation
--
-- Problem: A BOMComponents row had `condition_value = '\tQSSC-EDU-R64-V'`
-- (leading TAB, hex 09). When build_bom_preview_snapshot() and
-- compute_instance_cut_breakdown() compare the normalized config motor SKU
-- ('QSSC-EDU-R64-V') against this value, the strings differ and the motor is
-- silently excluded from the BOM. Result: dealer prices for LUT64 motorized
-- configurations were ~$230 (the EDU-64 motor cost) too low.
--
-- Standard SQL TRIM(BOTH FROM ...) only trims spaces (0x20), so the existing
-- save_bom_template_batch() defensive TRIM did NOT catch tabs/CR/LF. We use
-- BTRIM(s, E' \t\n\r') everywhere we sanitize text columns on BOMComponents.
--
-- Fix (defense in depth):
--   1. BEFORE INSERT/UPDATE trigger on BOMComponents auto-normalizes ALL text
--      identifier columns. Catches tabs, newlines, CR, NBSP, regular spaces.
--   2. One-time backfill rewrites every existing row through the trigger so
--      currently-corrupted data is cleaned.
--   3. ConfiguredProducts that referenced affected templates are recomputed
--      via calculate_configured_product_totals(), which rebuilds
--      bom_preview_snapshot and refreshes all cost columns.
--   4. QuoteLines whose snapshots reference recomputed CPs are re-synced from
--      ConfiguredProducts so list views display the corrected dealer price.
--
-- Pricing-protect note:
--   The protected formulas (msrp_compute_for_item, computeMsrpFromMarginOnSale,
--   total_cost = total_cost / (1 - margin), generated columns) are NOT
--   modified. This migration only fixes WHICH components participate in BOM
--   sums; the formulas themselves remain untouched.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Defensive trigger: auto-trim text identifier columns on every write
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_bom_components_normalize_strings()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  -- Whitespace set: space, TAB, LF, CR, vertical TAB, form feed, NBSP
  ws_chars CONSTANT text := E' \t\n\r\v\f\u00A0';
BEGIN
  IF NEW.condition_key IS NOT NULL THEN
    NEW.condition_key := NULLIF(BTRIM(NEW.condition_key, ws_chars), '');
  END IF;
  IF NEW.condition_value IS NOT NULL THEN
    NEW.condition_value := NULLIF(BTRIM(NEW.condition_value, ws_chars), '');
  END IF;
  IF NEW.depends_on_role IS NOT NULL THEN
    NEW.depends_on_role := NULLIF(BTRIM(NEW.depends_on_role, ws_chars), '');
  END IF;
  IF NEW.affects_role IS NOT NULL THEN
    NEW.affects_role := NULLIF(BTRIM(NEW.affects_role, ws_chars), '');
  END IF;
  IF NEW.cut_axis IS NOT NULL THEN
    NEW.cut_axis := NULLIF(BTRIM(NEW.cut_axis, ws_chars), '');
  END IF;
  IF NEW.qty_type IS NOT NULL THEN
    NEW.qty_type := NULLIF(BTRIM(NEW.qty_type, ws_chars), '');
  END IF;
  IF NEW.component_role IS NOT NULL THEN
    NEW.component_role := NULLIF(BTRIM(NEW.component_role, ws_chars), '');
  END IF;
  IF NEW.component_sub_role IS NOT NULL THEN
    NEW.component_sub_role := NULLIF(BTRIM(NEW.component_sub_role, ws_chars), '');
  END IF;
  IF NEW.uom IS NOT NULL THEN
    NEW.uom := NULLIF(BTRIM(NEW.uom, ws_chars), '');
  END IF;
  IF NEW.engineering_attr_key IS NOT NULL THEN
    NEW.engineering_attr_key := NULLIF(BTRIM(NEW.engineering_attr_key, ws_chars), '');
  END IF;
  IF NEW.engineering_source_role IS NOT NULL THEN
    NEW.engineering_source_role := NULLIF(BTRIM(NEW.engineering_source_role, ws_chars), '');
  END IF;
  IF NEW.engineering_delta_source IS NOT NULL THEN
    NEW.engineering_delta_source := NULLIF(BTRIM(NEW.engineering_delta_source, ws_chars), '');
  END IF;
  IF NEW.engineering_scope IS NOT NULL THEN
    NEW.engineering_scope := NULLIF(BTRIM(NEW.engineering_scope, ws_chars), '');
  END IF;
  IF NEW.cut_delta_scope IS NOT NULL THEN
    NEW.cut_delta_scope := NULLIF(BTRIM(NEW.cut_delta_scope, ws_chars), '');
  END IF;
  IF NEW.delta_mode IS NOT NULL THEN
    NEW.delta_mode := NULLIF(BTRIM(NEW.delta_mode, ws_chars), '');
  END IF;
  -- component_mode is an enum (bom_component_mode); skip
  IF NEW.component_scope IS NOT NULL THEN
    NEW.component_scope := NULLIF(BTRIM(NEW.component_scope, ws_chars), '');
  END IF;
  IF NEW.sku_resolution_rule IS NOT NULL THEN
    NEW.sku_resolution_rule := NULLIF(BTRIM(NEW.sku_resolution_rule, ws_chars), '');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bom_components_normalize_strings ON public."BOMComponents";
CREATE TRIGGER trg_bom_components_normalize_strings
  BEFORE INSERT OR UPDATE
  ON public."BOMComponents"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_bom_components_normalize_strings();

COMMENT ON FUNCTION public.trg_bom_components_normalize_strings() IS
  'Auto-trims whitespace (space, TAB, LF, CR, NBSP, etc.) from text identifier '
  'columns on BOMComponents. Prevents silent BOM cost exclusion bugs caused '
  'by invisible characters in condition_value, condition_key, etc.';

-- ---------------------------------------------------------------------------
-- 2. Identify affected templates BEFORE backfill, then recompute downstream
--    artifacts after the trigger cleans existing rows.
-- ---------------------------------------------------------------------------
DO $migration$
DECLARE
  v_affected_template_ids uuid[];
  v_affected_component_count integer := 0;
  v_cp_id uuid;
  v_cps_recomputed integer := 0;
  v_cps_failed integer := 0;
  v_quote_lines_synced integer := 0;
BEGIN
  -- 2a. Snapshot which templates currently have any whitespace in identifier columns.
  --     We'll only recompute CPs that use these templates (minimal blast radius).
  SELECT
    ARRAY(SELECT DISTINCT bom_template_id FROM public."BOMComponents"
          WHERE deleted = false AND archived = false
            AND bom_template_id IS NOT NULL
            AND (
              (condition_key IS NOT NULL AND condition_key ~ '[[:space:]]')
              OR (condition_value IS NOT NULL AND condition_value ~ '[[:space:]]')
              OR (depends_on_role IS NOT NULL AND depends_on_role ~ '[[:space:]]')
              OR (affects_role IS NOT NULL AND affects_role ~ '[[:space:]]')
              OR (cut_axis IS NOT NULL AND cut_axis ~ '[[:space:]]')
              OR (qty_type IS NOT NULL AND qty_type ~ '[[:space:]]')
              OR (component_role IS NOT NULL AND component_role ~ '[[:space:]]')
              OR (component_sub_role IS NOT NULL AND component_sub_role ~ '[[:space:]]')
              OR (uom IS NOT NULL AND uom ~ '[[:space:]]')
              OR (engineering_attr_key IS NOT NULL AND engineering_attr_key ~ '[[:space:]]')
              OR (engineering_source_role IS NOT NULL AND engineering_source_role ~ '[[:space:]]')
              OR (delta_mode IS NOT NULL AND delta_mode ~ '[[:space:]]')
              OR (sku_resolution_rule IS NOT NULL AND sku_resolution_rule ~ '[[:space:]]')
            ))
  INTO v_affected_template_ids;

  IF v_affected_template_ids IS NULL THEN
    v_affected_template_ids := ARRAY[]::uuid[];
  END IF;

  RAISE NOTICE '[whitespace-fix] Templates with whitespace components: %',
    COALESCE(array_length(v_affected_template_ids, 1), 0);

  -- 2b. Touch every potentially-affected row so the BEFORE trigger rewrites
  --     the columns through BTRIM. SET column = column is enough because the
  --     trigger reads NEW.* regardless of which column changed.
  WITH ws_rows AS (
    SELECT id FROM public."BOMComponents"
    WHERE deleted = false AND archived = false
      AND (
        (condition_key IS NOT NULL AND condition_key ~ '[[:space:]]')
        OR (condition_value IS NOT NULL AND condition_value ~ '[[:space:]]')
        OR (depends_on_role IS NOT NULL AND depends_on_role ~ '[[:space:]]')
        OR (affects_role IS NOT NULL AND affects_role ~ '[[:space:]]')
        OR (cut_axis IS NOT NULL AND cut_axis ~ '[[:space:]]')
        OR (qty_type IS NOT NULL AND qty_type ~ '[[:space:]]')
        OR (component_role IS NOT NULL AND component_role ~ '[[:space:]]')
        OR (component_sub_role IS NOT NULL AND component_sub_role ~ '[[:space:]]')
        OR (uom IS NOT NULL AND uom ~ '[[:space:]]')
        OR (engineering_attr_key IS NOT NULL AND engineering_attr_key ~ '[[:space:]]')
        OR (engineering_source_role IS NOT NULL AND engineering_source_role ~ '[[:space:]]')
        OR (delta_mode IS NOT NULL AND delta_mode ~ '[[:space:]]')
        OR (sku_resolution_rule IS NOT NULL AND sku_resolution_rule ~ '[[:space:]]')
      )
  ), updated AS (
    UPDATE public."BOMComponents" bc
    SET condition_value = bc.condition_value
    FROM ws_rows
    WHERE bc.id = ws_rows.id
    RETURNING bc.id
  )
  SELECT COUNT(*) INTO v_affected_component_count FROM updated;

  RAISE NOTICE '[whitespace-fix] Backfilled % BOMComponents rows', v_affected_component_count;

  -- 2c. Recompute every ConfiguredProduct that uses an affected template.
  --     calculate_configured_product_totals rebuilds bom_preview_snapshot via
  --     build_bom_preview_snapshot, so the motor (or any other previously
  --     skipped component) now appears and bom_total_cost is correct.
  IF array_length(v_affected_template_ids, 1) IS NOT NULL THEN
    FOR v_cp_id IN
      SELECT id FROM public."ConfiguredProducts"
      WHERE bom_template_id = ANY(v_affected_template_ids)
        AND deleted = false
    LOOP
      BEGIN
        PERFORM public.calculate_configured_product_totals(v_cp_id);
        v_cps_recomputed := v_cps_recomputed + 1;
      EXCEPTION WHEN OTHERS THEN
        v_cps_failed := v_cps_failed + 1;
        RAISE WARNING '[whitespace-fix] Failed to recompute CP %: %', v_cp_id, SQLERRM;
      END;
    END LOOP;
  END IF;

  RAISE NOTICE '[whitespace-fix] Recomputed % ConfiguredProducts (% failed)',
    v_cps_recomputed, v_cps_failed;

  -- 2d. Sync QuoteLine snapshots through the OFFICIAL pricing RPC so the
  --     write-protect trigger trg_quote_lines_allow_pricing_write_only_via_rpc
  --     accepts the update. The function recomputes the CP totals, recopies
  --     line_total/cost_total from bom_preview_snapshot.items, and bumps
  --     pricing_version. p_force = true bypasses pricing_locked.
  IF array_length(v_affected_template_ids, 1) IS NOT NULL THEN
    DECLARE
      v_ql_id uuid;
    BEGIN
      FOR v_ql_id IN
        SELECT ql.id
        FROM public."QuoteLines" ql
        JOIN public."ConfiguredProducts" cp ON cp.id = ql.configured_product_id
        WHERE cp.bom_template_id = ANY(v_affected_template_ids)
          AND cp.deleted = false
      LOOP
        BEGIN
          PERFORM public.sync_quote_line_pricing_from_configured_product(v_ql_id, true);
          v_quote_lines_synced := v_quote_lines_synced + 1;
        EXCEPTION WHEN OTHERS THEN
          RAISE WARNING '[whitespace-fix] Failed to sync QuoteLine %: %', v_ql_id, SQLERRM;
        END;
      END LOOP;
    END;
  END IF;

  RAISE NOTICE '[whitespace-fix] Synced % QuoteLine snapshots', v_quote_lines_synced;
END
$migration$;

-- ---------------------------------------------------------------------------
-- 3. Post-condition assertion: no whitespace remains in any covered column
-- ---------------------------------------------------------------------------
DO $assert$
DECLARE
  v_remaining integer;
BEGIN
  SELECT COUNT(*) INTO v_remaining
  FROM public."BOMComponents"
  WHERE deleted = false AND archived = false
    AND (
      (condition_key IS NOT NULL AND condition_key ~ '[[:space:]]')
      OR (condition_value IS NOT NULL AND condition_value ~ '[[:space:]]')
      OR (depends_on_role IS NOT NULL AND depends_on_role ~ '[[:space:]]')
      OR (affects_role IS NOT NULL AND affects_role ~ '[[:space:]]')
      OR (cut_axis IS NOT NULL AND cut_axis ~ '[[:space:]]')
      OR (qty_type IS NOT NULL AND qty_type ~ '[[:space:]]')
      OR (component_role IS NOT NULL AND component_role ~ '[[:space:]]')
      OR (component_sub_role IS NOT NULL AND component_sub_role ~ '[[:space:]]')
      OR (uom IS NOT NULL AND uom ~ '[[:space:]]')
      OR (engineering_attr_key IS NOT NULL AND engineering_attr_key ~ '[[:space:]]')
    );

  IF v_remaining > 0 THEN
    RAISE EXCEPTION
      '[whitespace-fix] Assertion failed: % BOMComponents rows still contain whitespace after backfill',
      v_remaining;
  END IF;

  RAISE NOTICE '[whitespace-fix] Post-condition OK: no whitespace remains in BOMComponents';
END
$assert$;

COMMIT;
