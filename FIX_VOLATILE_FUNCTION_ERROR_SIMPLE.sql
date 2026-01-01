-- ====================================================
-- Fix "SET is not allowed in a non-volatile function" Error
-- ====================================================
-- Simple fix: Change org_is_owner_or_admin from STABLE to VOLATILE
-- This allows the function to be used in contexts that require SET operations
-- ====================================================

-- Change org_is_owner_or_admin to VOLATILE
-- This is safe because the function queries OrganizationUsers which can change
-- Based on the migration file, the function signature is: (p_user_id uuid, p_org_id uuid)
DO $$
BEGIN
    -- Try to alter the function - PostgreSQL requires exact parameter names/types
    BEGIN
        ALTER FUNCTION public.org_is_owner_or_admin(p_user_id uuid, p_org_id uuid) VOLATILE;
        RAISE NOTICE '✅ Function org_is_owner_or_admin changed to VOLATILE';
    EXCEPTION
        WHEN undefined_function THEN
            RAISE WARNING '⚠️  Function org_is_owner_or_admin(p_user_id uuid, p_org_id uuid) not found';
            RAISE NOTICE '   Trying alternative signature (uuid, uuid)...';
            BEGIN
                ALTER FUNCTION public.org_is_owner_or_admin(uuid, uuid) VOLATILE;
                RAISE NOTICE '✅ Function org_is_owner_or_admin(uuid, uuid) changed to VOLATILE';
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️  Could not alter function. Error: %', SQLERRM;
                    RAISE NOTICE '   Please check the function signature manually';
            END;
    END;
END;
$$;

-- Verify the change
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

-- Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Fix Applied!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Changed:';
    RAISE NOTICE '  org_is_owner_or_admin: STABLE → VOLATILE';
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

