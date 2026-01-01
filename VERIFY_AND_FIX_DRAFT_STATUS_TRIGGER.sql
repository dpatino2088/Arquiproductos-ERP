-- ====================================================
-- VERIFY AND FIX: Draft Status Not Updating SO Status
-- ====================================================
-- This script verifies the trigger is working and fixes if needed
-- ====================================================

-- ====================================================
-- STEP 1: Verify trigger exists and is active
-- ====================================================

DO $$
DECLARE
    v_trigger_exists boolean;
    v_trigger_enabled text;
    v_function_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔍 DIAGNOSIS: Trigger Status Check';
    RAISE NOTICE '====================================================';
    
    -- Check if trigger exists
    SELECT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND NOT t.tgisinternal
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        -- Check trigger enabled status
        SELECT CASE t.tgenabled
            WHEN 'O' THEN 'ENABLED'
            WHEN 'D' THEN 'DISABLED'
            WHEN 'R' THEN 'REPLICA'
            WHEN 'A' THEN 'ALWAYS'
            ELSE 'UNKNOWN'
        END
        INTO v_trigger_enabled
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND NOT t.tgisinternal;
        
        RAISE NOTICE '✅ Trigger trg_mo_insert_generate_bom EXISTS';
        RAISE NOTICE '   Status: %', v_trigger_enabled;
        
        IF v_trigger_enabled <> 'ENABLED' THEN
            RAISE WARNING '⚠️ WARNING: Trigger is NOT ENABLED!';
        END IF;
    ELSE
        RAISE WARNING '❌ Trigger trg_mo_insert_generate_bom does NOT exist';
    END IF;
    
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_manufacturing_order_insert_generate_bom'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Function on_manufacturing_order_insert_generate_bom EXISTS';
    ELSE
        RAISE WARNING '❌ Function on_manufacturing_order_insert_generate_bom does NOT exist';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: Check recent MOs and their SO statuses
-- ====================================================

SELECT
    'Recent MO Status Check' as check_type,
    mo.manufacturing_order_no,
    mo.status as mo_status,
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN mo.status = 'draft' AND so.status = 'Scheduled for Production' THEN '✅ CORRECT'
        WHEN mo.status = 'draft' AND so.status <> 'Scheduled for Production' THEN '❌ WRONG - Should be "Scheduled for Production"'
        ELSE 'N/A'
    END as status_check
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.deleted = false
AND so.deleted = false
ORDER BY mo.created_at DESC
LIMIT 10;

-- ====================================================
-- STEP 3: Verify function logic is correct
-- ====================================================

DO $$
DECLARE
    v_function_def text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔍 Checking function definition...';
    RAISE NOTICE '====================================================';
    
    SELECT pg_get_functiondef(oid) INTO v_function_def
    FROM pg_proc
    WHERE proname = 'on_manufacturing_order_insert_generate_bom'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    LIMIT 1;
    
    IF v_function_def IS NULL THEN
        RAISE WARNING '❌ Function definition not found';
    ELSE
        IF v_function_def LIKE '%Scheduled for Production%' THEN
            RAISE NOTICE '✅ Function contains "Scheduled for Production"';
        ELSE
            RAISE WARNING '⚠️ Function does NOT contain "Scheduled for Production"';
        END IF;
        
        IF v_function_def LIKE '%NEW.status = ''draft''%' OR v_function_def LIKE '%NEW.status = ''draft''%' THEN
            RAISE NOTICE '✅ Function checks for status = ''draft''';
        ELSE
            RAISE WARNING '⚠️ Function may NOT check for status = ''draft'' correctly';
        END IF;
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 4: Recreate function with explicit logging
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_bom_lines_count integer;
    v_current_so_status text;
    v_updated_rows integer;
