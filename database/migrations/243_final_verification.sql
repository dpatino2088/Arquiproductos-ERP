-- ====================================================
-- Migration 243: Final Verification After Flexible Resolver
-- ====================================================
-- Verify that motor components are now being created
-- ====================================================

-- ====================================================
-- VERIFICATION 1: Check Motor Components Created
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
-- VERIFICATION 2: Show Motor Components Details
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.drive_type = 'motor'
    AND qlc.component_role IN ('motor', 'motor_adapter')
    AND ql.created_at > NOW() - INTERVAL '30 days'
ORDER BY ql.created_at DESC, qlc.component_role
LIMIT 20;

-- ====================================================
-- VERIFICATION 3: Test Resolver Directly
-- ====================================================

SELECT 
    public.resolve_bom_role_to_sku(
        'motor',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,
        'motor',
        'standard_m',
        'RTU-80',
        'standard',
        false,
        NULL,
        'white',
        false,
        NULL
    ) as resolved_motor_sku,
    ci.sku,
    ci.item_name
FROM "CatalogItems" ci
WHERE ci.id = public.resolve_bom_role_to_sku(
        'motor',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,
        'motor',
        'standard_m',
        'RTU-80',
        'standard',
        false,
        NULL,
        'white',
        false,
        NULL
    );

-- ====================================================
-- VERIFICATION 4: Overall Status
-- ====================================================

SELECT 
    'Overall Status' as check_type,
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) as with_tube_type,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') as with_motor_drive,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as motor_adapter_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'tube') as tube_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'bracket') as bracket_components,
    CASE 
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) = 0 THEN '❌ CRITICAL: No tube_type'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) = 0 THEN '❌ CRITICAL: No operating_system_variant'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') = 0 
        THEN '❌ CRITICAL: Motor components missing'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'motor') > 0 
        THEN '✅ OK: All components created correctly'
        ELSE '⚠️ CHECK: Review results'
    END as overall_status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- VERIFICATION 5: All Components by Role
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



