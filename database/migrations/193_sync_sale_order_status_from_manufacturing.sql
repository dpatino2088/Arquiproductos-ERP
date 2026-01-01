-- ====================================================
-- Migration: Sync SaleOrders.status from ManufacturingOrders.status
-- ====================================================
-- This migration:
-- 1. Updates SaleOrders.status CHECK constraint to use customer-facing values
-- 2. Migrates existing status values to new format
-- 3. Creates mapping function from ManufacturingOrders.status to SaleOrders.status
-- 4. Creates trigger to automatically sync SaleOrders.status when ManufacturingOrders.status changes
-- ====================================================

-- ====================================================
-- STEP 1: Update SaleOrders.status CHECK constraint
-- ====================================================
-- Change from: 'draft', 'confirmed', 'in_production', 'shipped', 'delivered', 'cancelled'
-- Change to: 'Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled'

-- First, drop the old constraint
ALTER TABLE "SalesOrders" 
DROP CONSTRAINT IF EXISTS "SaleOrders_status_check";

-- Migrate existing data to new format
UPDATE "SalesOrders"
SET status = CASE
    WHEN status = 'draft' THEN 'Draft'
    WHEN status = 'confirmed' THEN 'Confirmed'
    WHEN status = 'in_production' THEN 'In Production'
    WHEN status = 'shipped' THEN 'Ready for Delivery'
    WHEN status = 'delivered' THEN 'Delivered'
    WHEN status = 'cancelled' THEN 'Cancelled'
    ELSE 'Draft' -- Default fallback
END
WHERE status IN ('draft', 'confirmed', 'in_production', 'shipped', 'delivered', 'cancelled');

-- Add new CHECK constraint with customer-facing values
ALTER TABLE "SalesOrders"
ADD CONSTRAINT "SaleOrders_status_check" 
CHECK (status IN ('Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled'));

-- Update default value
ALTER TABLE "SalesOrders"
ALTER COLUMN status SET DEFAULT 'Draft';

-- ====================================================
-- STEP 2: Create helper function to map MO status to SO status
-- ====================================================

CREATE OR REPLACE FUNCTION public.map_mo_status_to_so_status(mo_status text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Map ManufacturingOrders.status to SaleOrders.status
    CASE mo_status
        WHEN 'planned' THEN
            RETURN 'Confirmed';
        WHEN 'in_production' THEN
            RETURN 'In Production';
        WHEN 'completed' THEN
            RETURN 'Ready for Delivery';
        WHEN 'cancelled' THEN
            RETURN 'Cancelled';
        ELSE
            -- For 'draft' or unknown statuses, return NULL (no change)
            RETURN NULL;
    END CASE;
END;
$$;

COMMENT ON FUNCTION public.map_mo_status_to_so_status IS 
'Maps ManufacturingOrders.status to SaleOrders.status. Returns NULL if no mapping exists (no change needed).';

-- ====================================================
-- STEP 3: Create trigger function to sync SaleOrders.status
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
'Syncs SaleOrders.status from ManufacturingOrders.status changes. Maps: planned→Confirmed, in_production→In Production, completed→Ready for Delivery, cancelled→Cancelled. Never overwrites Delivered status.';

-- ====================================================
-- STEP 4: Create trigger on ManufacturingOrders
-- ====================================================

-- Drop existing trigger if it exists (idempotent)
DROP TRIGGER IF EXISTS trg_mo_status_sync_sale_order ON "ManufacturingOrders";

-- Create trigger
CREATE TRIGGER trg_mo_status_sync_sale_order
    AFTER UPDATE OF status ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION public.on_manufacturing_order_status_change();

COMMENT ON TRIGGER trg_mo_status_sync_sale_order ON "ManufacturingOrders" IS 
'Automatically updates SaleOrders.status when ManufacturingOrders.status changes. Never overwrites Delivered status.';

-- ====================================================
-- STEP 5: Verification queries (commented out)
-- ====================================================

/*
-- Verify CHECK constraint exists
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = (SELECT oid FROM pg_class WHERE relname = 'SalesOrders')
AND conname = 'SaleOrders_status_check';

-- Show status distribution
SELECT 
    status,
    COUNT(*) AS count
FROM "SalesOrders"
WHERE deleted = false
GROUP BY status
ORDER BY count DESC;

-- Verify function exists
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('map_mo_status_to_so_status', 'on_manufacturing_order_status_change');

-- Verify trigger exists
SELECT
    tgname AS trigger_name,
    relname AS table_name,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE LOWER(c.relname) = LOWER('ManufacturingOrders')
AND tgname = 'trg_mo_status_sync_sale_order';

-- Test mapping function
SELECT 
    'planned' AS mo_status,
    public.map_mo_status_to_so_status('planned') AS so_status
UNION ALL
SELECT 'in_production', public.map_mo_status_to_so_status('in_production')
UNION ALL
SELECT 'completed', public.map_mo_status_to_so_status('completed')
UNION ALL
SELECT 'cancelled', public.map_mo_status_to_so_status('cancelled')
UNION ALL
SELECT 'draft', public.map_mo_status_to_so_status('draft');
*/

