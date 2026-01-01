-- ====================================================
-- Migration 282: Diagnose SalesOrder Creation Issue
-- ====================================================
-- Script to diagnose why SalesOrders are not being created
-- when quotes are approved
-- ====================================================

DO $$
DECLARE
    v_approved_quote_id uuid;
    v_quote_record RECORD;
    v_sale_order_count integer;
    v_trigger_exists boolean;
    v_function_exists boolean;
    v_trigger_enabled boolean;
BEGIN
    RAISE NOTICE '🔍 DIAGNOSTIC: SalesOrder Creation Issue';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    
    -- 1. Check if trigger exists and is enabled
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_on_quote_approved_create_operational_docs'
    ) INTO v_trigger_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'on_quote_approved_create_operational_docs'
    ) INTO v_function_exists;
    
    SELECT tgenabled = 'O' INTO v_trigger_enabled
    FROM pg_trigger 
    WHERE tgname = 'trg_on_quote_approved_create_operational_docs';
    
    RAISE NOTICE '1. TRIGGER STATUS:';
    RAISE NOTICE '   Trigger exists: %', v_trigger_exists;
    RAISE NOTICE '   Function exists: %', v_function_exists;
    RAISE NOTICE '   Trigger enabled: %', COALESCE(v_trigger_enabled::text, 'N/A');
    RAISE NOTICE '';
    
    -- 2. Find approved quotes without SalesOrders
    RAISE NOTICE '2. APPROVED QUOTES WITHOUT SALESORDERS:';
    FOR v_quote_record IN
        SELECT q.id, q.quote_no, q.status, q.organization_id, q.created_at
        FROM "Quotes" q
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "SalesOrders" so
            WHERE so.quote_id = q.id
            AND so.deleted = false
        )
        ORDER BY q.created_at DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '   Quote: % (%) - Created: % - Org: %', 
            v_quote_record.quote_no, 
            v_quote_record.id, 
            v_quote_record.created_at,
            v_quote_record.organization_id;
        
        -- Check if SalesOrder exists but is deleted
        SELECT COUNT(*) INTO v_sale_order_count
        FROM "SalesOrders"
        WHERE quote_id = v_quote_record.id
        AND deleted = true;
        
        IF v_sale_order_count > 0 THEN
            RAISE NOTICE '      ⚠️  SalesOrder exists but is DELETED (count: %)', v_sale_order_count;
        END IF;
        
        -- Check QuoteLines
        SELECT COUNT(*) INTO v_sale_order_count
        FROM "QuoteLines"
        WHERE quote_id = v_quote_record.id
        AND deleted = false;
        
        RAISE NOTICE '      QuoteLines (not deleted): %', v_sale_order_count;
    END LOOP;
    RAISE NOTICE '';
    
    -- 3. Check recent SalesOrders
    RAISE NOTICE '3. RECENT SALESORDERS (last 5):';
    FOR v_quote_record IN
        SELECT so.id, so.sale_order_no, so.quote_id, so.status, so.deleted, so.created_at
        FROM "SalesOrders" so
        ORDER BY so.created_at DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '   SO: % - Quote: % - Status: % - Deleted: % - Created: %',
            v_quote_record.sale_order_no,
            v_quote_record.quote_id,
            v_quote_record.status,
            v_quote_record.deleted,
            v_quote_record.created_at;
    END LOOP;
    RAISE NOTICE '';
    
    -- 4. Check if tables exist
    RAISE NOTICE '4. TABLE EXISTENCE:';
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'SalesOrders') THEN
        RAISE NOTICE '   ✅ SalesOrders table exists';
    ELSE
        RAISE NOTICE '   ❌ SalesOrders table DOES NOT EXIST';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'SalesOrderLines') THEN
        RAISE NOTICE '   ✅ SalesOrderLines table exists';
    ELSE
        RAISE NOTICE '   ❌ SalesOrderLines table DOES NOT EXIST';
    END IF;
    RAISE NOTICE '';
    
    -- 5. Check RLS policies
    RAISE NOTICE '5. RLS POLICIES ON SalesOrders:';
    FOR v_quote_record IN
        SELECT pol.polname, pol.polcmd, pol.polpermissive
        FROM pg_policy pol
        JOIN pg_class cls ON cls.oid = pol.polrelid
        WHERE cls.relname = 'SalesOrders'
    LOOP
        RAISE NOTICE '   Policy: % - Command: % - Permissive: %',
            v_quote_record.id,
            v_quote_record.quote_no,
            v_quote_record.status;
    END LOOP;
    
    IF NOT FOUND THEN
        RAISE NOTICE '   ⚠️  No RLS policies found (or RLS not enabled)';
    END IF;
    RAISE NOTICE '';
    
    -- 6. Test trigger manually (if we have an approved quote)
    SELECT id INTO v_approved_quote_id
    FROM "Quotes"
    WHERE status = 'approved'
    AND deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SalesOrders" so
        WHERE so.quote_id = "Quotes".id
        AND so.deleted = false
    )
    LIMIT 1;
    
    IF v_approved_quote_id IS NOT NULL THEN
        RAISE NOTICE '6. MANUAL TRIGGER TEST:';
        RAISE NOTICE '   Found approved quote without SalesOrder: %', v_approved_quote_id;
        RAISE NOTICE '   To test manually, run:';
        RAISE NOTICE '   SELECT public.on_quote_approved_create_operational_docs() FROM (SELECT %::uuid as id, ''approved''::text as status) AS NEW;', v_approved_quote_id;
    ELSE
        RAISE NOTICE '6. MANUAL TRIGGER TEST:';
        RAISE NOTICE '   No approved quotes without SalesOrders found';
    END IF;
    RAISE NOTICE '';
    
    RAISE NOTICE '✅ Diagnostic complete';
END $$;

-- Also provide a query to manually test trigger for a specific quote
-- Replace <QUOTE_ID> with actual quote ID
/*
DO $$
DECLARE
    v_quote_id uuid := '<QUOTE_ID>'::uuid;
    v_old_record RECORD;
    v_new_record RECORD;
BEGIN
    -- Get quote data
    SELECT * INTO v_new_record FROM "Quotes" WHERE id = v_quote_id;
    
    -- Simulate OLD record (status != approved)
    v_old_record := v_new_record;
    v_old_record.status := 'draft';
    
    -- Call trigger function manually
    PERFORM public.on_quote_approved_create_operational_docs();
    
    RAISE NOTICE 'Trigger executed for quote %', v_quote_id;
END $$;
*/


