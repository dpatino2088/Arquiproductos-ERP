-- ====================================================
-- UPDATE: Change MO.planned → SO."In Production"
-- ====================================================
-- This script updates the mapping so that:
-- - MO.planned → SO."In Production" (changed from "Confirmed")
-- - MO.completed → SO."Ready for Delivery" (unchanged)
-- - Delivered is manual from SalesOrders (unchanged)
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
Delivered is manual (changed from SalesOrders).
Returns NULL if no mapping exists (no change needed).';

-- ====================================================
-- STEP 2: Verification
-- ====================================================

DO $$
DECLARE
    v_function_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Status Mapping Updated';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Verify function exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'map_mo_status_to_so_status'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Function map_mo_status_to_so_status updated';
    ELSE
        RAISE WARNING '❌ Function map_mo_status_to_so_status does NOT exist';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 UPDATED STATUS MAPPING:';
    RAISE NOTICE '   MO.draft → SO."Scheduled for Production"';
    RAISE NOTICE '   MO.planned → SO."In Production" ✅ CHANGED';
    RAISE NOTICE '   MO.in_production → SO."In Production"';
    RAISE NOTICE '   MO.completed → SO."Ready for Delivery" ✅ MAINTAINED';
    RAISE NOTICE '   MO.cancelled → SO."Cancelled"';
    RAISE NOTICE '   Delivered → Manual (from SalesOrders) ✅ MAINTAINED';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST:';
    RAISE NOTICE '   SELECT public.map_mo_status_to_so_status(''planned'');';
    RAISE NOTICE '   Expected: "In Production"';
    RAISE NOTICE '';
    RAISE NOTICE '   SELECT public.map_mo_status_to_so_status(''completed'');';
    RAISE NOTICE '   Expected: "Ready for Delivery"';
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 3: Test the mapping function
-- ====================================================

DO $$
DECLARE
    v_result text;
BEGIN
    -- Test planned → In Production
    v_result := public.map_mo_status_to_so_status('planned');
    IF v_result = 'In Production' THEN
        RAISE NOTICE '✅ TEST PASSED: planned → "In Production"';
    ELSE
        RAISE WARNING '❌ TEST FAILED: planned → "%" (expected: "In Production")', v_result;
    END IF;
    
    -- Test completed → Ready for Delivery
    v_result := public.map_mo_status_to_so_status('completed');
    IF v_result = 'Ready for Delivery' THEN
        RAISE NOTICE '✅ TEST PASSED: completed → "Ready for Delivery"';
    ELSE
        RAISE WARNING '❌ TEST FAILED: completed → "%" (expected: "Ready for Delivery")', v_result;
    END IF;
    
    -- Test draft → Scheduled for Production
    v_result := public.map_mo_status_to_so_status('draft');
    IF v_result = 'Scheduled for Production' THEN
        RAISE NOTICE '✅ TEST PASSED: draft → "Scheduled for Production"';
    ELSE
        RAISE WARNING '❌ TEST FAILED: draft → "%" (expected: "Scheduled for Production")', v_result;
    END IF;
END;
$$;






