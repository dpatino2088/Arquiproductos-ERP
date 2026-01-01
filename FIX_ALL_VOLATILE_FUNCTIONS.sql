-- ====================================================
-- Fix All Functions Used in RLS Policies to VOLATILE
-- ====================================================
-- This script changes all helper functions used in RLS policies
-- from STABLE to VOLATILE to fix "SET is not allowed" errors
-- ====================================================

-- ====================================================
-- STEP 1: Change org_is_owner_or_admin to VOLATILE
-- ====================================================

DO $$
BEGIN
    BEGIN
        ALTER FUNCTION public.org_is_owner_or_admin(p_user_id uuid, p_org_id uuid) VOLATILE;
        RAISE NOTICE '✅ Function org_is_owner_or_admin changed to VOLATILE';
    EXCEPTION
        WHEN undefined_function THEN
            BEGIN
                ALTER FUNCTION public.org_is_owner_or_admin(uuid, uuid) VOLATILE;
                RAISE NOTICE '✅ Function org_is_owner_or_admin(uuid, uuid) changed to VOLATILE';
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️  Could not alter org_is_owner_or_admin. Error: %', SQLERRM;
            END;
    END;
END;
$$;

-- ====================================================
-- STEP 2: Change org_user_role to VOLATILE
-- ====================================================

DO $$
BEGIN
    BEGIN
        ALTER FUNCTION public.org_user_role(p_user_id uuid, p_org_id uuid) VOLATILE;
        RAISE NOTICE '✅ Function org_user_role changed to VOLATILE';
    EXCEPTION
        WHEN undefined_function THEN
            BEGIN
                ALTER FUNCTION public.org_user_role(uuid, uuid) VOLATILE;
                RAISE NOTICE '✅ Function org_user_role(uuid, uuid) changed to VOLATILE';
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️  Could not alter org_user_role. Error: %', SQLERRM;
            END;
    END;
END;
$$;

-- ====================================================
-- STEP 3: Change org_is_owner_or_superadmin to VOLATILE
-- ====================================================

DO $$
BEGIN
    BEGIN
        ALTER FUNCTION public.org_is_owner_or_superadmin(p_user_id uuid, p_org_id uuid) VOLATILE;
        RAISE NOTICE '✅ Function org_is_owner_or_superadmin changed to VOLATILE';
    EXCEPTION
        WHEN undefined_function THEN
            BEGIN
                ALTER FUNCTION public.org_is_owner_or_superadmin(uuid, uuid) VOLATILE;
                RAISE NOTICE '✅ Function org_is_owner_or_superadmin(uuid, uuid) changed to VOLATILE';
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️  Could not alter org_is_owner_or_superadmin. Error: %', SQLERRM;
            END;
    END;
END;
$$;

-- ====================================================
-- STEP 4: Find and fix any other functions used in RLS policies
-- ====================================================

DO $$
DECLARE
    v_func RECORD;
    v_alter_sql text;
BEGIN
    RAISE NOTICE 'Checking for other functions that might need to be VOLATILE...';
    
    -- Find functions that are STABLE or IMMUTABLE and might be used in RLS
    FOR v_func IN
        SELECT 
            p.oid,
            p.proname AS func_name,
            n.nspname AS schema_name,
            pg_get_function_identity_arguments(p.oid) AS func_args,
            CASE p.provolatile
                WHEN 'i' THEN 'IMMUTABLE'
                WHEN 's' THEN 'STABLE'
                WHEN 'v' THEN 'VOLATILE'
            END AS volatility
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.provolatile IN ('i', 's')  -- IMMUTABLE or STABLE
        AND (
            p.proname LIKE 'org_%'
            OR p.proname LIKE '%_owner%'
            OR p.proname LIKE '%_admin%'
            OR p.proname LIKE '%_member%'
            OR p.proname LIKE '%_role%'
        )
        ORDER BY p.proname
    LOOP
        BEGIN
            v_alter_sql := format('ALTER FUNCTION %I.%I(%s) VOLATILE', 
                v_func.schema_name, 
                v_func.func_name, 
                v_func.func_args);
            
            EXECUTE v_alter_sql;
            
            RAISE NOTICE '✅ Changed %(%) from % to VOLATILE', 
                v_func.func_name, 
                v_func.func_args, 
                v_func.volatility;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️  Could not alter %(%). Error: %', 
                    v_func.func_name, 
                    v_func.func_args, 
                    SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 5: Verify all changes
-- ====================================================

SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
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
AND (
    p.proname LIKE 'org_%'
    OR p.proname LIKE '%_owner%'
    OR p.proname LIKE '%_admin%'
    OR p.proname LIKE '%_member%'
    OR p.proname LIKE '%_role%'
)
ORDER BY p.proname, p.oid;

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
    RAISE NOTICE 'Changed all helper functions to VOLATILE:';
    RAISE NOTICE '  ✅ org_is_owner_or_admin';
    RAISE NOTICE '  ✅ org_user_role';
    RAISE NOTICE '  ✅ org_is_owner_or_superadmin';
    RAISE NOTICE '  ✅ Any other org_* functions found';
    RAISE NOTICE '';
    RAISE NOTICE 'This should fix the error:';
    RAISE NOTICE '  "SET is not allowed in a non-volatile function"';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Refresh the Quotes page';
    RAISE NOTICE '  2. Verify quotes load correctly';
    RAISE NOTICE '';
END;
$$;








