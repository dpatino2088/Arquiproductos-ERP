-- ============================================================================
-- Migration: Add drive_system_label to proposal quote_line_snapshot
-- Date: 2026-03-17
-- Description:
--   When freezing proposal snapshot (freeze_proposal_snapshot), include
--   drive_system_label as "Operation System | Manufacturer" (e.g. "Motorized | Lutron",
--   "Manual | Coulisse") from drive_type + CatalogItems -> Manufacturers.name.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.freeze_proposal_snapshot(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proposal_status text;
  v_pl RECORD;
  v_ql RECORD;
  v_config jsonb;
  v_base_unit numeric(12,4);
  v_base_line numeric(12,4);
  v_base_mode text;
  v_snapshot jsonb;
  v_drive_item_id uuid;
  v_motor_item_id uuid;
  v_system_item_id uuid;
  v_drive_type_label text;
  v_mfr_name text;
  v_drive_label text;
BEGIN
  SELECT status::text INTO v_proposal_status
  FROM public."Proposals"
  WHERE id = p_proposal_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_proposal_status NOT IN ('sent', 'accepted') THEN
    RETURN;
  END IF;

  FOR v_pl IN
    SELECT pl.id, pl.quote_line_id
    FROM public."ProposalLines" pl
    WHERE pl.proposal_id = p_proposal_id
      AND pl.deleted = false
      AND pl.line_type = 'from_quote'
      AND pl.quote_line_id IS NOT NULL
      AND pl.quote_line_snapshot IS NULL
  LOOP
    SELECT ql.name, ql.sku, ql.quantity, ql.width_m, ql.height_m, ql.area, ql.position,
           ql.product_type, ql.collection_name, ql.variant_name, ql.drive_type,
           ql.msrp, ql.unit_msrp_total_snapshot, ql.configured_product_id
    INTO v_ql
    FROM public."QuoteLines" ql
    WHERE ql.id = v_pl.quote_line_id
    LIMIT 1;

    IF NOT FOUND THEN
      v_snapshot := jsonb_build_object(
        'name', '—',
        'sku', NULL,
        'qty', 1,
        'width_m', NULL,
        'height_m', NULL,
        'measurements', '{}'::jsonb,
        'accessories', NULL,
        'base_price_mode', 'msrp',
        'base_unit_msrp', NULL,
        'base_line_msrp', NULL,
        'drive_system_label', NULL,
        'captured_at', now()
      );
    ELSE
      v_config := NULL;
      IF v_ql.configured_product_id IS NOT NULL THEN
        SELECT config_snapshot INTO v_config
        FROM public."ConfiguredProducts"
        WHERE id = v_ql.configured_product_id AND deleted = false
        LIMIT 1;
      END IF;

      v_drive_item_id := NULL;
      v_motor_item_id := NULL;
      IF v_config IS NOT NULL THEN
        IF v_config ? 'drive_item_id' THEN
          v_drive_item_id := (v_config->>'drive_item_id')::uuid;
        END IF;
        IF v_config ? 'motor_item_id' THEN
          v_motor_item_id := (v_config->>'motor_item_id')::uuid;
        END IF;
      END IF;

      v_drive_type_label := CASE WHEN v_ql.drive_type = 'motor' THEN 'Motorized' WHEN v_ql.drive_type = 'manual' THEN 'Manual' ELSE NULL END;
      v_system_item_id := CASE WHEN v_ql.drive_type = 'motor' THEN COALESCE(v_motor_item_id, v_drive_item_id) ELSE COALESCE(v_drive_item_id, v_motor_item_id) END;
      v_mfr_name := NULL;
      IF v_system_item_id IS NOT NULL THEN
        SELECT m.name INTO v_mfr_name
        FROM public."CatalogItems" ci
        LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
        WHERE ci.id = v_system_item_id AND ci.is_active = true
        LIMIT 1;
      END IF;
      IF v_mfr_name IS NULL AND v_system_item_id IS NOT NULL THEN
        SELECT NULLIF(TRIM(ci.manufacturer), '') INTO v_mfr_name
        FROM public."CatalogItems" ci
        WHERE ci.id = v_system_item_id AND ci.is_active = true
        LIMIT 1;
      END IF;
      v_drive_label := CASE
        WHEN v_drive_type_label IS NOT NULL AND v_mfr_name IS NOT NULL THEN v_drive_type_label || ' | ' || v_mfr_name
        WHEN v_mfr_name IS NOT NULL THEN COALESCE(v_drive_type_label, 'Drive') || ' | ' || v_mfr_name
        ELSE v_drive_type_label
      END;

      v_base_unit := COALESCE(v_ql.unit_msrp_total_snapshot, v_ql.msrp / NULLIF(v_ql.quantity, 0));
      v_base_line := COALESCE(v_ql.msrp, v_base_unit * COALESCE(NULLIF(v_ql.quantity, 0), 1));
      v_base_mode := CASE WHEN v_ql.msrp IS NOT NULL AND v_ql.msrp > 0 THEN 'msrp' ELSE 'unit_msrp' END;

      v_snapshot := jsonb_build_object(
        'name', v_ql.name,
        'sku', v_ql.sku,
        'qty', COALESCE(v_ql.quantity, 1),
        'width_m', v_ql.width_m,
        'height_m', v_ql.height_m,
        'area', v_ql.area,
        'position', v_ql.position,
        'product_type', v_ql.product_type,
        'collection_name', v_ql.collection_name,
        'variant_name', v_ql.variant_name,
        'drive_type', v_ql.drive_type,
        'drive_system_label', v_drive_label,
        'measurements', COALESCE(v_config->'measurements', '{}'::jsonb),
        'accessories', v_config->'accessories',
        'base_price_mode', v_base_mode,
        'base_unit_msrp', v_base_unit,
        'base_line_msrp', v_base_line,
        'captured_at', now()
      );
    END IF;

    UPDATE public."ProposalLines"
    SET quote_line_snapshot = v_snapshot
    WHERE id = v_pl.id;
  END LOOP;

  UPDATE public."Proposals"
  SET sent_at = COALESCE(sent_at, now())
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.freeze_proposal_snapshot(uuid) IS 'Captures QuoteLine + ConfiguredProduct snapshot. Uses unit_msrp_total_snapshot. Includes drive_system_label as "Operation System | Manufacturer" (e.g. Motorized | Lutron).';
