-- ====================================================
-- Migration: Create trigger to sync OrderList.tracking_status
-- ====================================================
-- OBJETIVO: OrderList.tracking_status SIEMPRE espejo de SalesOrders.tracking_status
-- ====================================================

BEGIN;

-- Function to sync OrderList.tracking_status when SalesOrder changes
CREATE OR REPLACE FUNCTION public.sync_order_list_tracking_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update OrderList.tracking_status to match SalesOrder
    UPDATE public."OrderList"
    SET 
        tracking_status = NEW.tracking_status,
        updated_at = now()
    WHERE sales_order_id = NEW.id
    AND deleted = false;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trg_sync_order_list_tracking ON public."SalesOrders";
CREATE TRIGGER trg_sync_order_list_tracking
    AFTER UPDATE OF tracking_status ON public."SalesOrders"
    FOR EACH ROW
    WHEN (OLD.tracking_status IS DISTINCT FROM NEW.tracking_status)
    EXECUTE FUNCTION public.sync_order_list_tracking_status();

-- Add comment
COMMENT ON FUNCTION public.sync_order_list_tracking_status() IS 
    'Trigger function: Syncs OrderList.tracking_status to match SalesOrders.tracking_status (mirror).';

COMMENT ON TRIGGER trg_sync_order_list_tracking ON public."SalesOrders" IS 
    'Trigger: Automatically syncs OrderList.tracking_status when SalesOrder.tracking_status changes.';

COMMIT;
