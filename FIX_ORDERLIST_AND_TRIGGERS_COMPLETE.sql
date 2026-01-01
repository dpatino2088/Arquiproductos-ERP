-- ====================================================
-- Fix OrderList and Triggers - Complete Solution
-- ====================================================
-- This script:
-- 1. Verifies and fixes the trigger for Quote -> SaleOrder
-- 2. Verifies and fixes the trigger for SaleOrder -> ManufacturingOrder
-- 3. Ensures RLS policies allow reading SaleOrders and creating ManufacturingOrders
-- 4. Tests the complete flow
-- ====================================================

-- ====================================================
-- STEP 1: Verify and Fix Quote -> SaleOrder Trigger
-- ====================================================

DO $$
BEGIN
    -- Check if function exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE WARNING '❌ Function on_quote_approved_create_operational_docs does not exist!';
        RAISE NOTICE '⚠️  Please run migration 197 first: database/migrations/197_ensure_quote_approved_trigger_works.sql';
    ELSE
        RAISE NOTICE '✅ Function on_quote_approved_create_operational_docs exists';
    END IF;

    -- Check if trigger exists and is enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        AND t.tgenabled = 'O'
    ) THEN
        RAISE WARNING '❌ Trigger trg_on_quote_approved_create_operational_docs is missing or disabled!';
        RAISE NOTICE '🔧 Recreating trigger...';
        
        DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";
        
        CREATE TRIGGER trg_on_quote_approved_create_operational_docs
            AFTER UPDATE OF status ON "Quotes"
            FOR EACH ROW
            WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
            EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();
        
        RAISE NOTICE '✅ Trigger recreated and enabled';
    ELSE
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs is active';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Verify and Fix SaleOrder -> ManufacturingOrder Trigger
-- ====================================================

DO $$
BEGIN
    -- Check if function exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_sale_order_confirmed_create_manufacturing_order'
    ) THEN
        RAISE WARNING '❌ Function on_sale_order_confirmed_create_manufacturing_order does not exist!';
        RAISE NOTICE '⚠️  Please run migration 194 first: database/migrations/194_complete_quote_to_manufacturing_flow.sql';
    ELSE
        RAISE NOTICE '✅ Function on_sale_order_confirmed_create_manufacturing_order exists';
    END IF;

    -- Check if trigger exists and is enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'SaleOrders'
        AND t.tgname = 'trg_sale_order_confirmed_create_mo'
        AND t.tgenabled = 'O'
    ) THEN
        RAISE WARNING '❌ Trigger trg_sale_order_confirmed_create_mo is missing or disabled!';
        RAISE NOTICE '🔧 Recreating trigger...';
        
        DROP TRIGGER IF EXISTS trg_sale_order_confirmed_create_mo ON "SaleOrders";
        
        CREATE TRIGGER trg_sale_order_confirmed_create_mo
            AFTER UPDATE OF status ON "SaleOrders"
            FOR EACH ROW
            WHEN (NEW.status = 'Confirmed' AND OLD.status IS DISTINCT FROM 'Confirmed')
            EXECUTE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order();
        
        RAISE NOTICE '✅ Trigger recreated and enabled';
    ELSE
        RAISE NOTICE '✅ Trigger trg_sale_order_confirmed_create_mo is active';
    END IF;
END;
$$;

-- ====================================================
-- STEP 3: Ensure RLS Policies for SaleOrders
-- ====================================================

-- Check if RLS is enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables t
        JOIN pg_class c ON c.relname = t.tablename
        WHERE t.schemaname = 'public'
        AND t.tablename = 'SaleOrders'
        AND c.relrowsecurity = true
    ) THEN
        RAISE NOTICE '🔧 Enabling RLS on SaleOrders...';
        ALTER TABLE "SaleOrders" ENABLE ROW LEVEL SECURITY;
    ELSE
        RAISE NOTICE '✅ RLS is enabled on SaleOrders';
    END IF;
END;
$$;

-- Note: The existing policy "sale_orders_select_own_org" should already allow reading SaleOrders
-- We just verify it exists and works correctly
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'SaleOrders'
        AND policyname = 'sale_orders_select_own_org'
    ) THEN
        RAISE WARNING '⚠️  Policy sale_orders_select_own_org does not exist!';
        RAISE NOTICE '🔧 Creating policy...';
        
        CREATE POLICY "sale_orders_select_own_org"
        ON "SaleOrders"
        FOR SELECT
        USING (
            organization_id IN (
                SELECT organization_id 
                FROM "OrganizationUsers" 
                WHERE user_id = auth.uid() 
                AND deleted = false
            )
            AND deleted = false
        );
        
        RAISE NOTICE '✅ Policy created';
    ELSE
        RAISE NOTICE '✅ Policy sale_orders_select_own_org exists';
    END IF;
