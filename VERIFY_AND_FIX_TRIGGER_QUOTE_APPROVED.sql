-- ====================================================
-- Verify and Fix Trigger for Quote Approved
-- ====================================================
-- This script verifies the trigger exists and is active,
-- and recreates it if necessary
-- ====================================================

-- STEP 1: Check if function exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE EXCEPTION 'Function on_quote_approved_create_operational_docs does not exist. Please run migration 197 first.';
    ELSE
        RAISE NOTICE '✅ Function on_quote_approved_create_operational_docs exists';
    END IF;
END;
$$;

-- STEP 2: Check if trigger exists and is enabled
DO $$
DECLARE
    v_trigger_exists boolean;
    v_trigger_enabled text;
BEGIN
    SELECT 
        EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'Quotes'
            AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        ),
        CASE t.tgenabled
            WHEN 'O' THEN 'Enabled'
            WHEN 'D' THEN 'Disabled'
            ELSE 'Unknown'
        END
    INTO v_trigger_exists, v_trigger_enabled
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'Quotes'
    AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
    LIMIT 1;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger exists and is %', v_trigger_enabled;
        IF v_trigger_enabled = 'Disabled' THEN
            RAISE WARNING '⚠️  Trigger is DISABLED! Enabling now...';
            ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;
            RAISE NOTICE '✅ Trigger enabled';
        END IF;
    ELSE
        RAISE WARNING '❌ Trigger does not exist! Creating now...';
    END IF;
END;
$$;

-- STEP 3: Drop and recreate trigger to ensure it's correct
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- STEP 4: Verify trigger was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        AND t.tgenabled = 'O'
    ) THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs is now active and enabled';
    ELSE
        RAISE WARNING '❌ Trigger was not created or is disabled!';
    END IF;
END;
$$;

-- STEP 5: Show trigger details
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
WHERE c.relname = 'Quotes'
AND t.tgname = 'trg_on_quote_approved_create_operational_docs';

-- STEP 6: Test query - show approved quotes without Sales Orders
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status,
    q.updated_at AS last_status_change,
    so.id AS sales_order_id,
    so.sale_order_no
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 10;








