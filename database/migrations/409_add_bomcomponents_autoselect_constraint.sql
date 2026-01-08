-- ====================================================
-- Migration: Add DB Constraint for Auto-Select Required Fields
-- ====================================================
-- Adds a CHECK constraint to ensure auto-select components
-- always have required fields (sku_resolution_rule, qty_type, uom)
-- ====================================================

-- Drop constraint if it exists (for idempotency)
ALTER TABLE "BOMComponents"
DROP CONSTRAINT IF EXISTS bomcomponents_autoselect_required_fields;

-- Add constraint to ensure auto-select rows are complete
-- ✅ FIX: Allow qty_formula_code as alternative to qty_type
ALTER TABLE "BOMComponents"
ADD CONSTRAINT bomcomponents_autoselect_required_fields
CHECK (
  auto_select IS NOT TRUE
  OR (
    sku_resolution_rule IS NOT NULL
    AND (qty_type IS NOT NULL OR qty_formula_code IS NOT NULL)
    AND uom IS NOT NULL
    AND uom != ''
  )
);

COMMENT ON CONSTRAINT bomcomponents_autoselect_required_fields ON "BOMComponents" IS 
  'Ensures auto-select components have required fields: sku_resolution_rule, qty_type, and uom must not be NULL or empty.';

