-- ====================================================
-- Ensure the trigger exists and is enabled
-- ====================================================
-- This creates the trigger if it doesn't exist
-- ====================================================

-- Drop trigger if it exists (to recreate it)
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

-- Create the trigger
CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Verify it was created
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    CASE tgenabled
        WHEN 'O' THEN 'origin (enabled)'
        WHEN 'D' THEN 'disabled'
        WHEN 'R' THEN 'replica'
        WHEN 'A' THEN 'always (enabled)'
        ELSE 'unknown'
    END as trigger_status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';



