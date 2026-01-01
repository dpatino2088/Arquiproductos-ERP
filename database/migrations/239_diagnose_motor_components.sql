-- ====================================================
-- Migration 239: Diagnose Why Motor Components Are Missing
-- ====================================================
-- Investigate why motor components are not being created
-- ====================================================

-- ====================================================
-- DIAGNOSIS 1: Check QuoteLines with motor drive_type
-- ====================================================

SELECT 
    ql.id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    ql.product_type_id,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as motor_adapter_components,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') as total_configured_components
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.drive_type = 'motor'
    AND ql.created_at > NOW() - INTERVAL '30 days'
GROUP BY ql.id, ql.drive_type, ql.tube_type, ql.operating_system_variant, ql.product_type_id
ORDER BY ql.created_at DESC
LIMIT 5;

-- ====================================================
-- DIAGNOSIS 2: Test resolver for motor role
-- ====================================================
-- Check if resolver can find motor SKUs
-- ====================================================

SELECT 
    public.resolve_bom_role_to_sku(
        'motor',
        ql.organization_id,
        ql.drive_type,
        ql.operating_system_variant,
        ql.tube_type,
        ql.bottom_rail_type,
        ql.side_channel,
        ql.side_channel_type,
        ql.hardware_color,
        ql.cassette,
        ql.cassette_type
    ) as resolved_motor_sku,
    ql.id as quote_line_id,
    ql.drive_type,
    ql.operating_system_variant
FROM "QuoteLines" ql
WHERE ql.deleted = false
    AND ql.drive_type = 'motor'
    AND ql.organization_id IS NOT NULL
    AND ql.created_at > NOW() - INTERVAL '30 days'
LIMIT 5;

-- ====================================================
-- DIAGNOSIS 3: Check if CatalogItems exist for motor
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND (ci.sku ILIKE '%MOTOR%' OR ci.item_name ILIKE '%MOTOR%')
ORDER BY ci.created_at DESC
LIMIT 10;

-- ====================================================
-- DIAGNOSIS 4: Check what components were actually created
-- ====================================================

SELECT 
    qlc.component_role,
    COUNT(*) as count,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_with_role
FROM "QuoteLineComponents" qlc
WHERE qlc.deleted = false
    AND qlc.source = 'configured_component'
    AND qlc.quote_line_id IN (
        SELECT id FROM "QuoteLines"
        WHERE deleted = false
            AND drive_type = 'motor'
            AND created_at > NOW() - INTERVAL '30 days'
    )
GROUP BY qlc.component_role
ORDER BY count DESC;

-- ====================================================
-- DIAGNOSIS 5: Check if generate_configured_bom was called
-- ====================================================
-- Check when QuoteLineComponents were last created/updated
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.drive_type,
    ql.created_at as quote_line_created,
    MAX(qlc.created_at) as last_component_created,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') as configured_components
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.drive_type = 'motor'
    AND ql.created_at > NOW() - INTERVAL '30 days'
GROUP BY ql.id, ql.drive_type, ql.created_at
ORDER BY ql.created_at DESC
LIMIT 5;

-- ====================================================
-- DIAGNOSIS 6: Manual test - try to generate BOM for one QuoteLine
-- ====================================================
-- This will show if the function works when called manually
-- ====================================================

-- First, get a QuoteLine ID to test
SELECT 
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant
FROM "QuoteLines" ql
WHERE ql.deleted = false
    AND ql.drive_type = 'motor'
    AND ql.product_type_id IS NOT NULL
    AND ql.organization_id IS NOT NULL
    AND ql.created_at > NOW() - INTERVAL '30 days'
LIMIT 1;

-- Then use that ID to test the function (replace <QUOTE_LINE_ID> with actual ID)
-- SELECT public.generate_configured_bom_for_quote_line(
--     '<QUOTE_LINE_ID>'::uuid,
--     (SELECT product_type_id FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT organization_id FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT drive_type FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT bottom_rail_type FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT cassette FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT cassette_type FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT side_channel FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT side_channel_type FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT hardware_color FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT width_m FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT height_m FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT qty FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT tube_type FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid),
--     (SELECT operating_system_variant FROM "QuoteLines" WHERE id = '<QUOTE_LINE_ID>'::uuid)
-- );



