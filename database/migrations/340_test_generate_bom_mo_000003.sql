-- ====================================================
-- Migration 340: Test generate_bom_for_manufacturing_order for MO-000003
-- ====================================================
-- Quick test script to run the function and see the result
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_result jsonb;
BEGIN
    -- Get MO-000003
    SELECT id INTO v_mo_id
    FROM "ManufacturingOrders"
    WHERE manufacturing_order_no = 'MO-000003'
    AND deleted = false
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE NOTICE '❌ MO-000003 not found';
        RETURN;
    END IF;
    
    RAISE NOTICE '🔧 Testing generate_bom_for_manufacturing_order for MO-000003 (ID: %)', v_mo_id;
    RAISE NOTICE '';
    
    -- Execute function
    v_result := public.generate_bom_for_manufacturing_order(v_mo_id);
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Function Result:';
    RAISE NOTICE '   success: %', v_result->>'success';
    RAISE NOTICE '   bom_instances_created: %', v_result->>'bom_instances_created';
    RAISE NOTICE '   bom_instance_lines_created: %', v_result->>'bom_instance_lines_created';
    RAISE NOTICE '   bom_instances_processed: %', v_result->>'bom_instances_processed';
    
    IF v_result->>'error' IS NOT NULL THEN
        RAISE NOTICE '   error: %', v_result->>'error';
    END IF;
    
END $$;

-- Also show current state
SELECT 
    mo.manufacturing_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_instance_lines
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no;


