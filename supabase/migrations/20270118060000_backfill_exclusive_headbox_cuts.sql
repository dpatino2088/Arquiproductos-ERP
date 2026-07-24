-- Backfill stored cuts after exclusive-headbox fix in compute_cut_breakdown_core.
-- Instances generated while both template headboxes were deducted are short by
-- ~4mm (tube) / ~8mm (bottom_bar). Sync BOMInstanceLines + WorkOrderTaskLines
-- to the recomputed resolved_mm so Assembly "Instancia almacenada" warnings clear.
--
-- Scope: only lines with a selected headbox UUID and a small positive delta
-- (3.5–20mm) so unrelated mismatches (e.g. headbox NONE drapery) are left alone.

DO $$
DECLARE
  v_bil_updated int := 0;
  v_wotl_updated int := 0;
BEGIN
  WITH targets AS (
    SELECT
      bil.id AS bil_id,
      ROUND((e->>'resolved_mm')::numeric, 1) AS new_cut,
      ROUND((e->>'resolved_mm')::numeric / 1000.0, 4) AS new_qty
    FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    JOIN public."SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
    JOIN public."ConfiguredProducts" cp ON cp.id = sol.configured_product_id
    JOIN LATERAL jsonb_array_elements(public.compute_instance_cut_breakdown(bil.bom_instance_id)) e
      ON e->>'role' = bil.part_role
    WHERE COALESCE(bil.deleted, false) = false
      AND bil.cut_length_mm IS NOT NULL
      AND bil.part_role IN ('tube', 'bottom_bar')
      AND COALESCE((e->>'match')::boolean, true) = false
      AND public.try_parse_uuid(cp.config_snapshot->>'headbox_item_id') IS NOT NULL
      AND (ROUND((e->>'resolved_mm')::numeric, 1) - bil.cut_length_mm) BETWEEN 3.5 AND 20
  ),
  upd_bil AS (
    UPDATE public."BOMInstanceLines" bil
    SET
      cut_length_mm = t.new_cut,
      qty = t.new_qty,
      updated_at = now()
    FROM targets t
    WHERE bil.id = t.bil_id
    RETURNING bil.id
  )
  SELECT COUNT(*) INTO v_bil_updated FROM upd_bil;

  -- Sync workstation / WO task lines from the corrected BOM instance cuts.
  WITH synced AS (
    UPDATE public."WorkOrderTaskLines" wotl
    SET
      cut_length_mm = bil.cut_length_mm,
      qty = bil.qty
    FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    JOIN public."SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
    JOIN public."ConfiguredProducts" cp ON cp.id = sol.configured_product_id
    WHERE wotl.bom_instance_line_id = bil.id
      AND bil.part_role IN ('tube', 'bottom_bar')
      AND public.try_parse_uuid(cp.config_snapshot->>'headbox_item_id') IS NOT NULL
      AND (
        wotl.cut_length_mm IS DISTINCT FROM bil.cut_length_mm
        OR wotl.qty IS DISTINCT FROM bil.qty
      )
    RETURNING wotl.id
  )
  SELECT COUNT(*) INTO v_wotl_updated FROM synced;

  RAISE NOTICE 'backfill_exclusive_headbox_cuts: bil=% wotl=%', v_bil_updated, v_wotl_updated;
END $$;