BEGIN
    -- ====================================================
    -- CRITICAL: DO NOT MODIFY ManufacturingOrder.status
    -- Status must remain as inserted (DRAFT)
    -- ====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔔 TRIGGER FIRED: on_manufacturing_order_insert_generate_bom';
    RAISE NOTICE '   MO ID: %', NEW.id;
    RAISE NOTICE '   MO Number: %', NEW.manufacturing_order_no;
    RAISE NOTICE '   MO Status: %', NEW.status;
    RAISE NOTICE '   SO ID: %', NEW.sale_order_id;
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
    
    v_current_so_status := v_sales_order_record.status;
    RAISE NOTICE '📋 SalesOrder Found: %', v_sales_order_record.sale_order_no;
    RAISE NOTICE '   Current SO Status: %', v_current_so_status;
    
    -- ====================================================
    -- CRITICAL: Update SalesOrder status based on MO status
    -- ====================================================
    
    IF NEW.status = 'draft' THEN
        RAISE NOTICE '🔧 MO status is ''draft'' → Updating SO to "Scheduled for Production"';
        
        -- MO is Draft → SO should be "Scheduled for Production"
        UPDATE "SalesOrders"
        SET status = 'Scheduled for Production',
            updated_at = now()
        WHERE id = NEW.sale_order_id
        AND deleted = false
        AND status <> 'Delivered';
        
        GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
        
        IF v_updated_rows > 0 THEN
            RAISE NOTICE '✅ SUCCESS: SalesOrder status updated from "%" to "Scheduled for Production"', v_current_so_status;
        ELSE
            RAISE WARNING '⚠️ WARNING: No rows updated. Possible reasons:';
            RAISE WARNING '   - SO status is already "Delivered" (cannot be changed)';
            RAISE WARNING '   - SO is deleted';
            RAISE WARNING '   - SO ID mismatch';
        END IF;
    ELSE
        RAISE NOTICE '⏭️  MO status is "%" (not draft), using mapping function', NEW.status;
        
        -- For other MO statuses, use the mapping function
        DECLARE
            v_mapped_status text;
        BEGIN
            v_mapped_status := public.map_mo_status_to_so_status(NEW.status);
            
            IF v_mapped_status IS NOT NULL AND v_mapped_status <> v_current_so_status AND v_current_so_status <> 'Delivered' THEN
                UPDATE "SalesOrders"
                SET status = v_mapped_status,
                    updated_at = now()
                WHERE id = NEW.sale_order_id
                AND deleted = false
                AND status <> 'Delivered';
                
                GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
                
                IF v_updated_rows > 0 THEN
                    RAISE NOTICE '✅ SalesOrder status updated from "%" to "%" (MO status: %)', v_current_so_status, v_mapped_status, NEW.status;
                END IF;
            ELSE
                RAISE NOTICE '⏭️  SalesOrder status unchanged: % (mapped: %, current: %)', v_current_so_status, v_mapped_status, v_current_so_status;
            END IF;
        END;
    END IF;
    
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
        RAISE NOTICE '✅ BOM exists with % lines', v_bom_lines_count;
    ELSE
        RAISE NOTICE '⚠️ No BOM lines found';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Trigger completed for ManufacturingOrder %', NEW.manufacturing_order_no;
    RAISE NOTICE '';
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ ERROR in trigger: %', SQLERRM;
        RAISE WARNING '   SQLSTATE: %', SQLSTATE;
        RAISE WARNING '   MO ID: %, SO ID: %', NEW.id, NEW.sale_order_id;
        -- Don't block MO creation
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Updates SalesOrder status when ManufacturingOrder is created.
If MO status = draft → SO status = "Scheduled for Production"
Other statuses use map_mo_status_to_so_status function.';

-- ====================================================
-- STEP 5: Ensure trigger exists and is ENABLED
-- ====================================================

DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Updates SalesOrder status to "Scheduled for Production" when ManufacturingOrder is created with status=draft.';

-- ====================================================
-- STEP 6: Final verification
-- ====================================================

DO $$
DECLARE
    v_trigger_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FINAL VERIFICATION';
    RAISE NOTICE '====================================================';
    
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'ManufacturingOrders'
    AND t.tgname = 'trg_mo_insert_generate_bom'
    AND NOT t.tgisinternal
    AND t.tgenabled = 'O';
    
    IF v_trigger_count > 0 THEN
        RAISE NOTICE '✅ Trigger trg_mo_insert_generate_bom is ACTIVE and ENABLED';
    ELSE
        RAISE WARNING '❌ Trigger is NOT active or enabled';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST: Create a new MO with status=draft and check SO status';
    RAISE NOTICE '   Expected: SO status should change to "Scheduled for Production"';
    RAISE NOTICE '';
END;
$$;






