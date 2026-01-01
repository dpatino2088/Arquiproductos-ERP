-- ========================================
-- FIX: Set default bottom_rail_type for QuoteLines
-- ========================================
-- This script updates QuoteLines that have bottom_rail_type = NULL
-- to set it to 'standard' as the default value
-- ========================================

-- Update QuoteLines with NULL bottom_rail_type
UPDATE "QuoteLines"
SET 
  bottom_rail_type = 'standard',
  updated_at = now()
WHERE bottom_rail_type IS NULL
  AND deleted = false;

-- Verify the update
SELECT 
  'Verification: QuoteLines with bottom_rail_type' as check_name,
  COUNT(*) as total_quote_lines,
  COUNT(CASE WHEN bottom_rail_type IS NULL THEN 1 END) as null_count,
  COUNT(CASE WHEN bottom_rail_type = 'standard' THEN 1 END) as standard_count,
  COUNT(CASE WHEN bottom_rail_type = 'wrapped' THEN 1 END) as wrapped_count
FROM "QuoteLines"
WHERE deleted = false;

-- ========================================
-- NOTE: After running this script, you may need to:
-- 1. Regenerate BOM for affected QuoteLines by calling generate_configured_bom_for_quote_line
-- 2. Or re-approve the Quote to trigger the BOM generation
-- ========================================








