-- ====================================================
-- FIX: Draft Status Not Updating SO Status
-- ====================================================
-- This script ensures the trigger correctly updates SO status
-- when MO is created with status='draft'
-- ====================================================

-- ====================================================
-- STEP 1: Verify CHECK constraint allows "Scheduled for Production"
-- ====================================================

DO $$
DECLARE
    v_constraint_exists boolean;
    v_allows_scheduled boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔍 Checking CHECK constraint...';
    RAISE NOTICE '====================================================';
    
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
        WHERE tc.table_name = 'SalesOrders'
        AND tc.constraint_name = 'SalesOrders_status_check'
    ) INTO v_constraint_exists;
    
    IF v_constraint_exists THEN
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.check_constraints
            WHERE constraint_name = 'SalesOrders_status_check'
            AND check_clause LIKE '%Scheduled for Production%'
        ) INTO v_allows_scheduled;
        
        IF v_allows_scheduled THEN
            RAISE NOTICE '✅ CHECK constraint allows "Scheduled for Production"';
        ELSE
            RAISE WARNING '⚠️ CHECK constraint may NOT allow "Scheduled for Production"';
            RAISE NOTICE '   Updating CHECK constraint...';
            
            -- Drop and recreate constraint
            ALTER TABLE "SalesOrders" 
            DROP CONSTRAINT IF EXISTS "SalesOrders_status_check";
            
            ALTER TABLE "SalesOrders"
            ADD CONSTRAINT "SalesOrders_status_check" 
            CHECK (status IN ('Draft', 'Confirmed', 'Scheduled for Production', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled'));
            
            RAISE NOTICE '✅ CHECK constraint updated';
        END IF;
    ELSE
        RAISE WARNING '⚠️ CHECK constraint does not exist - creating it...';
        ALTER TABLE "SalesOrders"
        ADD CONSTRAINT "SalesOrders_status_check" 
        CHECK (status IN ('Draft', 'Confirmed', 'Scheduled for Production', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled'));
        RAISE NOTICE '✅ CHECK constraint created';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: Recreate function with explicit status update
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
    RAISE NOTICE '   MO Number: %', COALESCE(NEW.manufacturing_order_no, 'NULL');
    RAISE NOTICE '   MO Status: %', NEW.status;
    RAISE NOTICE '   SO ID: %', NEW.sale_order_id;
    RAISE NOTICE '====================================================';
    
    -- Validate MO status is not null
    IF NEW.status IS NULL THEN
        RAISE WARNING '⚠️ MO status is NULL, cannot update SO status';
        RETURN NEW;
    END IF;
    
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
    -- Use LOWER() to ensure case-insensitive comparison
    -- ====================================================
    
    IF LOWER(TRIM(NEW.status)) = 'draft' THEN
        RAISE NOTICE '🔧 MO status is ''draft'' → Updating SO to "Scheduled for Production"';
        
        -- Only update if current status is not already "Scheduled for Production" or "Delivered"
        IF v_current_so_status <> 'Scheduled for Production' AND v_current_so_status <> 'Delivered' THEN
            UPDATE "SalesOrders"
            SET status = 'Scheduled for Production',
                updated_at = now()
            WHERE id = NEW.sale_order_id
            AND deleted = false
            AND status <> 'Delivered';
            
            GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
            
            IF v_updated_rows > 0 THEN
                RAISE NOTICE '✅ SUCCESS: SalesOrder status updated from "%" to "Scheduled for Production"', v_current_so_status;
                
                -- Verify the update
                SELECT status INTO v_current_so_status
                FROM "SalesOrders"
                WHERE id = NEW.sale_order_id;
                
                RAISE NOTICE '✅ VERIFIED: SalesOrder status is now "%"', v_current_so_status;
            ELSE
                RAISE WARNING '⚠️ WARNING: No rows updated. Possible reasons:';
                RAISE WARNING '   - SO status is "Delivered" (cannot be changed)';
                RAISE WARNING '   - SO is deleted';
                RAISE WARNING '   - SO ID mismatch';
                RAISE WARNING '   - CHECK constraint violation';
            END IF;
        ELSE
            RAISE NOTICE '⏭️  SO status is already "%", no update needed', v_current_so_status;
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
    RAISE NOTICE '✅ Trigger completed for ManufacturingOrder %', COALESCE(NEW.manufacturing_order_no, NEW.id::text);
    RAISE NOTICE '';
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ ERROR in trigger: %', SQLERRM;
        RAISE WARNING '   SQLSTATE: %', SQLSTATE;
        RAISE WARNING '   MO ID: %, SO ID: %, MO Status: %', NEW.id, NEW.sale_order_id, NEW.status;
        RAISE WARNING '   Current SO Status: %', v_current_so_status;
        -- Don't block MO creation
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Updates SalesOrder status when ManufacturingOrder is created.
If MO status = draft → SO status = "Scheduled for Production"
Other statuses use map_mo_status_to_so_status function.
Uses case-insensitive comparison for MO status.';

-- ====================================================
-- STEP 3: Ensure trigger exists and is ENABLED
-- ====================================================

DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Updates SalesOrder status to "Scheduled for Production" when ManufacturingOrder is created with status=draft.';

-- ====================================================
-- STEP 4: Final verification
-- ====================================================

DO $$
DECLARE
    v_trigger_count integer;
    v_function_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FINAL VERIFICATION';
    RAISE NOTICE '====================================================';
    
    -- Check trigger
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
    
    -- Check function
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines
    WHERE routine_schema = 'public'
    AND routine_name = 'on_manufacturing_order_insert_generate_bom';
    
    IF v_function_count > 0 THEN
        RAISE NOTICE '✅ Function on_manufacturing_order_insert_generate_bom exists';
    ELSE
        RAISE WARNING '❌ Function does NOT exist';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST: Create a new MO with status=draft';
    RAISE NOTICE '   Expected: SO status should change to "Scheduled for Production"';
    RAISE NOTICE '   Check logs (RAISE NOTICE) for detailed execution info';
    RAISE NOTICE '';
END;
$$;






