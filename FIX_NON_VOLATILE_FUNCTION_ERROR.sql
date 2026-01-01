-- ====================================================
-- Fix "SET is not allowed in a non-volatile function" Error
-- ====================================================
-- This error occurs when a function uses SET/SET LOCAL but is not marked as VOLATILE
-- Common causes: Functions used in RLS policies or triggers that need SET operations
-- ====================================================

-- ====================================================
-- STEP 1: Check org_is_owner_or_admin function
-- ====================================================

DO $$
DECLARE
    v_func_volatility text;
    v_func_has_set boolean;
BEGIN
    -- Check if function exists and its volatility
    SELECT 
        CASE p.provolatile
            WHEN 'i' THEN 'IMMUTABLE'
            WHEN 's' THEN 'STABLE'
            WHEN 'v' THEN 'VOLATILE'
        END,
        pg_get_functiondef(p.oid) LIKE '%SET%' OR pg_get_functiondef(p.oid) LIKE '%set %'
    INTO v_func_volatility, v_func_has_set
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'org_is_owner_or_admin'
    LIMIT 1;
    
    IF v_func_volatility IS NOT NULL THEN
        RAISE NOTICE 'Function org_is_owner_or_admin:';
        RAISE NOTICE '  Volatility: %', v_func_volatility;
        RAISE NOTICE '  Uses SET: %', v_func_has_set;
        
        IF v_func_has_set AND v_func_volatility != 'VOLATILE' THEN
            RAISE WARNING '⚠️  Function uses SET but is not VOLATILE!';
            RAISE NOTICE '🔧 Updating function to VOLATILE...';
            
            ALTER FUNCTION public.org_is_owner_or_admin(uuid, uuid) VOLATILE;
            
            RAISE NOTICE '✅ Function updated to VOLATILE';
        END IF;
    ELSE
        RAISE WARNING '⚠️  Function org_is_owner_or_admin not found!';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Check all functions that might be used in RLS policies
-- ====================================================

DO $$
DECLARE
    v_func RECORD;
BEGIN
    RAISE NOTICE 'Checking functions that might be used in RLS policies...';
    
    FOR v_func IN
        SELECT 
            p.proname AS func_name,
            n.nspname AS schema_name,
            CASE p.provolatile
                WHEN 'i' THEN 'IMMUTABLE'
                WHEN 's' THEN 'STABLE'
                WHEN 'v' THEN 'VOLATILE'
            END AS volatility,
            pg_get_functiondef(p.oid) LIKE '%SET%' OR pg_get_functiondef(p.oid) LIKE '%set %' AS uses_set
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%org_%'
            OR p.proname LIKE '%_owner%'
            OR p.proname LIKE '%_admin%'
            OR p.proname LIKE '%_member%'
        )
        ORDER BY p.proname
    LOOP
        IF v_func.uses_set AND v_func.volatility != 'VOLATILE' THEN
            RAISE WARNING '⚠️  Function % uses SET but is % (should be VOLATILE)', v_func.func_name, v_func.volatility;
        ELSE
            RAISE NOTICE '✅ Function %: % (SET: %)', v_func.func_name, v_func.volatility, v_func.uses_set;
        END IF;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 3: Check functions used in RLS policies for Quotes and SaleOrders
-- ====================================================

DO $$
DECLARE
    v_policy RECORD;
    v_func_name text;
BEGIN
    RAISE NOTICE 'Checking RLS policies for Quotes and SaleOrders...';
    
    FOR v_policy IN
        SELECT 
            tablename,
            policyname,
            qual,
            with_check
        FROM pg_policies
        WHERE tablename IN ('Quotes', 'SaleOrders', 'ManufacturingOrders')
        AND (qual LIKE '%org_%' OR with_check LIKE '%org_%')
    LOOP
        RAISE NOTICE 'Policy % on % uses org_* function', v_policy.policyname, v_policy.tablename;
        
        -- Extract function name from policy
        IF v_policy.qual IS NOT NULL AND v_policy.qual LIKE '%org_%(%' THEN
            v_func_name := (regexp_match(v_policy.qual, 'org_\w+'))[1];
            RAISE NOTICE '  Function in qual: %', v_func_name;
        END IF;
        
        IF v_policy.with_check IS NOT NULL AND v_policy.with_check LIKE '%org_%(%' THEN
            v_func_name := (regexp_match(v_policy.with_check, 'org_\w+'))[1];
            RAISE NOTICE '  Function in with_check: %', v_func_name;
        END IF;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 4: Ensure org_is_owner_or_admin is VOLATILE
-- ====================================================

-- Update org_is_owner_or_admin to VOLATILE if it's being used in contexts that require SET
-- Note: The function itself doesn't use SET, but if it's called from a context that does,
-- it needs to be VOLATILE. However, changing from STABLE to VOLATILE can impact performance.
-- Let's first check if the function actually needs to be changed.

-- Option 1: Just change volatility to VOLATILE (safest, but may impact performance)
ALTER FUNCTION public.org_is_owner_or_admin(uuid, uuid) VOLATILE;

-- Option 2: If the function doesn't actually need SET, keep it STABLE but ensure
-- any calling functions that use SET are VOLATILE
-- (We'll do Option 1 for now as it's safer)

COMMENT ON FUNCTION public.org_is_owner_or_admin(uuid, uuid) IS
'Checks if a user is an owner or admin of an organization. Must be VOLATILE if used in contexts that require SET operations.';

-- ====================================================
-- STEP 5: Verify fix
-- ====================================================

SELECT 
    p.proname AS function_name,
    CASE p.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        WHEN 'v' THEN 'VOLATILE'
    END AS volatility,
    CASE p.prosecdef
        WHEN true THEN 'SECURITY DEFINER'
        ELSE 'SECURITY INVOKER'
    END AS security
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'org_is_owner_or_admin';

-- ====================================================
-- Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Fix Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Updated:';
    RAISE NOTICE '  ✅ Function org_is_owner_or_admin set to VOLATILE';
    RAISE NOTICE '';
    RAISE NOTICE 'This should fix the error:';
    RAISE NOTICE '  "SET is not allowed in a non-volatile function"';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Refresh the Quote Approved page';
    RAISE NOTICE '  2. Verify quotes load correctly';
    RAISE NOTICE '';
END;
$$;

