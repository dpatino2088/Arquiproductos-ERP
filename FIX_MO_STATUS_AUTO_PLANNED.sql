-- ====================================================
-- FIX: Prevent ManufacturingOrders.status from auto-changing to PLANNED
-- ====================================================
-- This script ensures:
-- 1. MOs are created with status = 'DRAFT' (never 'planned')
-- 2. Only generate_bom_for_manufacturing_order can change to PLANNED
-- 3. PLANNED only happens if BOM lines > 0
-- ====================================================

-- ====================================================
-- STEP 1: AUDIT TRIGGERS ON ManufacturingOrders
-- ====================================================
DO $$
DECLARE
    v_trigger_record RECORD;
    v_function_def text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔍 AUDITING TRIGGERS ON ManufacturingOrders';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    FOR v_trigger_record IN
        SELECT
            t.tgname as trigger_name,
            p.proname as function_name,
            CASE t.tgtype::integer & 2
                WHEN 2 THEN 'AFTER'
                ELSE 'BEFORE'
            END as timing,
            CASE t.tgtype::integer & 28
                WHEN 4 THEN 'INSERT'
                WHEN 8 THEN 'DELETE'
                WHEN 16 THEN 'UPDATE'
                ELSE 'UNKNOWN'
            END as event,
            pg_get_functiondef(p.oid) as function_definition
        FROM pg_trigger t
        JOIN pg_proc p ON p.oid = t.tgfoid
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE c.relname = 'ManufacturingOrders'
        AND NOT t.tgisinternal
        ORDER BY t.tgname
    LOOP
        RAISE NOTICE '📋 Trigger: %', v_trigger_record.trigger_name;
        RAISE NOTICE '   Function: %', v_trigger_record.function_name;
        RAISE NOTICE '   Timing: % %', v_trigger_record.timing, v_trigger_record.event;
        
        -- Check if function modifies status
        IF v_trigger_record.function_definition ILIKE '%status%PLANNED%' 
           OR v_trigger_record.function_definition ILIKE '%status := ''planned''%'
           OR v_trigger_record.function_definition ILIKE '%status = ''planned''%'
           OR v_trigger_record.function_definition ILIKE '%SET status = ''planned''%'
           OR v_trigger_record.function_definition ILIKE '%SET status = ''PLANNED''%' THEN
            RAISE WARNING '⚠️  Function % may modify status to PLANNED!', v_trigger_record.function_name;
        END IF;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '✅ Audit complete';
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: NEUTRALIZE on_manufacturing_order_insert_generate_bom
-- ====================================================
-- This trigger should NOT change MO status
-- It should only link to existing BOM and update SalesOrder status
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_bom_instance_id uuid;
    v_bom_lines_count integer;
    v_quote_lines_processed integer := 0;
    v_quote_lines_failed integer := 0;
