-- ============================================================================
-- Fix: tg_require_quote_lines_before_approval()
-- Bug: COALESCE(NEW.status, '') evaluated '' against quote_status enum,
--      causing `invalid input value for enum quote_status: ""` (22P02) on any
--      Quotes UPDATE that touched the status column (e.g. approve flow).
-- Fix: cast the enum to text BEFORE COALESCE so the empty-string fallback
--      stays in text space and is never coerced into quote_status.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.tg_require_quote_lines_before_approval()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote_line_count integer := 0;
  v_custom_line_count integer := 0;
  v_allow_custom_only boolean := false;
BEGIN
  IF COALESCE(NEW.deleted, false) = false
     AND lower(COALESCE(NEW.status::text, '')) = 'approved'
     AND lower(COALESCE(OLD.status::text, '')) IS DISTINCT FROM 'approved' THEN

    SELECT COUNT(*)
      INTO v_quote_line_count
    FROM public."QuoteLines" ql
    WHERE ql.quote_id = NEW.id;

    IF COALESCE(v_quote_line_count, 0) > 0 THEN
      RETURN NEW;
    END IF;

    SELECT COALESCE(dcp.allow_custom_only_proposals, false)
      INTO v_allow_custom_only
    FROM public."DealerConfiguratorPolicies" dcp
    WHERE dcp.organization_id = NEW.organization_id
      AND dcp.dealer_id = NEW.dealer_id
    LIMIT 1;

    IF v_allow_custom_only THEN
      SELECT COUNT(*)
        INTO v_custom_line_count
      FROM public."Proposals" p
      JOIN public."ProposalLines" pl
        ON pl.proposal_id = p.id
      WHERE p.quote_id = NEW.id
        AND COALESCE(p.deleted, false) = false
        AND COALESCE(pl.deleted, false) = false
        AND pl.line_type = 'custom';

      IF COALESCE(v_custom_line_count, 0) > 0 THEN
        RETURN NEW;
      END IF;
    END IF;

    RAISE EXCEPTION 'Cannot approve quote without lines. Add at least one quote line or a custom proposal line before approval.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;
