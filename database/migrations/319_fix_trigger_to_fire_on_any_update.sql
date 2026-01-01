-- ====================================================
-- Migration 319: Fix Trigger to Fire on Any UPDATE
-- ====================================================
-- PROBLEM: Trigger only fires on UPDATE OF status, but frontend might
--          be doing full UPDATEs. Change to fire on any UPDATE and check
--          status change internally.
-- ====================================================

BEGIN;

-- Drop existing trigger
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

-- Recreate trigger to fire on ANY UPDATE (not just status)
CREATE TRIGGER trg_on_quote_approved_create_operational_docs
AFTER UPDATE ON "Quotes"
FOR EACH ROW
WHEN (
    NEW.deleted = false
    AND NEW.status IS NOT NULL
    AND (NEW.status::text ILIKE 'approved' OR NEW.status::text = 'Approved')
    AND (OLD.status IS DISTINCT FROM NEW.status)  -- Only if status actually changed
)
EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Enable the trigger
ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;

COMMENT ON TRIGGER trg_on_quote_approved_create_operational_docs ON "Quotes" IS 
    'Creates SalesOrder when quote status transitions to Approved. Fires on ANY UPDATE (not just status field) to ensure it catches all status changes. Idempotent and handles case-insensitive status matching.';

-- Add logging to verify trigger fires
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs recreated and enabled';
    RAISE NOTICE '   - Now fires on ANY UPDATE (not just UPDATE OF status)';
    RAISE NOTICE '   - Checks status change internally in WHEN clause';
END $$;

COMMIT;

-- ====================================================
-- Verification: Test trigger manually
-- ====================================================
/*
-- To test the trigger manually, run this (replace with actual quote_id):
DO $$
DECLARE
    v_test_quote_id uuid := '<QUOTE_ID>'::uuid;  -- Replace with actual quote_id
    v_old_status text;
    v_new_status text := 'Approved';
BEGIN
    -- Get current status
    SELECT status::text INTO v_old_status
    FROM "Quotes"
    WHERE id = v_test_quote_id;
    
    RAISE NOTICE 'Testing trigger with Quote %', v_test_quote_id;
    RAISE NOTICE '  Old status: %', v_old_status;
    RAISE NOTICE '  New status: %', v_new_status;
    
    -- Update status to trigger
    UPDATE "Quotes"
    SET status = v_new_status::quote_status,
        updated_at = now()
    WHERE id = v_test_quote_id;
    
    RAISE NOTICE '✅ Trigger should have fired. Check logs for ensure_sales_order_for_approved_quote messages.';
END $$;
*/


