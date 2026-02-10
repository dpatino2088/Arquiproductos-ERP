-- ============================================================
-- Freeze proposal snapshot on sent
-- ============================================================
-- When Proposal status changes from 'draft' to 'sent', capture
-- a snapshot of QuoteLine data (and ConfiguredProduct.measurements/accessories)
-- into ProposalLines.quote_line_snapshot so print/PDF no longer
-- depend on live QuoteLines/ConfiguredProducts.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Add columns (if not exist)
-- ============================================================
ALTER TABLE public."ProposalLines"
  ADD COLUMN IF NOT EXISTS quote_line_snapshot jsonb;

ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS snapshot_version integer DEFAULT 1;

COMMENT ON COLUMN public."ProposalLines"."quote_line_snapshot" IS 'Snapshot of QuoteLine + ConfiguredProduct data when proposal status changed to sent. Used by ProposalPrint when present.';
COMMENT ON COLUMN public."Proposals"."sent_at" IS 'Timestamp when proposal status was first set to sent (used for freeze snapshot).';
COMMENT ON COLUMN public."Proposals"."snapshot_version" IS 'Version of snapshot schema for future migrations.';

-- ============================================================
-- 2) Function: freeze_proposal_snapshot(p_proposal_id uuid)
-- ============================================================
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

  -- For each ProposalLine from_quote with null quote_line_snapshot
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

COMMENT ON FUNCTION public.freeze_proposal_snapshot(uuid) IS 'Captures QuoteLine + ConfiguredProduct snapshot into ProposalLines.quote_line_snapshot. Idempotent: only updates lines where quote_line_snapshot is null.';

-- ============================================================
-- 3) Trigger: after Proposals status draft -> sent
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_proposals_freeze_snapshot_on_sent()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'draft' AND NEW.status = 'sent' THEN
    PERFORM public.freeze_proposal_snapshot(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposals_freeze_snapshot_on_sent ON public."Proposals";
CREATE TRIGGER trg_proposals_freeze_snapshot_on_sent
  AFTER UPDATE OF status ON public."Proposals"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_proposals_freeze_snapshot_on_sent();

-- ============================================================
-- 4) Backfill: proposals already sent (optional one-time)
-- ============================================================
-- Run freeze_proposal_snapshot for proposals already in 'sent' or 'accepted'
-- that have no quote_line_snapshot yet
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT id FROM public."Proposals"
    WHERE deleted = false
      AND status IN ('sent', 'accepted')
      AND EXISTS (
        SELECT 1 FROM public."ProposalLines" pl
        WHERE pl.proposal_id = public."Proposals".id
          AND pl.deleted = false
          AND pl.line_type = 'from_quote'
          AND pl.quote_line_snapshot IS NULL
      )
  LOOP
    PERFORM public.freeze_proposal_snapshot(r.id);
  END LOOP;
END $$;

COMMIT;