END;
$$;

-- ====================================================
-- STEP 4: Ensure RLS Policies for ManufacturingOrders
-- ====================================================

-- Check if RLS is enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables t
        JOIN pg_class c ON c.relname = t.tablename
        WHERE t.schemaname = 'public'
        AND t.tablename = 'ManufacturingOrders'
        AND c.relrowsecurity = true
    ) THEN
        RAISE NOTICE '🔧 Enabling RLS on ManufacturingOrders...';
        ALTER TABLE "ManufacturingOrders" ENABLE ROW LEVEL SECURITY;
    ELSE
        RAISE NOTICE '✅ RLS is enabled on ManufacturingOrders';
    END IF;
END;
$$;

-- Note: The existing policies should already allow reading/creating/updating ManufacturingOrders
-- Based on the CSV provided, these policies exist:
-- - manufacturing_orders_select_own_org (SELECT)
-- - manufacturing_orders_insert_own_org (INSERT)
-- - manufacturing_orders_update_own_org (UPDATE)
-- - manufacturing_orders_delete_own_org (DELETE - uses org_is_owner_or_admin function)
-- We just verify they exist and list them
DO $$
DECLARE
    v_policy_count integer;
    v_policy_name text;
BEGIN
    -- Count existing policies
    SELECT COUNT(*) INTO v_policy_count
    FROM pg_policies
    WHERE tablename = 'ManufacturingOrders';
    
    IF v_policy_count >= 4 THEN
        RAISE NOTICE '✅ ManufacturingOrders has % policies (expected: 4+)', v_policy_count;
        RAISE NOTICE '   Policies found:';
        FOR v_policy_name IN
            SELECT policyname FROM pg_policies WHERE tablename = 'ManufacturingOrders' ORDER BY policyname
        LOOP
            RAISE NOTICE '     - %', v_policy_name;
        END LOOP;
    ELSE
        RAISE WARNING '⚠️  ManufacturingOrders has only % policies (expected: 4+)', v_policy_count;
        RAISE NOTICE '   Existing policies:';
        FOR v_policy_name IN
            SELECT policyname FROM pg_policies WHERE tablename = 'ManufacturingOrders' ORDER BY policyname
        LOOP
            RAISE NOTICE '     - %', v_policy_name;
        END LOOP;
    END IF;
    
    -- Verify specific policies exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ManufacturingOrders' 
        AND policyname = 'manufacturing_orders_select_own_org'
    ) THEN
        RAISE WARNING '⚠️  Policy manufacturing_orders_select_own_org is MISSING!';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ManufacturingOrders' 
        AND policyname = 'manufacturing_orders_insert_own_org'
    ) THEN
        RAISE WARNING '⚠️  Policy manufacturing_orders_insert_own_org is MISSING!';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ManufacturingOrders' 
        AND policyname = 'manufacturing_orders_update_own_org'
    ) THEN
        RAISE WARNING '⚠️  Policy manufacturing_orders_update_own_org is MISSING!';
    END IF;
END;
$$;

-- ====================================================
-- STEP 5: Ensure DirectoryCustomers can be read (for OrderList display)
-- ====================================================

-- Check if DirectoryCustomers RLS is enabled
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables t
        WHERE t.schemaname = 'public'
        AND t.tablename = 'DirectoryCustomers'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_class c
            WHERE c.relname = 'DirectoryCustomers'
            AND c.relrowsecurity = true
        ) THEN
            RAISE NOTICE '🔧 Enabling RLS on DirectoryCustomers...';
            ALTER TABLE "DirectoryCustomers" ENABLE ROW LEVEL SECURITY;
        ELSE
            RAISE NOTICE '✅ RLS is enabled on DirectoryCustomers';
        END IF;
    END IF;
END;
$$;

-- Ensure policy exists for reading DirectoryCustomers (if table exists)
-- Note: We check for existing policies and only create if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables t
        WHERE t.schemaname = 'public'
        AND t.tablename = 'DirectoryCustomers'
    ) THEN
        -- Check if a SELECT policy exists (could have different names)
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies
            WHERE tablename = 'DirectoryCustomers'
            AND cmd = 'SELECT'
        ) THEN
            RAISE WARNING '⚠️  No SELECT policy found for DirectoryCustomers!';
            RAISE NOTICE '🔧 Creating policy...';
            
            CREATE POLICY "directory_customers_select_own_org"
            ON "DirectoryCustomers"
            FOR SELECT
            USING (
                organization_id IN (
                    SELECT organization_id 
                    FROM "OrganizationUsers" 
                    WHERE user_id = auth.uid() 
                    AND deleted = false
                )
                AND deleted = false
            );
            
            RAISE NOTICE '✅ Policy for DirectoryCustomers created';
        ELSE
            RAISE NOTICE '✅ Policy for DirectoryCustomers exists';
        END IF;
    END IF;
