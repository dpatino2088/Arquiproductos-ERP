-- ============================================================================
-- Migration: Guard rail — block direct updates to QuoteLines pricing columns
-- Date: 2026-02-06
-- Description:
--   Only allow updates to msrp, unit_msrp, roll_msrp_snapshot, bom_msrp_snapshot,
--   roll_cost_snapshot, bom_cost_snapshot, total_cost, last_priced_at,
--   pricing_version, pricing_locked when the update is done from the allowed
--   RPCs (sync_quote_line_pricing_from_configured_product, commit_configured_product_to_quote_line).
--   RPCs must SET LOCAL app.allow_quote_line_pricing_update = 'true' before updating.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_quote_lines_guard_pricing_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing_changed boolean := false;
  v_allowed text;
BEGIN
  v_allowed := current_setting('app.allow_quote_line_pricing_update', true);

  IF (OLD.msrp IS DISTINCT FROM NEW.msrp)
     OR (OLD.unit_msrp IS DISTINCT FROM NEW.unit_msrp)
     OR (OLD.roll_msrp_snapshot IS DISTINCT FROM NEW.roll_msrp_snapshot)
     OR (OLD.bom_msrp_snapshot IS DISTINCT FROM NEW.bom_msrp_snapshot)
     OR (OLD.roll_cost_snapshot IS DISTINCT FROM NEW.roll_cost_snapshot)
     OR (OLD.bom_cost_snapshot IS DISTINCT FROM NEW.bom_cost_snapshot)
     OR (OLD.total_cost IS DISTINCT FROM NEW.total_cost)
     OR (OLD.last_priced_at IS DISTINCT FROM NEW.last_priced_at)
     OR (OLD.pricing_version IS DISTINCT FROM NEW.pricing_version)
     OR (OLD.pricing_locked IS DISTINCT FROM NEW.pricing_locked)
  THEN
    v_pricing_changed := true;
  END IF;

  IF v_pricing_changed AND COALESCE(trim(v_allowed), '') <> 'true' THEN
    RAISE EXCEPTION 'QuoteLines pricing columns (msrp, unit_msrp, snapshots, total_cost, last_priced_at, pricing_version, pricing_locked) can only be updated via sync_quote_line_pricing_from_configured_product or commit_configured_product_to_quote_line. Set app.allow_quote_line_pricing_update = true in the RPC.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS quote_lines_guard_pricing_update ON public."QuoteLines";
CREATE TRIGGER quote_lines_guard_pricing_update
  BEFORE UPDATE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_quote_lines_guard_pricing_update();

COMMENT ON FUNCTION public.trg_quote_lines_guard_pricing_update() IS
'Guard: only allow pricing column updates when app.allow_quote_line_pricing_update is set (by sync_quote_line_pricing_from_configured_product).';
