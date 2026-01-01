-- ====================================================
-- Migration 335: Diagnose Missing BOM for Manufacturing Order
-- ====================================================
-- Diagnostic script to understand why BOM is not being generated
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_mo RECORD;
    v_so RECORD;
    v_so_line_count integer;
    v_ql_count integer;
    v_qlc_count integer;
    v_bi_count integer;
    v_bil_count integer;
BEGIN
    -- Find the most recent Manufacturing Order (or use a specific one)
    -- Replace 'MO-000004' with the actual MO number you want to diagnose
    SELECT mo.id, mo.manufacturing_order_no, mo.sale_order_id
    INTO v_mo
    FROM "ManufacturingOrders" mo
    WHERE mo.deleted = false
    ORDER BY mo.created_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ No Manufacturing Orders found';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Diagnosing BOM for Manufacturing Order: %', v_mo.manufacturing_order_no;
    RAISE NOTICE '   MO ID: %', v_mo.id;
    RAISE NOTICE '   Sale Order ID: %', v_mo.sale_order_id;
    RAISE NOTICE '';
    
    -- Get Sale Order details
    SELECT so.id, so.sale_order_no, so.quote_id
    INTO v_so
    FROM "SalesOrders" so
    WHERE so.id = v_mo.sale_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Sale Order not found for MO';
        RETURN;
    END IF;
    
    RAISE NOTICE '📦 Sale Order: %', v_so.sale_order_no;
    RAISE NOTICE '   Quote ID: %', v_so.quote_id;
    RAISE NOTICE '';
    
    -- Count SalesOrderLines
    SELECT COUNT(*) INTO v_so_line_count
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = v_so.id
    AND sol.deleted = false;
    
    RAISE NOTICE '📋 SalesOrderLines: %', v_so_line_count;
    
    -- Count QuoteLines
    SELECT COUNT(*) INTO v_ql_count
    FROM "QuoteLines" ql
    WHERE ql.quote_id = v_so.quote_id
    AND ql.deleted = false;
    
    RAISE NOTICE '📝 QuoteLines: %', v_ql_count;
    
    -- Count QuoteLineComponents (configured components)
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    WHERE ql.quote_id = v_so.quote_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
    
    RAISE NOTICE '🧩 QuoteLineComponents (configured): %', v_qlc_count;
    
    -- Count BomInstances
    SELECT COUNT(*) INTO v_bi_count
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so.id
    AND bi.deleted = false;
    
    RAISE NOTICE '🏗️  BomInstances: %', v_bi_count;
    
    -- Count BomInstanceLines
    SELECT COUNT(*) INTO v_bil_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so.id
    AND bil.deleted = false;
    
    RAISE NOTICE '📊 BomInstanceLines: %', v_bil_count;
    RAISE NOTICE '';
    
    -- Diagnosis
    IF v_so_line_count = 0 THEN
        RAISE NOTICE '❌ PROBLEM: No SalesOrderLines found';
        RAISE NOTICE '   → Cannot create BomInstances without SalesOrderLines';
    ELSIF v_qlc_count = 0 THEN
        RAISE NOTICE '❌ PROBLEM: No QuoteLineComponents found';
        RAISE NOTICE '   → QuoteLineComponents are required to create BomInstanceLines';
        RAISE NOTICE '   → Run generate_configured_bom_for_quote_line() for each QuoteLine';
    ELSIF v_bi_count = 0 THEN
        RAISE NOTICE '❌ PROBLEM: No BomInstances found';
        RAISE NOTICE '   → BomInstances must be created from SalesOrderLines';
        RAISE NOTICE '   → Expected: 1 BomInstance per SalesOrderLine';
    ELSIF v_bil_count = 0 THEN
        RAISE NOTICE '❌ PROBLEM: BomInstances exist but no BomInstanceLines';
        RAISE NOTICE '   → BomInstanceLines should be created from QuoteLineComponents';
    ELSE
        RAISE NOTICE '✅ BOM structure exists';
        RAISE NOTICE '   → BomInstances: %', v_bi_count;
        RAISE NOTICE '   → BomInstanceLines: %', v_bil_count;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '--- Detailed Breakdown ---';
    
    -- Show SalesOrderLines without BomInstances
    RAISE NOTICE '';
    RAISE NOTICE 'SalesOrderLines without BomInstances:';
    FOR v_mo IN
        SELECT sol.id, sol.line_number, sol.product_type
        FROM "SalesOrderLines" sol
        LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
        WHERE sol.sale_order_id = v_so.id
        AND sol.deleted = false
        AND bi.id IS NULL
    LOOP
        RAISE NOTICE '   - Line % (ID: %, Product: %)', v_mo.line_number, v_mo.id, v_mo.product_type;
    END LOOP;
    
    -- Show QuoteLineComponents by role
    RAISE NOTICE '';
    RAISE NOTICE 'QuoteLineComponents by role:';
    FOR v_mo IN
        SELECT qlc.component_role, COUNT(*) as count
        FROM "QuoteLineComponents" qlc
        INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
        WHERE ql.quote_id = v_so.quote_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'
        GROUP BY qlc.component_role
        ORDER BY qlc.component_role
    LOOP
        RAISE NOTICE '   - %: %', v_mo.component_role, v_mo.count;
    END LOOP;
    
END $$;


