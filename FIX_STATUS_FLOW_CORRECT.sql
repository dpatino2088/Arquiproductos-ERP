-- ====================================================
-- FIX: Correct Status Flow Logic
-- ====================================================
-- FLUJO CORRECTO:
-- 1. MO creado con status='draft' → SO.status = 'Confirmed' (NO cambia)
-- 2. MO.status cambia a 'planned' → SO.status = 'Scheduled for Production'
-- 3. MO.status cambia a 'in_production' → SO.status = 'In Production'
-- 4. MO.status cambia a 'completed' → SO.status = 'Ready for Delivery'
-- 5. SO.status = 'Delivered' es MANUAL (desde SalesOrders)
-- ====================================================

-- ====================================================
-- STEP 1: Update map_mo_status_to_so_status function
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
            RETURN 'Scheduled for Production';
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
'Maps ManufacturingOrders.status to SaleOrders.status.
Maps: planned→Scheduled for Production, in_production→In Production, completed→Ready for Delivery, cancelled→Cancelled.
Returns NULL for draft (no change - SO stays as Confirmed).';

-- ====================================================
-- STEP 2: Fix on_manufacturing_order_insert_generate_bom
-- ====================================================
-- NO debe cambiar SO status cuando MO es creado con draft
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
    -- ====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔔 TRIGGER FIRED: on_manufacturing_order_insert_generate_bom';
    RAISE NOTICE '   MO ID: %', NEW.id;
    RAISE NOTICE '   MO Number: %', COALESCE(NEW.manufacturing_order_no, 'NULL');
    RAISE NOTICE '   MO Status: %', NEW.status;
    RAISE NOTICE '   SO ID: %', NEW.sale_order_id;
    RAISE NOTICE '====================================================';
    
    -- Get SalesOrder record (for verification only)
    SELECT * INTO v_sales_order_record
    FROM "SalesOrders"
    WHERE id = NEW.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ SalesOrder % not found for ManufacturingOrder %', NEW.sale_order_id, NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '📋 SalesOrder Found: % (Status: %)', v_sales_order_record.sale_order_no, v_sales_order_record.status;
    
    -- ====================================================
    -- IMPORTANT: NO cambiamos SO.status cuando MO es creado con 'draft'
    -- SO.status se mantiene como está (usualmente 'Confirmed')
    -- Solo se actualizará cuando MO.status cambie a 'planned', 'in_production', etc.
    -- ====================================================
    
    IF LOWER(TRIM(COALESCE(NEW.status, ''))) = 'draft' THEN
        RAISE NOTICE '⏭️  MO status is ''draft'' → NO cambiar SO.status (mantiene: %)', v_sales_order_record.status;
    ELSE
        -- Si por alguna razón MO se crea con otro status, usar mapeo
        DECLARE
            v_mapped_status text;
        BEGIN
            v_mapped_status := public.map_mo_status_to_so_status(NEW.status);
            
            IF v_mapped_status IS NOT NULL AND v_mapped_status <> v_sales_order_record.status AND v_sales_order_record.status <> 'Delivered' THEN
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
        RAISE WARNING '   MO ID: %, SO ID: %', NEW.id, NEW.sale_order_id;
        -- Don't block MO creation
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Trigger fired when ManufacturingOrder is created.
BEHAVIOR:
- If MO status = draft → NO cambia SO.status (mantiene su estado actual, usualmente "Confirmed")
- SO.status solo cambia cuando MO.status se actualiza (via on_manufacturing_order_status_change)
- Does NOT modify ManufacturingOrder.status';

-- ====================================================
-- STEP 3: Update on_manufacturing_order_status_change
-- ====================================================
-- Este trigger maneja los cambios de status cuando MO se actualiza
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
    v_updated_rows integer;
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
        
        GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
        
        IF v_updated_rows > 0 THEN
            RAISE NOTICE '✅ Updated SaleOrder % status from "%" to "%" (triggered by ManufacturingOrder % status: %)', 
                v_sale_order_id, v_current_so_status, v_mapped_status, COALESCE(NEW.id, OLD.id), NEW.status;
        ELSE
            RAISE WARNING '⚠️ No rows updated for SaleOrder %', v_sale_order_id;
        END IF;
    ELSE
        IF v_mapped_status IS NULL THEN
            RAISE NOTICE '⏭️  MO status "%" does not map to SO status (no change)', NEW.status;
        ELSE
            RAISE NOTICE '⏭️  SO status already "%" (no change needed)', v_current_so_status;
        END IF;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_status_change IS 
'Syncs SalesOrders.status from ManufacturingOrders.status changes.
Maps: planned→Scheduled for Production, in_production→In Production, completed→Ready for Delivery, cancelled→Cancelled.
Draft does NOT change SO status (returns NULL from map function).
Never overwrites Delivered status.';

-- ====================================================
-- STEP 4: Fix CHECK constraint to include all valid statuses
-- ====================================================

-- Drop existing constraints (both possible names - singular and plural)
ALTER TABLE "SalesOrders" 
DROP CONSTRAINT IF EXISTS "SalesOrders_status_check";

ALTER TABLE "SalesOrders" 
DROP CONSTRAINT IF EXISTS "SaleOrders_status_check";

-- Add correct CHECK constraint with ALL valid statuses
ALTER TABLE "SalesOrders"
ADD CONSTRAINT "SalesOrders_status_check" 
CHECK (status IN (
    'Draft',
    'Confirmed', 
    'Scheduled for Production',
    'In Production', 
    'Ready for Delivery',
    'Delivered',
    'Cancelled'
));

-- ====================================================
-- STEP 5: Ensure triggers exist and are active
-- ====================================================

-- Trigger for INSERT
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Trigger fired when ManufacturingOrder is created. Does NOT change SO status if MO is draft.';

-- Trigger for UPDATE
DROP TRIGGER IF EXISTS trg_mo_status_sync_sale_order ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_status_sync_sale_order
    AFTER UPDATE OF status ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.on_manufacturing_order_status_change();

COMMENT ON TRIGGER trg_mo_status_sync_sale_order ON "ManufacturingOrders" IS 
'Automatically updates SalesOrders.status when ManufacturingOrders.status changes. Never overwrites Delivered status.';

-- ====================================================
-- STEP 5: Verification
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FLUJO CORREGIDO';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 FLUJO DE STATUS:';
    RAISE NOTICE '';
    RAISE NOTICE '1. MO creado (draft) → SO.status NO cambia (mantiene Confirmed)';
    RAISE NOTICE '2. MO.status = planned → SO.status = "Scheduled for Production"';
    RAISE NOTICE '3. MO.status = in_production → SO.status = "In Production"';
    RAISE NOTICE '4. MO.status = completed → SO.status = "Ready for Delivery"';
    RAISE NOTICE '5. SO.status = "Delivered" es MANUAL (desde SalesOrders)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Triggers configurados correctamente';
    RAISE NOTICE '✅ CHECK constraint actualizado con todos los status válidos';
    RAISE NOTICE '';
END;
$$;

