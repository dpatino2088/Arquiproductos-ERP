-- ====================================================
-- Fix: Update trigger function to use correct table name "SalesOrders"
-- ====================================================
-- This script fixes the on_manufacturing_order_status_change function
-- to use "SalesOrders" (plural) instead of "SaleOrders" (singular)
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
    
    -- Get current SaleOrder status (FIXED: Use "SalesOrders" plural)
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
        -- FIXED: Use "SalesOrders" plural
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
'Syncs SalesOrders.status from ManufacturingOrders.status changes. Maps: planned→Confirmed, in_production→In Production, completed→Ready for Delivery, cancelled→Cancelled. Never overwrites Delivered status. Uses "SalesOrders" (plural) table name.';

-- Verify trigger exists and is active
DROP TRIGGER IF EXISTS trg_mo_status_sync_sale_order ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_status_sync_sale_order
    AFTER UPDATE OF status ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_status_change();

COMMENT ON TRIGGER trg_mo_status_sync_sale_order ON "ManufacturingOrders" IS 
'Automatically updates SalesOrders.status when ManufacturingOrders.status changes. Never overwrites Delivered status.';

-- Verify the function was updated
DO $$
BEGIN
    RAISE NOTICE '✅ Function on_manufacturing_order_status_change updated to use "SalesOrders" (plural)';
    RAISE NOTICE '✅ Trigger trg_mo_status_sync_sale_order created/updated';
END;
$$;






