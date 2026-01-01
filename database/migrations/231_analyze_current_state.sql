-- ====================================================
-- Migration 231: Analyze Current BOM State
-- ====================================================
-- Diagnostic queries to understand current state after
-- implementing configuration fields
-- ====================================================

-- ====================================================
-- ANALYSIS 1: Check Configuration Field Coverage
-- ====================================================
-- Shows which QuoteLines have configuration fields set
-- ====================================================

SELECT 
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL) as with_tube_type,
    COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL AND operating_system_variant IS NOT NULL) as with_both,
    COUNT(*) FILTER (WHERE tube_type IS NULL OR operating_system_variant IS NULL) as missing_config,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tube_type IS NOT NULL) / COUNT(*), 2) as pct_with_tube_type,
    ROUND(100.0 * COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) / COUNT(*), 2) as pct_with_os_variant
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- ANALYSIS 2: Check QuoteLineComponents by Role
-- ====================================================
-- Detailed breakdown of components by role
-- ====================================================

SELECT 
    qlc.component_role,
    COUNT(DISTINCT qlc.id) as component_count,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_role,
    COUNT(DISTINCT qlc.catalog_item_id) as unique_skus,
    COUNT(*) FILTER (WHERE ci.id IS NULL) as null_catalog_items
FROM "QuoteLineComponents" qlc
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.deleted = false
    AND qlc.quote_line_id IN (
        SELECT id FROM "QuoteLines" 
        WHERE deleted = false 
        AND created_at > NOW() - INTERVAL '30 days'
    )
GROUP BY qlc.component_role
ORDER BY component_count DESC;

-- ====================================================
-- ANALYSIS 3: Check Side Channel Configuration
-- ====================================================
-- Why are side channel components missing?
-- ====================================================

SELECT 
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE side_channel = true) as with_side_channel,
    COUNT(*) FILTER (WHERE side_channel = false) as without_side_channel,
    COUNT(*) FILTER (WHERE side_channel IS NULL) as side_channel_null,
    COUNT(*) FILTER (WHERE side_channel = true AND side_channel_type IS NOT NULL) as with_side_channel_and_type
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- ANALYSIS 4: Sample QuoteLines Without Configuration
-- ====================================================
-- Show examples of QuoteLines missing configuration fields
-- ====================================================

SELECT 
    ql.id,
    ql.product_type,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    ql.side_channel,
    ql.width_m,
    ql.height_m,
    COUNT(qlc.id) as component_count
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND (ql.tube_type IS NULL OR ql.operating_system_variant IS NULL)
    AND ql.created_at > NOW() - INTERVAL '30 days'
GROUP BY ql.id
ORDER BY ql.created_at DESC
LIMIT 10;

-- ====================================================
-- ANALYSIS 5: Check BOMTemplate Roles
-- ====================================================
-- What roles are defined in BOMTemplates?
-- ====================================================

SELECT 
    bt.name as template_name,
    bc.component_role,
    COUNT(*) as role_count,
    COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as with_item_id,
    COUNT(*) FILTER (WHERE bc.auto_select = true) as auto_select,
    COUNT(*) FILTER (WHERE bc.block_condition IS NOT NULL) as with_block_condition
FROM "BOMTemplates" bt
JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
    AND bc.deleted = false
    AND bt.active = true
GROUP BY bt.name, bc.component_role
ORDER BY bt.name, bc.component_role;

-- ====================================================
-- ANALYSIS 6: Check for Side Channel Roles in Templates
-- ====================================================
-- Are side_channel_profile and side_channel_end_cap in templates?
-- ====================================================

SELECT 
    bt.name as template_name,
    bc.component_role,
    bc.block_condition,
    bc.component_item_id,
    ci.sku
FROM "BOMTemplates" bt
JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.deleted = false
    AND bc.deleted = false
    AND bt.active = true
    AND bc.component_role IN ('side_channel_profile', 'side_channel_end_cap')
ORDER BY bt.name, bc.component_role;

