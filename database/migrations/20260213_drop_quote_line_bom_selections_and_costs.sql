-- ============================================================================
-- Migration: Drop QuoteLineBOMSelections and QuoteLineCosts
-- Date: 2026-02-13
-- Description: Remove legacy tables. BOM selections and costs are derived from
--              ConfiguredProducts / QuoteLines / QuoteLineComponents.
-- ============================================================================

-- Triggers on QuoteLineCosts (drop before table so no dangling refs in some PG versions)
DROP TRIGGER IF EXISTS trg_recalculate_price_on_cost_update ON public."QuoteLineCosts";

-- Drop tables (order: no FK from one to the other)
DROP TABLE IF EXISTS public."QuoteLineBOMSelections" CASCADE;
DROP TABLE IF EXISTS public."QuoteLineCosts" CASCADE;