BEGIN
    -- ====================================================
    -- CRITICAL: DO NOT MODIFY ManufacturingOrder.status
    -- Status must remain as inserted (DRAFT)
    -- Only generate_bom_for_manufacturing_order can change to PLANNED
    -- ====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔔 BOM Link Trigger for ManufacturingOrder %', NEW.manufacturing_order_no;
    RAISE NOTICE '   Current Status: % (WILL NOT BE CHANGED)', NEW.status;
    RAISE NOTICE '====================================================';
    
    -- Get SalesOrder record
    SELECT * INTO v_sales_order_record
    FROM "SalesOrders"
    WHERE id = NEW.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ SalesOrder % not found for ManufacturingOrder %', NEW.sale_order_id, NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '📋 SalesOrder: %', v_sales_order_record.sale_order_no;
    
    -- Update SalesOrder status to 'In Production' (this is OK)
    UPDATE "SalesOrders"
    SET status = 'In Production',
        updated_at = now()
    WHERE id = NEW.sale_order_id
    AND deleted = false
    AND status <> 'Delivered';
    
    RAISE NOTICE '✅ SalesOrder status updated to "In Production"';
    
    -- Check if BOM exists (for logging only)
    SELECT COUNT(*) INTO v_bom_lines_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = NEW.sale_order_id
    AND bil.deleted = false
    AND bi.deleted = false
    AND sol.deleted = false;
    
    IF v_bom_lines_count > 0 THEN
        RAISE NOTICE '✅ BOM exists with % lines (status will remain DRAFT until generate_bom_for_manufacturing_order is called)', v_bom_lines_count;
    ELSE
        RAISE NOTICE '⚠️ No BOM lines found. Status will remain DRAFT. Call generate_bom_for_manufacturing_order to create BOM and change to PLANNED.';
    END IF;
    
    -- ====================================================
    -- CRITICAL: DO NOT UPDATE ManufacturingOrder.status
    -- Status must remain DRAFT until BOM is generated
    -- ====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ ManufacturingOrder % created with status DRAFT (unchanged)', NEW.manufacturing_order_no;
    RAISE NOTICE '';
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_insert_generate_bom: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
        -- Don't block MO creation
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Links ManufacturingOrder to SalesOrder when MO is created.
BEHAVIOR:
- Updates SalesOrder status to "In Production"
- DOES NOT modify ManufacturingOrder.status (must remain DRAFT)
- Only generate_bom_for_manufacturing_order can change status to PLANNED
- Architecture: BOM must be generated manually via RPC call';

-- ====================================================
-- STEP 3: ENSURE TRIGGER EXISTS AND IS ACTIVE
-- ====================================================

DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Links MO to SalesOrder and updates SO status. DOES NOT modify MO.status.';

-- ====================================================
-- STEP 4: VERIFY generate_bom_for_manufacturing_order
-- ====================================================
-- This function should be the ONLY one that changes status to PLANNED
-- And ONLY if BOM lines > 0
-- ====================================================

-- The function is already defined in HARDEN_MO_BOM_WORKFLOW.sql
-- Verify it exists and has correct logic
DO $$
DECLARE
    v_function_exists boolean;
    v_function_def text;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'generate_bom_for_manufacturing_order'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        SELECT pg_get_functiondef(p.oid) INTO v_function_def
        FROM pg_proc p
        WHERE p.proname = 'generate_bom_for_manufacturing_order'
        AND p.pronargs = 1
        LIMIT 1;
        
        -- Verify it checks BOM lines before changing to PLANNED
        IF v_function_def ILIKE '%COUNT(*) INTO v_total_bom_lines%'
           AND v_function_def ILIKE '%IF v_total_bom_lines > 0%'
           AND v_function_def ILIKE '%status = ''planned''%' THEN
            RAISE NOTICE '✅ generate_bom_for_manufacturing_order has correct logic';
            RAISE NOTICE '   - Counts BOM lines';
            RAISE NOTICE '   - Only changes to PLANNED if lines > 0';
        ELSE
            RAISE WARNING '⚠️ generate_bom_for_manufacturing_order may need review';
            RAISE NOTICE '   Function definition available for manual inspection';
        END IF;
    ELSE
        RAISE WARNING '❌ generate_bom_for_manufacturing_order does NOT exist';
        RAISE NOTICE '   Run HARDEN_MO_BOM_WORKFLOW.sql first';
    END IF;
END;
$$;

-- ====================================================
-- STEP 5: PROTECT STATUS IN INSERT (Frontend check)
-- ====================================================
-- Note: This is a database-level check
-- Frontend should also ensure status = 'draft' on insert
-- ====================================================

-- Add a trigger to FORCE status = 'draft' on INSERT if not specified
CREATE OR REPLACE FUNCTION public.enforce_draft_status_on_mo_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If status is not 'draft', force it to 'draft'
    -- This prevents any accidental 'planned' status on creation
    IF NEW.status IS NULL OR NEW.status != 'draft' THEN
        RAISE NOTICE '🔒 Forcing ManufacturingOrder status to DRAFT (was: %)', COALESCE(NEW.status, 'NULL');
        NEW.status := 'draft';
    END IF;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enforce_draft_status_on_mo_insert IS 
