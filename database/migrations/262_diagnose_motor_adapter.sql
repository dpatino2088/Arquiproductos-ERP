-- ====================================================
-- Migration 262: Diagnose Motor Adapter Issue
-- ====================================================
-- Diagnostic query to check why motor_adapter is not being created
-- ====================================================

-- Check 1: Verify motor_adapter role is in required_roles
SELECT 
    'Check 1: QuoteLine drive_type' as check_name,
    id,
    drive_type,
    tube_type,
    operating_system_variant
FROM "QuoteLines"
WHERE id = 'b634562f-c1a7-4a3a-9b1e-01428f79eda4'::uuid;

-- Check 2: Check if motor_adapter CatalogItems exist
SELECT 
    'Check 2: Motor Adapter CatalogItems' as check_name,
    id,
    sku,
    item_name,
    organization_id
FROM "CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND deleted = false
    AND (sku ILIKE '%MOTOR%ADAPTER%' OR item_name ILIKE '%MOTOR%ADAPTER%' OR sku ILIKE '%ADAPTER%' OR item_name ILIKE '%ADAPTER%')
ORDER BY 
    CASE WHEN sku ILIKE '%ADAPTER%' THEN 0 ELSE 1 END,
    created_at DESC;

-- Check 3: Test resolver directly for motor_adapter
SELECT 
    'Check 3: Resolver test for motor_adapter' as check_name,
    public.resolve_bom_role_to_sku(
        'motor_adapter',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,
        'motor',
        'standard_m',
        'RTU-42',
        'standard',
        false,
        NULL,
        'white',
        false,
        NULL,
        'Roller Shade'
    ) as resolved_catalog_item_id;

-- Check 4: Check what QuoteLineComponents were created
SELECT 
    'Check 4: Created QuoteLineComponents' as check_name,
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLineComponents" qlc
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = 'b634562f-c1a7-4a3a-9b1e-01428f79eda4'::uuid
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
ORDER BY qlc.component_role;


