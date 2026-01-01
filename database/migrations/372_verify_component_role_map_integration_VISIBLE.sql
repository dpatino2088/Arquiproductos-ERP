-- ====================================================
-- Migration 372: Verify ComponentRoleMap Integration (Visible Results)
-- ====================================================
-- This version returns visible results instead of RAISE NOTICE
-- to verify that ComponentRoleMap integration is working correctly
-- ====================================================

-- ====================================================
-- TEST 1: Test get_category_code_from_role() with sample roles
-- ====================================================
SELECT 
    'get_category_code_from_role() Test' as test_name,
    'tube' as test_role,
    public.get_category_code_from_role('tube') as result_category_code,
    CASE 
        WHEN public.get_category_code_from_role('tube') IS NOT NULL 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status
UNION ALL
SELECT 
    'get_category_code_from_role() Test',
    'bracket',
    public.get_category_code_from_role('bracket'),
    CASE 
        WHEN public.get_category_code_from_role('bracket') IS NOT NULL 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END
UNION ALL
SELECT 
    'get_category_code_from_role() Test',
    'fabric',
    public.get_category_code_from_role('fabric'),
    CASE 
        WHEN public.get_category_code_from_role('fabric') IS NOT NULL 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END
UNION ALL
SELECT 
    'get_category_code_from_role() Test',
    'end_cap',
    public.get_category_code_from_role('end_cap'),
    CASE 
        WHEN public.get_category_code_from_role('end_cap') IS NOT NULL 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END
UNION ALL
SELECT 
    'get_category_code_from_role() Test',
    'operating_system',
    public.get_category_code_from_role('operating_system'),
    CASE 
        WHEN public.get_category_code_from_role('operating_system') IS NOT NULL 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END;

-- ====================================================
-- TEST 2: Verify functions exist
-- ====================================================
SELECT 
    'Function Existence Check' as test_name,
    p.proname as function_name,
    CASE 
        WHEN p.proname IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname IN (
    'get_category_code_from_role',
    'get_item_category_codes_from_role',
    'resolve_auto_select_sku',
    'generate_bom_for_manufacturing_order'
)
ORDER BY p.proname;

-- ====================================================
-- TEST 3: Verify ComponentRoleMap has mappings for canonical roles
-- ====================================================
SELECT 
    'ComponentRoleMap Coverage' as test_name,
    role as canonical_role,
    COUNT(*) as mapping_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ MAPPED'
        ELSE '❌ MISSING'
    END as status
FROM public."ComponentRoleMap"
WHERE active = true
AND role IN (
    'fabric', 'tube', 'bracket', 'cassette', 'side_channel', 'bottom_bar', 
    'bottom_rail', 'top_rail', 'drive_manual', 'drive_motorized', 
    'remote_control', 'battery', 'tool', 'hardware', 'accessory',
    'service', 'window_film', 'end_cap', 'operating_system'
)
GROUP BY role
ORDER BY role;

-- ====================================================
-- TEST 4: Show ComponentRoleMap summary
-- ====================================================
SELECT 
    'ComponentRoleMap Summary' as test_name,
    role,
    item_category_code,
    sub_role,
    active,
    '✅ ACTIVE' as status
FROM public."ComponentRoleMap"
WHERE active = true
ORDER BY role, item_category_code
LIMIT 20;

-- ====================================================
-- TEST 5: Check for missing canonical roles
-- ====================================================
WITH canonical_roles AS (
    SELECT unnest(ARRAY[
        'fabric', 'tube', 'bracket', 'cassette', 'side_channel', 'bottom_bar', 
        'bottom_rail', 'top_rail', 'drive_manual', 'drive_motorized', 
        'remote_control', 'battery', 'tool', 'hardware', 'accessory',
        'service', 'window_film', 'end_cap', 'operating_system'
    ]) as role
),
mapped_roles AS (
    SELECT DISTINCT role
    FROM public."ComponentRoleMap"
    WHERE active = true
)
SELECT 
    'Missing Mappings Check' as test_name,
    cr.role as missing_role,
    '❌ MISSING' as status
FROM canonical_roles cr
LEFT JOIN mapped_roles mr ON cr.role = mr.role
WHERE mr.role IS NULL
ORDER BY cr.role;

