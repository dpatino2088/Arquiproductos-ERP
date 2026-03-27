-- Add opening_direction from ConfiguredProducts.config_snapshot to
-- the frozen quote_line_snapshot so Drapery lines show the opening
-- type (Left Stack / Center Opening / Right Stack) instead of panel count.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.freeze_proposal_snapshot(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proposal RECORD;
  v_pl RECORD;
  v_ql RECORD;
  v_cp RECORD;
  v_snapshot jsonb;
  v_config jsonb;
  v_base_mode text;
  v_base_unit numeric(12,4);
  v_base_line numeric(12,4);
BEGIN
  SELECT id, status, sent_at INTO v_proposal
  FROM public."Proposals"
  WHERE id = p_proposal_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_proposal.status NOT IN ('sent', 'accepted') THEN
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
           ql.msrp, ql.unit_msrp, ql.configured_product_id
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
        'opening_direction', NULL,
        'base_price_mode', 'msrp',
        'base_unit_msrp', NULL,
        'base_line_msrp', NULL,
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

      v_base_mode := CASE WHEN v_ql.msrp IS NOT NULL AND v_ql.msrp > 0 THEN 'msrp' ELSE 'unit_msrp' END;
      v_base_unit := COALESCE(v_ql.unit_msrp, v_ql.msrp / NULLIF(v_ql.quantity, 0));
      v_base_line := COALESCE(v_ql.msrp, v_ql.unit_msrp * NULLIF(v_ql.quantity, 0));

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
        'measurements', COALESCE(v_config->'measurements', '{}'::jsonb),
        'accessories', v_config->'accessories',
        'opening_direction', COALESCE(v_config->>'opening_direction', v_config->>'openingDirection'),
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

-- Backfill: patch existing sent/accepted drapery snapshots with opening_direction
UPDATE public."ProposalLines" pl
SET quote_line_snapshot = pl.quote_line_snapshot || jsonb_build_object(
  'opening_direction',
  COALESCE(cp.config_snapshot->>'opening_direction', cp.config_snapshot->>'openingDirection')
)
FROM public."QuoteLines" ql
JOIN public."ConfiguredProducts" cp ON cp.id = ql.configured_product_id AND cp.deleted = false
WHERE pl.quote_line_id = ql.id
  AND pl.deleted = false
  AND pl.quote_line_snapshot IS NOT NULL
  AND (pl.quote_line_snapshot->>'opening_direction') IS NULL
  AND COALESCE(cp.config_snapshot->>'opening_direction', cp.config_snapshot->>'openingDirection') IS NOT NULL;
