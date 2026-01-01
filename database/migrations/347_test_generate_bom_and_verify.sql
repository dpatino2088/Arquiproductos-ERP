-- ====================================================
-- Migration 347: Test generate_bom and verify creation
-- ====================================================
-- Executes the function and shows BEFORE/AFTER counts
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_result jsonb;
    v_bi_before integer;
    v_bi_after integer;
    v_bil_before integer;
    v_bil_after integer;
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
    
    -- Count BEFORE
    SELECT COUNT(DISTINCT bi.id) INTO v_bi_before
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = v_mo_id AND bi.deleted = false;
    
    SELECT COUNT(DISTINCT bil.id) INTO v_bil_before
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = v_mo_id AND bil.deleted = false;
    
    RAISE NOTICE '📊 BEFORE execution:';
    RAISE NOTICE '   BomInstances: %', v_bi_before;
    RAISE NOTICE '   BomInstanceLines: %', v_bil_before;
    RAISE NOTICE '';
    
    -- Execute function
    RAISE NOTICE '🚀 Executing generate_bom_for_manufacturing_order...';
    v_result := public.generate_bom_for_manufacturing_order(v_mo_id);
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Function Result:';
    RAISE NOTICE '   success: %', v_result->>'success';
    RAISE NOTICE '   bom_instances_created: %', v_result->>'bom_instances_created';
    RAISE NOTICE '   bom_instance_lines_created: %', v_result->>'bom_instance_lines_created';
    
    IF v_result->>'error' IS NOT NULL THEN
        RAISE NOTICE '   error: %', v_result->>'error';
    END IF;
    RAISE NOTICE '';
    
    -- Count AFTER
    SELECT COUNT(DISTINCT bi.id) INTO v_bi_after
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = v_mo_id AND bi.deleted = false;
    
    SELECT COUNT(DISTINCT bil.id) INTO v_bil_after
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = v_mo_id AND bil.deleted = false;
    
    RAISE NOTICE '📊 AFTER execution:';
    RAISE NOTICE '   BomInstances: %', v_bi_after;
    RAISE NOTICE '   BomInstanceLines: %', v_bil_after;
    RAISE NOTICE '';
    
    RAISE NOTICE '📈 CHANGES:';
    RAISE NOTICE '   BomInstances: % → % (delta: %)', v_bi_before, v_bi_after, (v_bi_after - v_bi_before);
    RAISE NOTICE '   BomInstanceLines: % → % (delta: %)', v_bil_before, v_bil_after, (v_bil_after - v_bil_before);
    
END $$;

-- Also show current state as a table
SELECT 
    'CURRENT_STATE' as check_type,
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