-- ====================================================
-- ANALYSIS 7: Compare Resolved SKUs by Configuration
-- ====================================================
-- Do different configurations produce different SKUs?
-- ====================================================

SELECT 
    ql.tube_type,
    ql.operating_system_variant,
    qlc.component_role,
    ci.sku,
    COUNT(*) as usage_count
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.tube_type IS NOT NULL
    AND qlc.component_role = 'tube'
GROUP BY ql.tube_type, ql.operating_system_variant, qlc.component_role, ci.sku
ORDER BY ql.tube_type, ci.sku;

-- ====================================================
-- ANALYSIS 8: Check Recent QuoteLineComponents Generation
-- ====================================================
-- When were QuoteLineComponents last generated?
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.created_at as quote_line_created,
    qlc.created_at as component_created,
    ql.tube_type,
    ql.operating_system_variant,
    COUNT(qlc.id) as component_count
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '7 days'
GROUP BY ql.id, ql.created_at, qlc.created_at, ql.tube_type, ql.operating_system_variant
ORDER BY ql.created_at DESC
LIMIT 10;

-- ====================================================
-- ANALYSIS 9: Check for Missing Resolutions
-- ====================================================
-- Which roles are failing to resolve to SKUs?
-- ====================================================

SELECT 
    qlc.component_role,
    COUNT(*) as total_components,
    COUNT(*) FILTER (WHERE qlc.catalog_item_id IS NULL) as null_catalog_item,
    COUNT(*) FILTER (WHERE ci.id IS NULL) as invalid_catalog_item,
    COUNT(*) FILTER (WHERE qlc.catalog_item_id IS NOT NULL AND ci.id IS NOT NULL) as resolved
FROM "QuoteLineComponents" qlc
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.deleted = false
    AND qlc.quote_line_id IN (
        SELECT id FROM "QuoteLines" 
        WHERE deleted = false 
        AND created_at > NOW() - INTERVAL '30 days'
    )
GROUP BY qlc.component_role
ORDER BY total_components DESC;

-- ====================================================
-- ANALYSIS 10: Recommendations
-- ====================================================
-- Summary with actionable recommendations
-- ====================================================

SELECT 
    'Configuration Fields' as category,
    CASE 
        WHEN COUNT(*) FILTER (WHERE tube_type IS NOT NULL) = 0 THEN 
            '❌ CRITICAL: No QuoteLines have tube_type set. Frontend must persist this field.'
        WHEN COUNT(*) FILTER (WHERE tube_type IS NOT NULL) < COUNT(*) * 0.5 THEN 
            '⚠️ WARNING: Less than 50% of QuoteLines have tube_type set.'
        ELSE 
            '✅ OK: Most QuoteLines have tube_type set.'
    END as status
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT 
    'Operating System Variant' as category,
    CASE 
        WHEN COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) = 0 THEN 
            '❌ CRITICAL: No QuoteLines have operating_system_variant set. Frontend must persist this field.'
        WHEN COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) < COUNT(*) * 0.5 THEN 
            '⚠️ WARNING: Less than 50% of QuoteLines have operating_system_variant set.'
        ELSE 
            '✅ OK: Most QuoteLines have operating_system_variant set.'
    END as status
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT 
    'Side Channel Components' as category,
    CASE 
        WHEN COUNT(*) FILTER (WHERE side_channel = true) = 0 THEN 
            'ℹ️ INFO: No QuoteLines have side_channel enabled. This is OK if not needed.'
        ELSE 
            '✅ OK: Some QuoteLines have side_channel enabled.'
    END as status
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT 
    'BOM Generation' as category,
    CASE 
        WHEN COUNT(DISTINCT qlc.id) = 0 THEN 
            '❌ CRITICAL: No QuoteLineComponents found. BOM generation may not be working.'
        WHEN COUNT(DISTINCT qlc.id) < COUNT(DISTINCT ql.id) * 2 THEN 
            '⚠️ WARNING: Few QuoteLineComponents per QuoteLine. Expected at least 5-10 components.'
        ELSE 
            '✅ OK: QuoteLineComponents are being generated.'
    END as status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';



