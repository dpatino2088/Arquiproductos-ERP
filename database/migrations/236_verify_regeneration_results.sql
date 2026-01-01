-- ====================================================
-- Migration 236: Verify Regeneration Results
-- ====================================================
-- Quick verification queries to confirm backfill and regeneration worked
-- ====================================================

-- ====================================================
-- VERIFICATION 1: Check Configuration Fields Backfill
-- ====================================================

SELECT 
    'Configuration Fields' as check_type,
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL) as with_tube_type,
    COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL AND operating_system_variant IS NOT NULL) as with_both,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tube_type IS NOT NULL) / NULLIF(COUNT(*), 0), 2) as pct_with_tube_type,
    ROUND(100.0 * COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) / NULLIF(COUNT(*), 0), 2) as pct_with_os_variant
FROM "QuoteLines"
WHERE deleted = false
    AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- VERIFICATION 2: Check QuoteLineComponents Regeneration
-- ====================================================

SELECT 
    'QuoteLineComponents' as check_type,
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_components,
    COUNT(qlc.id) as total_components,
    ROUND(COUNT(qlc.id)::numeric / NULLIF(COUNT(DISTINCT qlc.quote_line_id), 0), 2) as avg_components_per_line
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
WHERE ql.deleted = false
    AND ql.product_type_id IS NOT NULL
    AND ql.created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- VERIFICATION 3: Check Conditional Components (Motor)
-- ====================================================

SELECT 
    'Motor Components' as check_type,
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
-- VERIFICATION 4: Check Tube SKU Variation
-- ====================================================

SELECT 
    'Tube SKU Variation' as check_type,
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
-- VERIFICATION 5: Check All Required Roles
-- ====================================================

SELECT 
    qlc.component_role,
    COUNT(DISTINCT qlc.id) as component_count,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_role,
    COUNT(DISTINCT qlc.catalog_item_id) as unique_skus
FROM "QuoteLineComponents" qlc
WHERE qlc.deleted = false
    AND qlc.source = 'configured_component'
    AND qlc.quote_line_id IN (
        SELECT id FROM "QuoteLines" 
        WHERE deleted = false 
        AND created_at > NOW() - INTERVAL '30 days'
    )
GROUP BY qlc.component_role
ORDER BY component_count DESC;

-- ====================================================
-- VERIFICATION 6: Summary - Overall Health Check
-- ====================================================

SELECT 
    'Overall Health' as check_type,
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) as with_tube_type,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') as with_motor_drive,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') as side_channel_components,
    COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role = 'tube') as unique_tube_skus,
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

