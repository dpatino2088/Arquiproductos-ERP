-- ====================================================
-- Ensure Trigger is Active
-- ====================================================
-- This script ensures the trigger exists and is active
-- ====================================================

-- Step 1: Check if function exists, if not, we need to run migration 197 first
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE EXCEPTION 'Function on_quote_approved_create_operational_docs does not exist. Please run migration 197 first: database/migrations/197_ensure_quote_approved_trigger_works.sql';
    ELSE
        RAISE NOTICE '✅ Function exists';
    END IF;
END;
$$;

-- Step 2: Drop trigger if exists (to recreate it fresh)
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

-- Step 3: Create trigger
CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Step 4: Verify trigger was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs is now active';
    ELSE
        RAISE WARNING '❌ Trigger was not created!';
    END IF;
END;
$$;

-- Step 5: Show trigger details
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








