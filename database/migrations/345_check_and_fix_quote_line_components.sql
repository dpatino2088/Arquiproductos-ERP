-- ====================================================
-- Migration 345: Check and Fix QuoteLineComponents for MO-000003
-- ====================================================
-- First check if QuoteLineComponents exist, if not, guide on how to generate them
-- ====================================================

-- Step 1: Check current state
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_line_id uuid;
    v_qlc_count integer;
    v_sol_count integer;
BEGIN
    -- Get Quote ID from MO-000003
    SELECT so.quote_id, sol.quote_line_id
    INTO v_quote_id, v_quote_line_id
    FROM "ManufacturingOrders" mo
    INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
    INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND mo.deleted = false
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ Could not find Quote for MO-000003';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Quote ID: %', v_quote_id;
    RAISE NOTICE '📝 QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '';
    
    -- Count QuoteLineComponents
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents" qlc
    WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
    
    RAISE NOTICE '🧩 QuoteLineComponents (configured): %', v_qlc_count;
    
    IF v_qlc_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ PROBLEM FOUND: No QuoteLineComponents exist!';
        RAISE NOTICE '';
        RAISE NOTICE 'SOLUTION: You need to generate QuoteLineComponents first using:';
        RAISE NOTICE '  SELECT public.generate_configured_bom_for_quote_line(''%'');', v_quote_line_id;
        RAISE NOTICE '';
        RAISE NOTICE 'After generating QuoteLineComponents, then run generate_bom_for_manufacturing_order';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '✅ QuoteLineComponents exist. The problem is elsewhere.';
        RAISE NOTICE '   Check if the function is actually creating BomInstances.';
    END IF;
    
END $$;

-- Step 2: Show QuoteLine details to help with manual generation if needed
SELECT 
    ql.id as quote_line_id,
    ql.product_type,
    ql.product_type_id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    ql.width_m,
    ql.height_m,
    ql.qty,
    ql.bom_template_id,
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
     WHERE qlc.quote_line_id = ql.id 
     AND qlc.deleted = false 
     AND qlc.source = 'configured_component') as quote_line_components_count
FROM "QuoteLines" ql
INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
ORDER BY ql.created_at;


