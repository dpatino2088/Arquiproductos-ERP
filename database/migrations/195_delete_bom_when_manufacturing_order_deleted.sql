-- ====================================================
-- Migration: Delete BOM when ManufacturingOrder is deleted
-- ====================================================
-- This migration:
-- 1. Creates trigger function to soft-delete BomInstances and BomInstanceLines
--    when a ManufacturingOrder is deleted
-- 2. The relationship is: ManufacturingOrder -> SaleOrder -> SaleOrderLines -> BomInstances
-- ====================================================

-- ====================================================
-- STEP 1: Create function to delete BOM when ManufacturingOrder is deleted
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_deleted_delete_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_bom_instance_ids uuid[];
    v_deleted_bom_instances_count integer;
    v_deleted_bom_lines_count integer;
BEGIN
    -- Get sale_order_id from the deleted ManufacturingOrder
    v_sale_order_id := OLD.sale_order_id;
    
    IF v_sale_order_id IS NULL THEN
        RETURN OLD;
    END IF;
    
    RAISE NOTICE '🔔 ManufacturingOrder % deleted, cleaning up BOM for SaleOrder %', OLD.id, v_sale_order_id;
    
    -- Get all BomInstance IDs related to this SaleOrder (through SaleOrderLines)
    SELECT ARRAY_AGG(bi.id) INTO v_bom_instance_ids
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
    AND bi.deleted = false;
    
    IF v_bom_instance_ids IS NULL OR array_length(v_bom_instance_ids, 1) = 0 THEN
        RAISE NOTICE '⏭️  No BomInstances found for SaleOrder %, nothing to delete', v_sale_order_id;
        RETURN OLD;
    END IF;
    
    -- Soft delete BomInstanceLines first (child records)
    UPDATE "BomInstanceLines"
    SET deleted = true,
        updated_at = now()
    WHERE bom_instance_id = ANY(v_bom_instance_ids)
    AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_bom_lines_count = ROW_COUNT;
    
    -- Soft delete BomInstances
    UPDATE "BomInstances"
    SET deleted = true,
        updated_at = now()
    WHERE id = ANY(v_bom_instance_ids)
    AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_bom_instances_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Deleted % BomInstances and % BomInstanceLines for SaleOrder %', 
        v_deleted_bom_instances_count, v_deleted_bom_lines_count, v_sale_order_id;
    
    RETURN OLD;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_deleted_delete_bom for ManufacturingOrder %: %', OLD.id, SQLERRM;
        RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_deleted_delete_bom IS 
'Soft-deletes BomInstances and BomInstanceLines when a ManufacturingOrder is deleted. The relationship is: ManufacturingOrder -> SaleOrder -> SaleOrderLines -> BomInstances.';

-- ====================================================
-- STEP 2: Create trigger on ManufacturingOrders
-- ====================================================

DROP TRIGGER IF EXISTS trg_manufacturing_order_deleted_delete_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_manufacturing_order_deleted_delete_bom
    AFTER UPDATE OF deleted ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = true AND OLD.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_deleted_delete_bom();

COMMENT ON TRIGGER trg_manufacturing_order_deleted_delete_bom ON "ManufacturingOrders" IS 
'Automatically soft-deletes related BomInstances and BomInstanceLines when a ManufacturingOrder is soft-deleted.';

-- ====================================================
-- STEP 3: Verification queries (commented out)
-- ====================================================

/*
-- Verify function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'on_manufacturing_order_deleted_delete_bom';

-- Verify trigger exists
SELECT tgname, relname, pg_get_triggerdef(oid)
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'ManufacturingOrders'
AND tgname = 'trg_manufacturing_order_deleted_delete_bom';

-- Test: Soft delete a ManufacturingOrder and check if BOM is deleted
-- SELECT id, manufacturing_order_no, sale_order_id FROM "ManufacturingOrders" WHERE deleted = false LIMIT 1;
-- UPDATE "ManufacturingOrders" SET deleted = true WHERE id = '<manufacturing_order_id>';
-- SELECT id, deleted FROM "BomInstances" WHERE id IN (SELECT bom_instance_id FROM ...);
-- SELECT id, deleted FROM "BomInstanceLines" WHERE bom_instance_id IN (...);
*/




