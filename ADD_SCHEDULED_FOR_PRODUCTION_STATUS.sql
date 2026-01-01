-- ====================================================
-- ADD "Scheduled for Production" Status to SalesOrders
-- ====================================================
-- This script:
-- 1. Adds "Scheduled for Production" to SalesOrders.status CHECK constraint
-- 2. Updates map_mo_status_to_so_status to map MO.draft → SO."Scheduled for Production"
-- 3. Updates trigger to set "Scheduled for Production" when MO = Draft
-- 4. Ensures QuoteApproved shows "Scheduled for Production" when MO = Draft
-- ====================================================

-- ====================================================
-- STEP 1: Add "Scheduled for Production" to CHECK constraint
-- ====================================================

DO $$
BEGIN
    -- Drop existing constraint
    ALTER TABLE "SalesOrders" 
    DROP CONSTRAINT IF EXISTS "SalesOrders_status_check";
    
    -- Add new CHECK constraint with "Scheduled for Production"
    ALTER TABLE "SalesOrders"
    ADD CONSTRAINT "SalesOrders_status_check" 
    CHECK (status IN ('Draft', 'Confirmed', 'Scheduled for Production', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled'));
    
    RAISE NOTICE '✅ Added "Scheduled for Production" to SalesOrders.status CHECK constraint';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '⚠️ Error updating CHECK constraint: %', SQLERRM;
END;
$$;

-- ====================================================
-- STEP 2: Update map_mo_status_to_so_status function
-- ====================================================
-- Map MO.draft → SO."Scheduled for Production"
-- ====================================================

CREATE OR REPLACE FUNCTION public.map_mo_status_to_so_status(mo_status text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Map ManufacturingOrders.status to SaleOrders.status
    CASE mo_status
        WHEN 'draft' THEN
            RETURN 'Scheduled for Production';
        WHEN 'planned' THEN
            RETURN 'In Production';
        WHEN 'in_production' THEN
            RETURN 'In Production';
        WHEN 'completed' THEN
            RETURN 'Ready for Delivery';
        WHEN 'cancelled' THEN
            RETURN 'Cancelled';
        ELSE
            -- For unknown statuses, return NULL (no change)
            RETURN NULL;
    END CASE;
END;
$$;

COMMENT ON FUNCTION public.map_mo_status_to_so_status IS 
'Maps ManufacturingOrders.status to SaleOrders.status.
Maps: draft→Scheduled for Production, planned→In Production, in_production→In Production, completed→Ready for Delivery, cancelled→Cancelled.
Returns NULL if no mapping exists (no change needed).';

-- ====================================================
-- STEP 3: Update on_manufacturing_order_insert_generate_bom
-- ====================================================
-- When MO is created with status = 'draft', set SO status to "Scheduled for Production"
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_bom_lines_count integer;
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
    
    -- ====================================================
    -- CRITICAL: Update SalesOrder status based on MO status
    -- ====================================================
    -- If MO status = 'draft' → SO status = 'Scheduled for Production'
    -- If MO status = 'planned' → SO status = 'In Production' (via map function)
    -- If MO status = 'in_production' → SO status = 'In Production'
    -- If MO status = 'completed' → SO status = 'Ready for Delivery'
    -- ====================================================
    
    IF NEW.status = 'draft' THEN
        -- MO is Draft → SO should be "Scheduled for Production"
        UPDATE "SalesOrders"
        SET status = 'Scheduled for Production',
            updated_at = now()
        WHERE id = NEW.sale_order_id
        AND deleted = false
        AND status <> 'Delivered';
        
        RAISE NOTICE '✅ SalesOrder status updated to "Scheduled for Production" (MO is Draft)';
    ELSE
        -- For other MO statuses, use the mapping function
        DECLARE
            v_mapped_status text;
        BEGIN
            v_mapped_status := public.map_mo_status_to_so_status(NEW.status);
            
            IF v_mapped_status IS NOT NULL THEN
                UPDATE "SalesOrders"
                SET status = v_mapped_status,
                    updated_at = now()
                WHERE id = NEW.sale_order_id
                AND deleted = false
                AND status <> 'Delivered';
                
                RAISE NOTICE '✅ SalesOrder status updated to "%" (MO status: %)', v_mapped_status, NEW.status;
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
        -- Don't block MO creation
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Links ManufacturingOrder to SalesOrder when MO is created.
BEHAVIOR:
- If MO status = draft → Updates SalesOrder status to "Scheduled for Production"
- If MO status = planned → Updates SalesOrder status to "In Production"
- If MO status = in_production → Updates SalesOrder status to "In Production"
- If MO status = completed → Updates SalesOrder status to "Ready for Delivery"
- DOES NOT modify ManufacturingOrder.status (must remain DRAFT)
- Only generate_bom_for_manufacturing_order can change MO status to PLANNED
- Architecture: BOM must be generated manually via RPC call';

-- ====================================================
-- STEP 3.1: Ensure trigger exists and is active
-- ====================================================

DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Updates SalesOrder status to "Scheduled for Production" when ManufacturingOrder is created with status=draft. Does not modify MO status.';

-- ====================================================
-- STEP 4: Update on_manufacturing_order_status_change
-- ====================================================
-- Ensure it handles the new status mapping correctly
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_mapped_status text;
    v_current_so_status text;
BEGIN
    -- Only process if status actually changed
    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;
    
    -- Get sale_order_id from ManufacturingOrder
    v_sale_order_id := COALESCE(NEW.sale_order_id, OLD.sale_order_id);
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get current SaleOrder status
    SELECT status INTO v_current_so_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Rule 1: Never overwrite 'Delivered'
    IF v_current_so_status = 'Delivered' THEN
        RAISE NOTICE '⏭️  SaleOrder % status is "Delivered", skipping automatic update from ManufacturingOrder %', 
            v_sale_order_id, COALESCE(NEW.id, OLD.id);
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Map ManufacturingOrder status to SaleOrder status
    v_mapped_status := public.map_mo_status_to_so_status(NEW.status);
    
    -- Only update if mapping exists and status would change
    IF v_mapped_status IS NOT NULL AND v_mapped_status IS DISTINCT FROM v_current_so_status THEN
        UPDATE "SalesOrders"
        SET status = v_mapped_status,
            updated_at = now()
        WHERE id = v_sale_order_id
        AND deleted = false
        AND status <> 'Delivered'; -- Extra safety check
        
        RAISE NOTICE '✅ Updated SaleOrder % status from "%" to "%" (triggered by ManufacturingOrder % status: %)', 
            v_sale_order_id, v_current_so_status, v_mapped_status, COALESCE(NEW.id, OLD.id), NEW.status;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_status_change IS 
'Syncs SalesOrders.status from ManufacturingOrders.status changes. 
Maps: draft→Scheduled for Production, planned→In Production, in_production→In Production, completed→Ready for Delivery, cancelled→Cancelled. 
Never overwrites Delivered status. Uses "SalesOrders" (plural) table name.';

-- ====================================================
-- STEP 5: Verification
-- ====================================================

DO $$
DECLARE
    v_constraint_exists boolean;
    v_function_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ "Scheduled for Production" Status Added';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Verify constraint
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
        WHERE tc.table_name = 'SalesOrders'
        AND tc.constraint_name = 'SalesOrders_status_check'
        AND cc.check_clause LIKE '%Scheduled for Production%'
    ) INTO v_constraint_exists;
    
    IF v_constraint_exists THEN
        RAISE NOTICE '✅ CHECK constraint includes "Scheduled for Production"';
    ELSE
        RAISE WARNING '⚠️ CHECK constraint may not include "Scheduled for Production"';
    END IF;
    
    -- Verify function
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'map_mo_status_to_so_status'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ map_mo_status_to_so_status function updated';
    ELSE
        RAISE WARNING '⚠️ map_mo_status_to_so_status function may not exist';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 STATUS MAPPING:';
    RAISE NOTICE '   MO.draft → SO."Scheduled for Production"';
    RAISE NOTICE '   MO.planned → SO."In Production"';
    RAISE NOTICE '   MO.in_production → SO."In Production"';
    RAISE NOTICE '   MO.completed → SO."Ready for Delivery"';
    RAISE NOTICE '   MO.cancelled → SO."Cancelled"';
    RAISE NOTICE '   Delivered → Manual (from SalesOrders)';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 BEHAVIOR:';
    RAISE NOTICE '   ✅ When MO created with status=draft → SO status="Scheduled for Production"';
    RAISE NOTICE '   ✅ When MO status changes → SO status updates automatically';
    RAISE NOTICE '   ✅ Manual changes restricted: Only Draft→Confirmed and Ready for Delivery→Delivered';
    RAISE NOTICE '';
END;
$$;

