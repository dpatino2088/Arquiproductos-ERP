-- ====================================================
-- Migration 246: Test Resolver Directly (SIMPLIFIED)
-- ====================================================
-- Simplified version to avoid timeouts
-- ====================================================

-- ====================================================
-- TEST 1: Test resolver for motor role (SIMPLE)
-- ====================================================

SELECT 
    public.resolve_bom_role_to_sku(
        'motor',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,
        'motor',
        'standard_m',
        'RTU-42',
        'standard',
        false,
        NULL,
        'white',
        false,
        NULL
    ) as motor_sku_id;

-- ====================================================
-- TEST 2: Show what CatalogItem was found for motor
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND (
        item_name ILIKE '%motor%'
        OR sku ILIKE 'CM%'
    )
ORDER BY 
    CASE WHEN item_name ILIKE '%motor%' THEN 0 ELSE 1 END,
    ci.created_at DESC
LIMIT 5;

-- ====================================================
-- TEST 3: Test resolver for motor_adapter role
-- ====================================================

SELECT 
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
        NULL
    ) as motor_adapter_sku_id;

-- ====================================================
-- TEST 4: Show what CatalogItems match motor_adapter patterns
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND (
        (item_name ILIKE '%motor%' AND item_name ILIKE '%endcap%')
        OR item_name ILIKE '%motor%endcap%'
    )
ORDER BY 
    CASE WHEN item_name ILIKE '%motor%endcap%' THEN 0 ELSE 1 END,
    ci.created_at DESC
LIMIT 5;

-- ====================================================
-- TEST 5: Test resolver for tube role (RTU-42)
-- ====================================================

SELECT 
    public.resolve_bom_role_to_sku(
        'tube',
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,
        'motor',
        'standard_m',
        'RTU-42',
        'standard',
        false,
        NULL,
        'white',
        false,
        NULL
    ) as tube_sku_id;

-- ====================================================
-- TEST 6: Show RTU-42 CatalogItems
-- ====================================================

SELECT 
    ci.id,
    ci.sku,
    ci.item_name
FROM "CatalogItems" ci
WHERE ci.deleted = false
    AND ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND (
        sku ILIKE '%RTU%42%'
        OR item_name ILIKE '%tube%42%'
        OR sku = 'RTU-42'
    )
ORDER BY ci.created_at DESC
LIMIT 5;

