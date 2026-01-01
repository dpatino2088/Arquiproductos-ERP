-- ====================================================
-- Migration 378: Debug version of bom_readiness_report
-- ====================================================
-- Temporary debug version to understand why it returns empty array
-- ====================================================

CREATE OR REPLACE FUNCTION public.bom_readiness_report_debug(
    p_organization_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_result jsonb := '[]'::jsonb;
    v_product_type RECORD;
    v_product_type_count integer := 0;
    v_loop_iterations integer := 0;
    v_debug_info jsonb := jsonb_build_object();
BEGIN
    -- Debug: Count ProductTypes before loop
    SELECT COUNT(*) INTO v_product_type_count
    FROM "ProductTypes" pt
    WHERE pt.organization_id = p_organization_id
    AND pt.deleted = false;
    
    RAISE NOTICE 'DEBUG: Found % ProductTypes for organization_id %', v_product_type_count, p_organization_id;
    
    -- Build debug info
    v_debug_info := jsonb_build_object(
        'organization_id', p_organization_id,
        'product_types_found', v_product_type_count,
        'loop_iterations', 0,
        'result_length_before_loop', jsonb_array_length(v_result),
        'sample_product_type', NULL
    );
    
    -- Iterate through all ProductTypes for this organization
    FOR v_product_type IN
        SELECT pt.id, pt.name, pt.code
        FROM "ProductTypes" pt
        WHERE pt.organization_id = p_organization_id
        AND pt.deleted = false
        ORDER BY pt.sort_order NULLS LAST, pt.name
        LIMIT 1  -- Only process first one for debug
    LOOP
        v_loop_iterations := v_loop_iterations + 1;
        
        RAISE NOTICE 'DEBUG: Processing ProductType: id=%, name=%, code=%', 
            v_product_type.id, v_product_type.name, v_product_type.code;
        
        -- Update debug info with sample
        v_debug_info := v_debug_info || jsonb_build_object(
            'loop_iterations', v_loop_iterations,
            'sample_product_type', jsonb_build_object(
                'id', v_product_type.id,
                'name', v_product_type.name,
                'code', v_product_type.code
            )
        );
        
        -- For debug, just add a simple entry
        v_result := v_result || jsonb_build_object(
            'product_type_id', v_product_type.id,
            'product_type_name', v_product_type.name,
            'product_type_code', COALESCE(v_product_type.code, ''),
            'status', 'DEBUG_ENTRY'
        );
        
        RAISE NOTICE 'DEBUG: Added entry to result. Result length now: %', jsonb_array_length(v_result);
    END LOOP;
    
    RAISE NOTICE 'DEBUG: Loop completed. Total iterations: %, Final result length: %', 
        v_loop_iterations, jsonb_array_length(v_result);
    
    -- Return debug info as part of result
    RETURN jsonb_build_object(
        'debug_info', v_debug_info,
        'result', v_result,
        'result_length', jsonb_array_length(v_result)
    );
END;
$$;

COMMENT ON FUNCTION public.bom_readiness_report_debug(uuid) IS 
'Debug version of bom_readiness_report to diagnose why it returns empty array.';

