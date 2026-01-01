-- ====================================================
-- Migration 233: Verification Queries for Conditional Role Creation
-- ====================================================
-- Queries to verify that conditional roles are being created correctly
-- ====================================================

-- ====================================================
-- VERIFICATION 1: Check Side Channel Components
-- ====================================================
-- When side_channel = true, should have side_channel_profile and side_channel_end_cap
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.side_channel,
    ql.side_channel_type,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') as has_profile,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_end_cap') as has_end_cap,
    CASE 
        WHEN ql.side_channel = true AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') = 0 THEN '❌ MISSING: side_channel_profile'
        WHEN ql.side_channel = true AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_end_cap') = 0 THEN '❌ MISSING: side_channel_end_cap'
        WHEN ql.side_channel = true THEN '✅ OK: Side channel components present'
        WHEN ql.side_channel = false OR ql.side_channel IS NULL THEN '✅ OK: Side channel not enabled'
        ELSE '⚠️ UNKNOWN'
    END as validation_status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.component_role IN ('side_channel_profile', 'side_channel_end_cap')
    AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '7 days'
GROUP BY ql.id, ql.side_channel, ql.side_channel_type
ORDER BY ql.created_at DESC;

-- ====================================================
-- VERIFICATION 2: Check Motor Components
-- ====================================================
-- When drive_type = 'motor', should have motor and motor_adapter
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.drive_type,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') as has_motor,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as has_motor_adapter,
    CASE 
        WHEN ql.drive_type = 'motor' AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') = 0 THEN '❌ MISSING: motor'
        WHEN ql.drive_type = 'motor' AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') = 0 THEN '❌ MISSING: motor_adapter'
        WHEN ql.drive_type = 'motor' THEN '✅ OK: Motor components present'
        WHEN ql.drive_type = 'manual' OR ql.drive_type IS NULL THEN '✅ OK: Manual drive (no motor)'
        ELSE '⚠️ UNKNOWN'
    END as validation_status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.component_role IN ('motor', 'motor_adapter')
    AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '7 days'
GROUP BY ql.id, ql.drive_type
ORDER BY ql.created_at DESC;

-- ====================================================
-- VERIFICATION 3: Check Tube SKU Variation
-- ====================================================
-- RTU-42 vs RTU-65 vs RTU-80 should generate different SKUs
-- ====================================================

SELECT 
    ql.tube_type,
    qlc.component_role,
    ci.sku,
    COUNT(DISTINCT ql.id) as quote_line_count,
    COUNT(DISTINCT ci.id) as unique_sku_count,
    CASE 
        WHEN COUNT(DISTINCT ci.id) > 1 THEN '✅ OK: Different SKUs for different tube types'
        WHEN COUNT(DISTINCT ci.id) = 1 AND COUNT(DISTINCT ql.tube_type) > 1 THEN '❌ WRONG: Same SKU for different tube types'
        ELSE '⚠️ CHECK: Only one tube_type in sample'
    END as validation_status
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.tube_type IS NOT NULL
    AND qlc.component_role = 'tube'
    AND ql.created_at > NOW() - INTERVAL '30 days'
GROUP BY ql.tube_type, qlc.component_role, ci.sku
ORDER BY ql.tube_type, ci.sku;

-- ====================================================
-- VERIFICATION 4: Check Operating System Variant SKU Variation
-- ====================================================
-- Standard M vs Standard L should generate different SKUs
-- ====================================================

SELECT 
    ql.operating_system_variant,
    qlc.component_role,
    ci.sku,
    COUNT(DISTINCT ql.id) as quote_line_count,
    COUNT(DISTINCT ci.id) as unique_sku_count,
    CASE 
        WHEN COUNT(DISTINCT ci.id) > 1 THEN '✅ OK: Different SKUs for different OS variants'
        WHEN COUNT(DISTINCT ci.id) = 1 AND COUNT(DISTINCT ql.operating_system_variant) > 1 THEN '❌ WRONG: Same SKU for different OS variants'
        ELSE '⚠️ CHECK: Only one OS variant in sample'
    END as validation_status
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.operating_system_variant IS NOT NULL
    AND qlc.component_role IN ('operating_system_drive', 'motor')
    AND ql.created_at > NOW() - INTERVAL '30 days'
GROUP BY ql.operating_system_variant, qlc.component_role, ci.sku
ORDER BY ql.operating_system_variant, qlc.component_role, ci.sku;

-- ====================================================
-- VERIFICATION 5: Check All Required Roles Are Present
-- ====================================================
-- Core roles should always be present
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.drive_type,
    ql.side_channel,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'tube') as has_tube,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bracket') as has_bracket,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'fabric') as has_fabric,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bottom_rail_profile') as has_bottom_rail_profile,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bottom_rail_end_cap') as has_bottom_rail_end_cap,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'operating_system_drive') as has_operating_system_drive,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') as has_motor,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as has_motor_adapter,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') as has_side_channel_profile,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_end_cap') as has_side_channel_end_cap,
    CASE 
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'tube') = 0 THEN '❌ MISSING: tube'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bracket') = 0 THEN '❌ MISSING: bracket'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'fabric') = 0 THEN '❌ MISSING: fabric'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bottom_rail_profile') = 0 THEN '❌ MISSING: bottom_rail_profile'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'operating_system_drive') = 0 THEN '❌ MISSING: operating_system_drive'
        WHEN ql.drive_type = 'motor' AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') = 0 THEN '❌ MISSING: motor (drive_type=motor)'
        WHEN ql.drive_type = 'motor' AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') = 0 THEN '❌ MISSING: motor_adapter (drive_type=motor)'
        WHEN ql.side_channel = true AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') = 0 THEN '❌ MISSING: side_channel_profile (side_channel=true)'
        WHEN ql.side_channel = true AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_end_cap') = 0 THEN '❌ MISSING: side_channel_end_cap (side_channel=true)'
        ELSE '✅ OK: All required roles present'
    END as validation_status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '7 days'
GROUP BY ql.id, ql.drive_type, ql.side_channel
ORDER BY ql.created_at DESC
LIMIT 20;

-- ====================================================
-- VERIFICATION 6: Summary Statistics
-- ====================================================
-- Overall health check
-- ====================================================

SELECT 
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.side_channel = true) as with_side_channel,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') as side_channel_profile_count,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_end_cap') as side_channel_end_cap_count,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') as with_motor,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_count,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as motor_adapter_count,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) as with_tube_type,
    COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role = 'tube') as unique_tube_skus,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(DISTINCT ci.id) FILTER (WHERE qlc.component_role IN ('operating_system_drive', 'motor')) as unique_drive_skus
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';



