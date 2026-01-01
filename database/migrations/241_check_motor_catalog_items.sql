-- ====================================================
-- Migration 241: Check Motor CatalogItems
-- ====================================================
-- Verify if motor CatalogItems exist and match resolver patterns
-- ====================================================

-- ====================================================
-- CHECK 1: Search for motor CatalogItems
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.deleted,
    CASE 
        WHEN ci.sku ILIKE '%MOTOR%' OR ci.item_name ILIKE '%MOTOR%' THEN '✅ Matches MOTOR pattern'
        ELSE '❌ Does not match'
    END as matches_pattern
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND (ci.sku ILIKE '%MOTOR%' OR ci.item_name ILIKE '%MOTOR%')
ORDER BY 
    CASE WHEN ci.sku ILIKE '%MOTOR%' THEN 0 ELSE 1 END,
    ci.created_at DESC
LIMIT 20;

-- ====================================================
-- CHECK 2: Search for motor adapter CatalogItems
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.deleted,
    CASE 
        WHEN ci.sku ILIKE '%MOTOR%ADAPTER%' OR ci.item_name ILIKE '%MOTOR%ADAPTER%' THEN '✅ Matches MOTOR ADAPTER pattern'
        WHEN ci.sku ILIKE '%ADAPTER%' OR ci.item_name ILIKE '%ADAPTER%' THEN '⚠️ Matches ADAPTER but not MOTOR ADAPTER'
        ELSE '❌ Does not match'
    END as matches_pattern
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND (ci.sku ILIKE '%ADAPTER%' OR ci.item_name ILIKE '%ADAPTER%')
ORDER BY 
    CASE WHEN ci.sku ILIKE '%MOTOR%ADAPTER%' THEN 0 ELSE 1 END,
    ci.created_at DESC
LIMIT 20;

-- ====================================================
-- CHECK 3: Test resolver with actual organization_id
-- ====================================================

SELECT 
    public.resolve_bom_role_to_sku(
        'motor',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,  -- organization_id from the QuoteLine
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
    'motor' as role,
    '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id;

-- ====================================================
-- CHECK 4: Test resolver for motor_adapter
-- ====================================================

SELECT 
    public.resolve_bom_role_to_sku(
        'motor_adapter',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,  -- organization_id from the QuoteLine
        'motor',
        'standard_m',
        'RTU-80',
        'standard',
        false,
        NULL,
        'white',
        false,
        NULL
    ) as resolved_motor_adapter_sku,
    'motor_adapter' as role,
    '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid as organization_id;

-- ====================================================
-- CHECK 5: All CatalogItems for the organization
-- ====================================================
-- See what CatalogItems exist for this organization
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    CASE 
        WHEN ci.sku ILIKE '%MOTOR%' OR ci.item_name ILIKE '%MOTOR%' THEN '✅ Contains MOTOR'
        WHEN ci.sku ILIKE '%ADAPTER%' OR ci.item_name ILIKE '%ADAPTER%' THEN '⚠️ Contains ADAPTER'
        ELSE 'Other'
    END as category
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
ORDER BY 
    CASE 
        WHEN ci.sku ILIKE '%MOTOR%' THEN 0
        WHEN ci.sku ILIKE '%ADAPTER%' THEN 1
        ELSE 2
    END,
    ci.created_at DESC
LIMIT 50;



