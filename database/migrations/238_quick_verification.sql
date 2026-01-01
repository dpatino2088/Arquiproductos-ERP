-- ====================================================
-- Migration 238: Quick Verification After Backfill and Regeneration
-- ====================================================
-- Quick check to confirm everything worked
-- ====================================================

-- ====================================================
-- QUICK CHECK 1: Configuration Fields
-- ====================================================

SELECT 
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL) as with_tube_type,
    COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL AND operating_system_variant IS NOT NULL) as with_both
FROM "QuoteLines"
WHERE deleted = false
    AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- QUICK CHECK 2: QuoteLineComponents
-- ====================================================

SELECT 
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_components,
    COUNT(qlc.id) as total_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'tube') as tube_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bracket') as bracket_components
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
WHERE ql.deleted = false
    AND ql.product_type_id IS NOT NULL
    AND ql.created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- QUICK CHECK 3: Motor Components for Motor Drive Types
-- ====================================================

SELECT 
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') as quote_lines_with_motor_drive,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as motor_adapter_components,
    CASE 
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') = 0 
        THEN '❌ MISSING: Motor components not created'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') > 0 
        THEN '✅ OK: Motor components present'
        ELSE 'ℹ️ INFO: No motor drive types in sample'
    END as status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.component_role IN ('motor', 'motor_adapter')
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- QUICK CHECK 4: Tube SKU Variation
-- ====================================================

SELECT 
    COUNT(DISTINCT ql.tube_type) as unique_tube_types,
    COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role = 'tube') as unique_tube_skus,
    CASE 
        WHEN COUNT(DISTINCT ql.tube_type) > 1 
            AND COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role = 'tube') > 1 
        THEN '✅ OK: Different SKUs for different tube types'
        WHEN COUNT(DISTINCT ql.tube_type) > 1 
            AND COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role = 'tube') = 1 
        THEN '❌ WRONG: Same SKU for different tube types'
        ELSE '⚠️ CHECK: Need more data'
    END as status
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.tube_type IS NOT NULL
    AND qlc.component_role = 'tube'
    AND ql.created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- QUICK CHECK 5: Overall Status
-- ====================================================

SELECT 
    'Overall Status' as check_type,
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) as with_tube_type,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') as with_motor_drive,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    CASE 
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) = 0 THEN '❌ CRITICAL: No tube_type'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) = 0 THEN '❌ CRITICAL: No operating_system_variant'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') = 0 
        THEN '❌ CRITICAL: Motor components missing'
        WHEN COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role = 'tube') <= 1 
            AND COUNT(DISTINCT ql.tube_type) > 1 
        THEN '⚠️ WARNING: Tube SKU variation not working'
        ELSE '✅ OK: Configuration and components look good'
    END as overall_status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';



