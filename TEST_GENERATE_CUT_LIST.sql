-- ====================================================
-- TEST: generate_cut_list_for_manufacturing_order
-- ====================================================
-- STEP 1: First, find a valid MO ID using FIND_MO_FOR_CUT_LIST_TEST.sql
-- STEP 2: Replace 'YOUR_MO_ID_HERE' below with the actual UUID from step 1
-- STEP 3: Run this script
-- ====================================================

-- ====================================================
-- OPTION 1: Test with a specific MO ID (replace with actual UUID)
-- ====================================================
-- Uncomment and replace 'YOUR_MO_ID_HERE' with actual UUID:
/*
SELECT public.generate_cut_list_for_manufacturing_order('YOUR_MO_ID_HERE');
*/

-- ====================================================
-- OPTION 2: Test with the first available MO (status = 'planned')
-- ====================================================
-- This will automatically find and test the first MO with status = 'planned'
DO $$
DECLARE
    v_mo_id uuid;
    v_mo_no text;
BEGIN
    -- Find first MO with status = 'planned' and BOM lines
    SELECT mo.id, mo.manufacturing_order_no
    INTO v_mo_id, v_mo_no
    FROM "ManufacturingOrders" mo
    INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
    LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
    LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
    WHERE mo.status = 'planned'
    AND mo.deleted = false
    GROUP BY mo.id, mo.manufacturing_order_no
    HAVING COUNT(DISTINCT bil.id) > 0
    ORDER BY mo.created_at DESC
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE NOTICE '❌ No ManufacturingOrder found with status = ''planned'' and BOM lines.';
        RAISE NOTICE '   Please ensure:';
        RAISE NOTICE '   1. A ManufacturingOrder exists with status = ''planned''';
        RAISE NOTICE '   2. The MO has BomInstanceLines (generate BOM first)';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '====================================================';
        RAISE NOTICE '🧪 Testing generate_cut_list_for_manufacturing_order';
        RAISE NOTICE '   ManufacturingOrder: % (%)', v_mo_no, v_mo_id;
        RAISE NOTICE '====================================================';
        RAISE NOTICE '';
        
        -- Call the function
        PERFORM public.generate_cut_list_for_manufacturing_order(v_mo_id);
        
        RAISE NOTICE '';
        RAISE NOTICE '✅ Function executed successfully!';
        RAISE NOTICE '';
    END IF;
END;
$$;

-- ====================================================
-- VERIFICATION: Check if cut list was created
-- ====================================================
-- Run this after the test to verify cut list was created
/*
SELECT 
    cj.id as cut_job_id,
    cj.manufacturing_order_id,
    mo.manufacturing_order_no,
    cj.status as cut_job_status,
    COUNT(cjl.id) as cut_lines_count
FROM "CutJobs" cj
INNER JOIN "ManufacturingOrders" mo ON mo.id = cj.manufacturing_order_id
LEFT JOIN "CutJobLines" cjl ON cjl.cut_job_id = cj.id AND cjl.deleted = false
WHERE cj.deleted = false
GROUP BY cj.id, cj.manufacturing_order_id, mo.manufacturing_order_no, cj.status
ORDER BY cj.created_at DESC
LIMIT 5;
*/