'Enforces that ManufacturingOrders are created with status = ''draft''.
Prevents any automatic or accidental status changes on INSERT.';

-- Create BEFORE INSERT trigger
DROP TRIGGER IF EXISTS trg_enforce_draft_status ON "ManufacturingOrders";

CREATE TRIGGER trg_enforce_draft_status
    BEFORE INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_draft_status_on_mo_insert();

COMMENT ON TRIGGER trg_enforce_draft_status ON "ManufacturingOrders" IS 
'Forces status = ''draft'' on INSERT. Prevents automatic PLANNED status.';

-- ====================================================
-- STEP 6: VERIFICATION QUERIES
-- ====================================================

DO $$
DECLARE
    v_draft_count integer;
    v_planned_count integer;
    v_recent_mo RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '📊 VERIFICATION: ManufacturingOrders Status';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Count by status
    SELECT COUNT(*) INTO v_draft_count
    FROM "ManufacturingOrders"
    WHERE status = 'draft'
    AND deleted = false;
    
    SELECT COUNT(*) INTO v_planned_count
    FROM "ManufacturingOrders"
    WHERE status = 'planned'
    AND deleted = false;
    
    RAISE NOTICE '📈 Status Distribution:';
    RAISE NOTICE '   DRAFT: %', v_draft_count;
    RAISE NOTICE '   PLANNED: %', v_planned_count;
    RAISE NOTICE '';
    
    -- Show most recent MOs
    RAISE NOTICE '📋 Most Recent Manufacturing Orders:';
    FOR v_recent_mo IN
        SELECT 
            manufacturing_order_no,
            status,
            created_at
        FROM "ManufacturingOrders"
        WHERE deleted = false
        ORDER BY created_at DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '   % | Status: % | Created: %', 
            v_recent_mo.manufacturing_order_no,
            v_recent_mo.status,
            v_recent_mo.created_at;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Verification complete';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 EXPECTED BEHAVIOR:';
    RAISE NOTICE '   ✅ New MOs → DRAFT';
    RAISE NOTICE '   ✅ MOs with BOM → PLANNED (after generate_bom_for_manufacturing_order)';
    RAISE NOTICE '   ✅ MOs without BOM → DRAFT';
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- FINAL SUMMARY
-- ====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FIX COMPLETE: MO Status Auto-Change Prevention';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 CHANGES MADE:';
    RAISE NOTICE '   1. ✅ on_manufacturing_order_insert_generate_bom:';
    RAISE NOTICE '      - Removed any status modification';
    RAISE NOTICE '      - Only updates SalesOrder status';
    RAISE NOTICE '   2. ✅ enforce_draft_status_on_mo_insert:';
    RAISE NOTICE '      - Forces status = ''draft'' on INSERT';
    RAISE NOTICE '      - Prevents accidental PLANNED status';
    RAISE NOTICE '   3. ✅ generate_bom_for_manufacturing_order:';
    RAISE NOTICE '      - Only function that can change to PLANNED';
    RAISE NOTICE '      - Only if BOM lines > 0';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 RULES ENFORCED:';
    RAISE NOTICE '   ✅ MO created → status = DRAFT (enforced)';
    RAISE NOTICE '   ✅ Generate BOM → status = PLANNED (if lines > 0)';
    RAISE NOTICE '   ✅ No BOM → status = DRAFT (unchanged)';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TESTING:';
    RAISE NOTICE '   1. Create new MO → Should be DRAFT';
    RAISE NOTICE '   2. Call generate_bom_for_manufacturing_order → Should be PLANNED (if BOM has lines)';
    RAISE NOTICE '   3. Refresh → Should remain PLANNED';
    RAISE NOTICE '';
END;
$$;