END;
$$;

-- ====================================================
-- STEP 6: Verify Functions have SECURITY DEFINER
-- ====================================================

DO $$
DECLARE
    v_func_security text;
BEGIN
    -- Check on_quote_approved_create_operational_docs
    SELECT prosecdef::text INTO v_func_security
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'on_quote_approved_create_operational_docs';
    
    IF v_func_security = 't' THEN
        RAISE NOTICE '✅ Function on_quote_approved_create_operational_docs has SECURITY DEFINER';
    ELSE
        RAISE WARNING '⚠️  Function on_quote_approved_create_operational_docs does NOT have SECURITY DEFINER!';
        RAISE NOTICE '🔧 Updating function...';
        ALTER FUNCTION public.on_quote_approved_create_operational_docs() SECURITY DEFINER;
        RAISE NOTICE '✅ Function updated';
    END IF;
    
    -- Check on_sale_order_confirmed_create_manufacturing_order
    SELECT prosecdef::text INTO v_func_security
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'on_sale_order_confirmed_create_manufacturing_order';
    
    IF v_func_security = 't' THEN
        RAISE NOTICE '✅ Function on_sale_order_confirmed_create_manufacturing_order has SECURITY DEFINER';
    ELSE
        RAISE WARNING '⚠️  Function on_sale_order_confirmed_create_manufacturing_order does NOT have SECURITY DEFINER!';
        RAISE NOTICE '🔧 Updating function...';
        ALTER FUNCTION public.on_sale_order_confirmed_create_manufacturing_order() SECURITY DEFINER;
        RAISE NOTICE '✅ Function updated';
    END IF;
END;
$$;

-- ====================================================
-- STEP 7: Final Verification Queries
-- ====================================================

-- Show all triggers
SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'Enabled'
        WHEN 'D' THEN 'Disabled'
        ELSE 'Unknown'
    END AS trigger_status,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname IN ('Quotes', 'SaleOrders')
AND t.tgname IN ('trg_on_quote_approved_create_operational_docs', 'trg_sale_order_confirmed_create_mo')
ORDER BY c.relname, t.tgname;

-- Show RLS policies for SaleOrders
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'SaleOrders'
ORDER BY policyname;

-- Show RLS policies for ManufacturingOrders
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'ManufacturingOrders'
ORDER BY policyname;

-- Test query: Show confirmed SaleOrders without ManufacturingOrders (what OrderList should show)
-- This query should work with the existing RLS policies
SELECT 
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.organization_id,
    dc.customer_name,
    mo.id AS manufacturing_order_id,
    mo.manufacturing_order_no,
    CASE 
        WHEN mo.id IS NULL THEN 'Needs MO'
        ELSE 'Has MO'
    END AS mo_status
FROM "SaleOrders" so
LEFT JOIN "DirectoryCustomers" dc ON dc.id = so.customer_id AND dc.deleted = false
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
WHERE so.status = 'Confirmed'
AND so.deleted = false
ORDER BY 
    CASE WHEN mo.id IS NULL THEN 0 ELSE 1 END, -- Show "Needs MO" first
    so.created_at DESC
LIMIT 20;

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
    RAISE NOTICE 'Verified/Fixed:';
    RAISE NOTICE '  ✅ Quote -> SaleOrder trigger';
    RAISE NOTICE '  ✅ SaleOrder -> ManufacturingOrder trigger';
    RAISE NOTICE '  ✅ RLS policies for SaleOrders';
    RAISE NOTICE '  ✅ RLS policies for ManufacturingOrders';
    RAISE NOTICE '  ✅ RLS policies for DirectoryCustomers';
    RAISE NOTICE '  ✅ Function security (SECURITY DEFINER)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Test creating a Quote and approving it';
    RAISE NOTICE '  2. Verify SaleOrder is created automatically';
    RAISE NOTICE '  3. Change SaleOrder status to "Confirmed"';
    RAISE NOTICE '  4. Verify ManufacturingOrder is created automatically';
    RAISE NOTICE '  5. Check OrderList shows confirmed SaleOrders without MOs';
    RAISE NOTICE '';
END;
$$;

