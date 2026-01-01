-- ====================================================
-- FIX: Ensure Trigger Updates SO Status to "Scheduled for Production"
-- ====================================================
-- This script:
-- 1. Verifies the trigger exists and is active
-- 2. Updates the function to correctly set "Scheduled for Production"
-- 3. Creates/recreates the trigger if needed
-- ====================================================

-- ====================================================
-- STEP 1: Verify current trigger status
-- ====================================================

DO $$
DECLARE
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔍 Checking trigger status...';
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
        -- Check if trigger is enabled
        SELECT t.tgenabled = 'O' INTO v_trigger_enabled
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND NOT t.tgisinternal;
        
        IF v_trigger_enabled THEN
            RAISE NOTICE '✅ Trigger trg_mo_insert_generate_bom exists and is ENABLED';
        ELSE
            RAISE WARNING '⚠️ Trigger trg_mo_insert_generate_bom exists but is DISABLED';
        END IF;
    ELSE
        RAISE WARNING '❌ Trigger trg_mo_insert_generate_bom does NOT exist';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: Update function to correctly set status
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
BEGIN
    -- ====================================================
    -- CRITICAL: DO NOT MODIFY ManufacturingOrder.status
    -- Status must remain as inserted (DRAFT)
    -- Only generate_bom_for_manufacturing_order can change to PLANNED
    -- ====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔔 BOM Link Trigger for ManufacturingOrder %', NEW.manufacturing_order_no;
    RAISE NOTICE '   Current MO Status: % (WILL NOT BE CHANGED)', NEW.status;
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
    RAISE NOTICE '📋 SalesOrder: % (Current status: %)', v_sales_order_record.sale_order_no, v_current_so_status;
    
    -- ====================================================
    -- CRITICAL: Update SalesOrder status based on MO status
    -- ====================================================
    -- If MO status = 'draft' → SO status = 'Scheduled for Production'
    -- ====================================================
    
    IF NEW.status = 'draft' THEN
        -- MO is Draft → SO should be "Scheduled for Production"
        -- Only update if current status is not already "Scheduled for Production" or "Delivered"
        IF v_current_so_status <> 'Scheduled for Production' AND v_current_so_status <> 'Delivered' THEN
            UPDATE "SalesOrders"
            SET status = 'Scheduled for Production',
                updated_at = now()
            WHERE id = NEW.sale_order_id
            AND deleted = false
            AND status <> 'Delivered';
            
            RAISE NOTICE '✅ SalesOrder status updated from "%" to "Scheduled for Production" (MO is Draft)', v_current_so_status;
        ELSE
            RAISE NOTICE '⏭️  SalesOrder status already "%", skipping update', v_current_so_status;
        END IF;
    ELSE
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
                
                RAISE NOTICE '✅ SalesOrder status updated from "%" to "%" (MO status: %)', v_current_so_status, v_mapped_status, NEW.status;
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
        RAISE NOTICE '✅ BOM exists with % lines (status will remain DRAFT until generate_bom_for_manufacturing_order is called)', v_bom_lines_count;
    ELSE
        RAISE NOTICE '⚠️ No BOM lines found. Status will remain DRAFT. Call generate_bom_for_manufacturing_order to create BOM and change to PLANNED.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ ManufacturingOrder % created with status DRAFT (unchanged)', NEW.manufacturing_order_no;
    RAISE NOTICE '';
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_insert_generate_bom: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
        RAISE WARNING '   MO ID: %, SO ID: %', NEW.id, NEW.sale_order_id;
        -- Don't block MO creation
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Links ManufacturingOrder to SalesOrder when MO is created.
BEHAVIOR:
- If MO status = draft → Updates SalesOrder status to "Scheduled for Production"
- If MO status = planned → Updates SalesOrder status to "In Production" (via map function)
- If MO status = in_production → Updates SalesOrder status to "In Production"
- If MO status = completed → Updates SalesOrder status to "Ready for Delivery"
- DOES NOT modify ManufacturingOrder.status (must remain DRAFT)
- Only generate_bom_for_manufacturing_order can change MO status to PLANNED
- Architecture: BOM must be generated manually via RPC call';

-- ====================================================
-- STEP 3: Ensure trigger exists and is active
-- ====================================================

DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Updates SalesOrder status to "Scheduled for Production" when ManufacturingOrder is created with status=draft. Does not modify MO status.';

-- ====================================================
-- STEP 4: Verification and test query
-- ====================================================

DO $$
DECLARE
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
    v_function_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Verification Complete';
    RAISE NOTICE '====================================================';
    
    -- Verify trigger exists and is enabled
    SELECT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND NOT t.tgisinternal
        AND t.tgenabled = 'O'
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_mo_insert_generate_bom is ACTIVE';
    ELSE
        RAISE WARNING '❌ Trigger trg_mo_insert_generate_bom is NOT active';
    END IF;
    
    -- Verify function exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_manufacturing_order_insert_generate_bom'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Function on_manufacturing_order_insert_generate_bom exists';
    ELSE
        RAISE WARNING '❌ Function on_manufacturing_order_insert_generate_bom does NOT exist';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 EXPECTED BEHAVIOR:';
    RAISE NOTICE '   When MO is created with status=draft → SO status="Scheduled for Production"';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST QUERY (run after creating a new MO):';
    RAISE NOTICE '   SELECT';
    RAISE NOTICE '       mo.manufacturing_order_no,';
    RAISE NOTICE '       mo.status as mo_status,';
    RAISE NOTICE '       so.sale_order_no,';
    RAISE NOTICE '       so.status as so_status';
    RAISE NOTICE '   FROM "ManufacturingOrders" mo';
    RAISE NOTICE '   INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id';
    RAISE NOTICE '   WHERE mo.deleted = false';
    RAISE NOTICE '   ORDER BY mo.created_at DESC';
    RAISE NOTICE '   LIMIT 5;';
    RAISE NOTICE '';
END;
$$;

