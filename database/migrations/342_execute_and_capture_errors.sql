-- ====================================================
-- Migration 342: Execute generate_bom and capture any errors
-- ====================================================
-- This script executes the function and shows detailed error information
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_result jsonb;
    v_error_detail text;
    v_error_hint text;
    v_error_context text;
BEGIN
    -- Get MO-000003
    SELECT id INTO v_mo_id
    FROM "ManufacturingOrders"
    WHERE manufacturing_order_no = 'MO-000003'
    AND deleted = false
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE EXCEPTION 'MO-000003 not found';
    END IF;
    
    RAISE NOTICE '🚀 Executing generate_bom_for_manufacturing_order for MO-000003';
    RAISE NOTICE '   MO ID: %', v_mo_id;
    
    -- Execute function with detailed error handling
    BEGIN
        v_result := public.generate_bom_for_manufacturing_order(v_mo_id);
        
        -- Check if function returned success
        IF (v_result->>'success')::boolean = false THEN
            RAISE WARNING 'Function returned success=false';
            RAISE WARNING 'Error message: %', v_result->>'error';
        ELSE
            RAISE NOTICE '✅ Function executed with success=true';
            RAISE NOTICE '   bom_instances_created: %', v_result->>'bom_instances_created';
            RAISE NOTICE '   bom_instance_lines_created: %', v_result->>'bom_instance_lines_created';
            RAISE NOTICE '   bom_instances_processed: %', v_result->>'bom_instances_processed';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS 
                v_error_detail = PG_EXCEPTION_DETAIL,
                v_error_hint = PG_EXCEPTION_HINT,
                v_error_context = PG_EXCEPTION_CONTEXT;
            
            RAISE WARNING '❌ EXCEPTION caught in DO block:';
            RAISE WARNING '   SQLSTATE: %', SQLSTATE;
            RAISE WARNING '   SQLERRM: %', SQLERRM;
            RAISE WARNING '   DETAIL: %', v_error_detail;
            RAISE WARNING '   HINT: %', v_error_hint;
            RAISE WARNING '   CONTEXT: %', v_error_context;
    END;
    
END $$;

-- Also check if function exists and get its definition
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'generate_bom_for_manufacturing_order'
LIMIT 1;


