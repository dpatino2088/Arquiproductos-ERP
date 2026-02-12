-- ============================================================================
-- Migration: Normalize legacy roll_pricing_mode 'per_unit' → 'per_linear_meter'
-- Date: 2026-02-13
-- Description: Roll items should be priced per linear meter or per square meter.
--              'Per Unit ($/roll)' is legacy; normalize to per_linear_meter.
-- ============================================================================

UPDATE public."CatalogItems"
SET roll_pricing_mode = 'per_linear_meter'
WHERE is_roll = true
  AND roll_pricing_mode = 'per_unit';
