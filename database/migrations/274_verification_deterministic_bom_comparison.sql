-- ====================================================
-- Migration 274: Verification Queries - Deterministic BOM Comparison
-- ====================================================
-- Comparison queries to prove determinism:
-- Shows that different configurations produce different SKUs
-- ====================================================

-- ====================================================
-- VERIFICATION 1: Compare Default Configurations
-- Test A: standard_m + RTU-42 (default) vs Test B: standard_l + RTU-65 (default)
-- ====================================================

SELECT 
    'Verification 1: Default Configurations Comparison (standard_m+RTU-42 vs standard_l+RTU-65)' as check_name,
    ql.id as quote_line_id,
    ql.operating_system_variant,
    ql.tube_type,
    qlc.component_role,
    ci.id as resolved_catalog_item_id,
    ci.sku as resolved_sku,
    ci.item_name as resolved_item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    AND ql.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid  -- Roller Shade
    AND (
        (ql.operating_system_variant = 'standard_m' AND ql.tube_type = 'RTU-42') OR
        (ql.operating_system_variant = 'standard_l' AND ql.tube_type = 'RTU-65')
    )
ORDER BY 
    ql.operating_system_variant,
    ql.tube_type,
    qlc.component_role;

-- ====================================================
-- VERIFICATION 2: Show all resolved components for a specific QuoteLine
-- ====================================================

SELECT 
    'Verification 2: All components for QuoteLine' as check_name,
    ql.id as quote_line_id,
    ql.operating_system_variant,
    ql.tube_type,
    ql.drive_type,
    ql.side_channel,
    ql.hardware_color,
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
    AND qlc.source = 'configured_component'
    AND ql.id = 'b634562f-c1a7-4a3a-9b1e-01428f79eda4'::uuid  -- Replace with actual QuoteLine ID
ORDER BY qlc.component_role;

-- ====================================================
-- VERIFICATION 3: Test resolver directly for different configurations
-- ====================================================

WITH test_configs AS (
    SELECT 
        'Test A: standard_m + RTU-42 (default)' as config_name,
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid as product_type_id,
        'standard_m'::text as operating_system_variant,
        'RTU-42'::text as tube_type,
        'white'::text as hardware_color,
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
    UNION ALL
    SELECT 
        'Test B: standard_l + RTU-65 (default)' as config_name,
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid as product_type_id,
        'standard_l'::text as operating_system_variant,
        'RTU-65'::text as tube_type,
        'white'::text as hardware_color,
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
    UNION ALL
    SELECT 
        'Test C: standard_l + RTU-80 (optional, not default)' as config_name,
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid as product_type_id,
        'standard_l'::text as operating_system_variant,
        'RTU-80'::text as tube_type,
        'white'::text as hardware_color,
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id
)
SELECT 
    'Verification 3: Direct resolver test' as check_name,
    tc.config_name,
    'tube' as component_role,
    public.resolve_bom_role_to_catalog_item_id(
        tc.product_type_id,
        'tube',
        tc.operating_system_variant,
        tc.tube_type,
        NULL,
        NULL,
        tc.hardware_color,
        tc.organization_id
    ) as resolved_catalog_item_id,
    ci.sku as resolved_sku,
    ci.item_name as resolved_item_name
FROM test_configs tc
LEFT JOIN "CatalogItems" ci ON ci.id = public.resolve_bom_role_to_catalog_item_id(
    tc.product_type_id,
    'tube',
    tc.operating_system_variant,
    tc.tube_type,
    NULL,
    NULL,
    tc.hardware_color,
    tc.organization_id
)
ORDER BY tc.config_name;

-- ====================================================
-- VERIFICATION 4: Show mapping specificity (priority order)
-- ====================================================

SELECT 
    'Verification 4: Mapping specificity and priority' as check_name,
    m.component_role,
    m.operating_system_variant,
    m.tube_type,
    m.hardware_color,
    m.priority,
    ci.sku,
    ci.item_name,
    -- Count non-null configuration fields (higher = more specific)
    (
        CASE WHEN m.operating_system_variant IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.tube_type IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.bottom_rail_type IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.side_channel_type IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.hardware_color IS NOT NULL THEN 1 ELSE 0 END
    ) as specificity_score
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
ORDER BY 
    m.component_role,
    specificity_score DESC,
    m.priority ASC;

-- ====================================================
-- VERIFICATION 5: Validate that all required roles are mapped
-- ====================================================

SELECT 
    'Verification 5: Required roles coverage' as check_name,
    m.component_role,
    COUNT(DISTINCT m.id) as mapping_count,
    MIN(m.priority) as best_priority,
    COUNT(DISTINCT CASE WHEN m.operating_system_variant IS NOT NULL THEN m.id END) as with_os_variant,
    COUNT(DISTINCT CASE WHEN m.tube_type IS NOT NULL THEN m.id END) as with_tube_type,
    COUNT(DISTINCT CASE WHEN m.hardware_color IS NOT NULL THEN m.id END) as with_color
FROM "BomRoleSkuMapping" m
WHERE m.deleted = false
    AND m.active = true
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
GROUP BY m.component_role
ORDER BY m.component_role;

-- ====================================================
-- VERIFICATION 6: Test validation function
-- ====================================================

SELECT 
    'Verification 6: Configuration validation' as check_name,
    ql.id as quote_line_id,
    ql.operating_system_variant,
    ql.tube_type,
    public.validate_quote_line_configuration(ql.id) as validation_result
FROM "QuoteLines" ql
WHERE ql.deleted = false
    AND ql.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
    AND ql.operating_system_variant IS NOT NULL
    AND ql.tube_type IS NOT NULL
ORDER BY ql.created_at DESC
LIMIT 5;

