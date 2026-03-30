-- Drop overly strict CHECK constraints on QuoteLines pricing coherence.
--
-- Three constraints enforced that totals = unit_snapshot × quantity at ALL times:
--   chk_quotelines_dealer_price_coherent: dealer_price_total ≈ unit_dealer_price_snapshot × qty
--   chk_quotelines_msrp_coherent:         msrp ≈ unit_msrp_total_snapshot × qty
--   chk_quotelines_total_cost_coherent:   total_cost ≈ unit_cost_total_snapshot × qty
--
-- These fail when the frontend updates `quantity` in a structural update BEFORE
-- the pricing sync RPC can recalculate the totals. The pricing trigger blocks
-- writing pricing fields from non-RPC context, creating a deadlock:
--   1. Structural update changes quantity → constraint fails (old totals)
--   2. Can't include totals in structural update (pricing trigger blocks it)
--   3. Pricing sync RPC would fix it, but never reaches because step 1 fails
--
-- Consistency is already enforced by:
--   - commit_configured_product_to_quote_line (sets all atomically on INSERT)
--   - sync_quote_line_pricing_from_configured_product (recalculates on sync)
--   - trg_quote_lines_pricing_write_via_rpc_only (prevents ad-hoc writes)
--
-- chk_quotelines_unit_snapshots_non_neg (>= 0) is kept for basic integrity.

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_dealer_price_coherent;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_msrp_coherent;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_total_cost_coherent;
