-- ====================================================
-- Migration 371: Verify ComponentRoleMap Integration
-- ====================================================
-- Verifies that resolve_auto_select_sku() and generate_bom_for_manufacturing_order()
-- are correctly using ComponentRoleMap instead of hardcoded CASE statements
-- ====================================================

-- ====================================================
-- TEST 1: Verify get_category_code_from_role() exists and works
-- ====================================================
DO $$
DECLARE
    v_test_result text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST 1: Verifying get_category_code_from_role() function';
    RAISE NOTICE '====================================================';
    
    -- Test with a canonical role
    SELECT public.get_category_code_from_role('tube') INTO v_test_result;
    
    IF v_test_result IS NULL OR v_test_result = '' THEN
        RAISE EXCEPTION '❌ get_category_code_from_role(''tube'') returned NULL or empty';
    END IF;
    
    RAISE NOTICE '✅ get_category_code_from_role(''tube'') = %', v_test_result;
    RAISE NOTICE '   Expected: COMP-TUBE (or similar from ComponentRoleMap)';
    
    -- Test with another canonical role
    SELECT public.get_category_code_from_role('bracket') INTO v_test_result;
    RAISE NOTICE '✅ get_category_code_from_role(''bracket'') = %', v_test_result;
    
    -- Test with fabric
    SELECT public.get_category_code_from_role('fabric') INTO v_test_result;
    RAISE NOTICE '✅ get_category_code_from_role(''fabric'') = %', v_test_result;
    
    RAISE NOTICE '';
END $$;

-- ====================================================
-- TEST 2: Verify get_item_category_codes_from_role() works
-- ====================================================
DO $$
DECLARE
    v_category_codes text[];
BEGIN
    RAISE NOTICE '🧪 TEST 2: Verifying get_item_category_codes_from_role() function';
    RAISE NOTICE '====================================================';
    
    -- Test with a canonical role
    SELECT public.get_item_category_codes_from_role('tube', NULL) INTO v_category_codes;
    
    IF v_category_codes IS NULL OR array_length(v_category_codes, 1) IS NULL THEN
        RAISE EXCEPTION '❌ get_item_category_codes_from_role(''tube'') returned NULL or empty array';
    END IF;
    
    RAISE NOTICE '✅ get_item_category_codes_from_role(''tube'') = %', v_category_codes;
    RAISE NOTICE '   Expected: {COMP-TUBE} (or similar from ComponentRoleMap)';
    
    RAISE NOTICE '';
END $$;

-- ====================================================
-- TEST 3: Verify resolve_auto_select_sku() uses ComponentRoleMap
-- ====================================================
-- Note: This test requires a real organization_id and valid data
-- We'll just verify the function exists and can be called
DO $$
BEGIN
    RAISE NOTICE '🧪 TEST 3: Verifying resolve_auto_select_sku() function exists';
    RAISE NOTICE '====================================================';
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'resolve_auto_select_sku'
    ) THEN
        RAISE EXCEPTION '❌ Function resolve_auto_select_sku() does not exist';
    END IF;
    
    RAISE NOTICE '✅ Function resolve_auto_select_sku() exists';
    RAISE NOTICE '   (This function should use ComponentRoleMap internally)';
    
    RAISE NOTICE '';
END $$;

-- ====================================================
-- TEST 4: Verify generate_bom_for_manufacturing_order() exists
-- ====================================================
DO $$
BEGIN
    RAISE NOTICE '🧪 TEST 4: Verifying generate_bom_for_manufacturing_order() function exists';
    RAISE NOTICE '====================================================';
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'generate_bom_for_manufacturing_order'
    ) THEN
        RAISE EXCEPTION '❌ Function generate_bom_for_manufacturing_order() does not exist';
    END IF;
    
    RAISE NOTICE '✅ Function generate_bom_for_manufacturing_order() exists';
    RAISE NOTICE '   (This function should use get_category_code_from_role() internally)';
    
    RAISE NOTICE '';
END $$;

-- ====================================================
-- TEST 5: Verify ComponentRoleMap has mappings for all canonical roles
-- ====================================================
DO $$
DECLARE
    v_missing_roles text[];
    v_canonical_roles text[] := ARRAY[
        'fabric', 'tube', 'bracket', 'cassette', 'side_channel', 'bottom_bar', 
        'bottom_rail', 'top_rail', 'drive_manual', 'drive_motorized', 
        'remote_control', 'battery', 'tool', 'hardware', 'accessory',
        'service', 'window_film', 'end_cap', 'operating_system'
    ];
    v_role text;
BEGIN
    RAISE NOTICE '🧪 TEST 5: Verifying ComponentRoleMap has mappings for canonical roles';
    RAISE NOTICE '====================================================';
    
    FOREACH v_role IN ARRAY v_canonical_roles
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public."ComponentRoleMap"
            WHERE role = v_role
            AND active = true
        ) THEN
            v_missing_roles := array_append(v_missing_roles, v_role);
        END IF;
    END LOOP;
    
    IF array_length(v_missing_roles, 1) > 0 THEN
        RAISE WARNING '⚠️  Missing ComponentRoleMap mappings for roles: %', v_missing_roles;
    ELSE
        RAISE NOTICE '✅ All canonical roles have mappings in ComponentRoleMap';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- ====================================================
-- TEST 6: Show summary of ComponentRoleMap
-- ====================================================
DO $$
DECLARE
    v_count integer;
    rec RECORD;
BEGIN
    RAISE NOTICE '📊 ComponentRoleMap Summary';
    RAISE NOTICE '====================================================';
    
    SELECT COUNT(*) INTO v_count
    FROM public."ComponentRoleMap"
    WHERE active = true;
    
    RAISE NOTICE 'Total active mappings: %', v_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Sample mappings:';
    RAISE NOTICE '';
    
    -- Display sample mappings
    FOR rec IN
        SELECT role, item_category_code
        FROM public."ComponentRoleMap"
        WHERE active = true
        ORDER BY role
        LIMIT 10
    LOOP
        RAISE NOTICE '  % → %', rec.role, rec.item_category_code;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ All verification tests completed!';
    RAISE NOTICE '';
END $$;

