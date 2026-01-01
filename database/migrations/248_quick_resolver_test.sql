-- ====================================================
-- Migration 248: Quick Resolver Test
-- ====================================================
-- Quick test to verify resolver works for key roles
-- ====================================================

-- Test motor resolver
SELECT 
    'motor' as role,
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
    ) as resolved_id;

-- Test motor_adapter resolver
SELECT 
    'motor_adapter' as role,
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
    ) as resolved_id;

-- Test tube resolver (RTU-42)
SELECT 
    'tube' as role,
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
    ) as resolved_id;



