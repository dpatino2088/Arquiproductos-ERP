-- ====================================================
-- Migration 237: Diagnose Backfill and Regeneration Issues
-- ====================================================
-- Diagnostic queries to understand why backfill and regeneration didn't work
-- ====================================================

-- ====================================================
-- DIAGNOSIS 1: Check if QuoteLines have width_m for backfill
-- ====================================================

SELECT 
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE width_m IS NOT NULL) as with_width_m,
    COUNT(*) FILTER (WHERE width_m IS NULL) as without_width_m,
    COUNT(*) FILTER (WHERE product_type IN ('Roller Shade', 'Dual Shade', 'Triple Shade')) as roller_shade_types,
    COUNT(*) FILTER (WHERE product_type IN ('Roller Shade', 'Dual Shade', 'Triple Shade') AND width_m IS NOT NULL) as roller_with_width
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- DIAGNOSIS 2: Check actual product_type values
-- ====================================================

SELECT 
    product_type,
    COUNT(*) as count,
    COUNT(*) FILTER (WHERE width_m IS NOT NULL) as with_width_m,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL) as with_tube_type,
    COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) as with_os_variant
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days'
GROUP BY product_type
ORDER BY count DESC;

-- ====================================================
-- DIAGNOSIS 3: Check if backfill UPDATE actually ran
-- ====================================================
-- Sample QuoteLines to see their current state
-- ====================================================

SELECT 
    id,
    product_type,
    width_m,
    height_m,
    drive_type,
    tube_type,
    operating_system_variant,
    created_at
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days'
ORDER BY created_at DESC
LIMIT 10;

-- ====================================================
-- DIAGNOSIS 4: Check QuoteLineComponents regeneration
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.product_type,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as configured_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor' AND qlc.deleted = false) as motor_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'tube' AND qlc.deleted = false) as tube_components
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days'
GROUP BY ql.id, ql.product_type, ql.drive_type, ql.tube_type, ql.operating_system_variant
ORDER BY ql.created_at DESC
LIMIT 10;

-- ====================================================
-- DIAGNOSIS 5: Check if generate_configured_bom_for_quote_line exists
-- ====================================================

SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name = 'generate_configured_bom_for_quote_line';

-- ====================================================
-- DIAGNOSIS 6: Manual backfill test for one QuoteLine
-- ====================================================
-- This shows what the backfill should do
-- ====================================================

SELECT 
    id,
    product_type,
    width_m,
    CASE
        WHEN width_m IS NOT NULL AND width_m < 0.042 THEN 'RTU-42'
        WHEN width_m IS NOT NULL AND width_m < 0.065 THEN 'RTU-65'
        WHEN width_m IS NOT NULL THEN 'RTU-80'
        ELSE NULL
    END as inferred_tube_type,
    tube_type as current_tube_type,
    CASE 
        WHEN drive_type IS NOT NULL THEN 'standard_m'
        ELSE NULL
    END as inferred_os_variant,
    operating_system_variant as current_os_variant
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days'
    AND (tube_type IS NULL OR operating_system_variant IS NULL)
ORDER BY created_at DESC
LIMIT 5;



