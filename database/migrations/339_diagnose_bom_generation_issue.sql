-- ====================================================
-- Migration 339: Diagnose BOM Generation Issue
-- ====================================================
-- Diagnostic script to understand why generate_bom_for_manufacturing_order is not working
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_mo RECORD;
    v_so RECORD;
    v_result jsonb;
    v_so_line_count integer;
    v_qlc_count integer;
    v_bi_count_before integer;
    v_bi_count_after integer;
    v_bil_count_before integer;
    v_bil_count_after integer;
BEGIN
    -- Get the most recent Manufacturing Order
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
    RAISE NOTICE '🔍 Diagnosing BOM Generation for MO: %', v_mo.manufacturing_order_no;
    RAISE NOTICE '   MO ID: %', v_mo.id;
    RAISE NOTICE '';
    
    -- Get Sale Order
    SELECT so.id, so.sale_order_no, so.quote_id
    INTO v_so
    FROM "SalesOrders" so
    WHERE so.id = v_mo.sale_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Sale Order not found';
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
    
    -- Count QuoteLineComponents (configured components)
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    WHERE ql.quote_id = v_so.quote_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
    
    RAISE NOTICE '🧩 QuoteLineComponents (configured): %', v_qlc_count;
    
    -- Show QuoteLineComponents details
    RAISE NOTICE '';
    RAISE NOTICE 'QuoteLineComponents details:';
    FOR v_mo IN
        SELECT qlc.component_role, qlc.qty, qlc.uom, ci.sku, ci.item_name
        FROM "QuoteLineComponents" qlc
        INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
        INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE ql.quote_id = v_so.quote_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'
        ORDER BY qlc.component_role
        LIMIT 20
    LOOP
        RAISE NOTICE '   - %: % % (SKU: %, Name: %)', 
            v_mo.component_role, v_mo.qty, v_mo.uom, v_mo.sku, v_mo.item_name;
    END LOOP;
    
    -- Count BomInstances BEFORE
    SELECT COUNT(*) INTO v_bi_count_before
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so.id
    AND bi.deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '🏗️  BomInstances BEFORE: %', v_bi_count_before;
    
    -- Count BomInstanceLines BEFORE
    SELECT COUNT(*) INTO v_bil_count_before
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so.id
    AND bil.deleted = false;
    
    RAISE NOTICE '📊 BomInstanceLines BEFORE: %', v_bil_count_before;
    RAISE NOTICE '';
    
    -- Execute the function
    RAISE NOTICE '🚀 Executing generate_bom_for_manufacturing_order...';
    RAISE NOTICE '';
    
    BEGIN
        v_result := public.generate_bom_for_manufacturing_order(v_mo.id);
        
        RAISE NOTICE '✅ Function executed successfully';
        RAISE NOTICE '   Result: %', v_result;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Error executing function: %', SQLERRM;
            RAISE NOTICE '   SQLSTATE: %', SQLSTATE;
            RETURN;
    END;
    
    RAISE NOTICE '';
    
    -- Count BomInstances AFTER
    SELECT COUNT(*) INTO v_bi_count_after
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so.id
    AND bi.deleted = false;
    
    RAISE NOTICE '🏗️  BomInstances AFTER: %', v_bi_count_after;
    
    -- Count BomInstanceLines AFTER
    SELECT COUNT(*) INTO v_bil_count_after
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so.id
    AND bil.deleted = false;
    
    RAISE NOTICE '📊 BomInstanceLines AFTER: %', v_bil_count_after;
    RAISE NOTICE '';
    
    -- Summary
    RAISE NOTICE '📈 Summary:';
    RAISE NOTICE '   BomInstances created: %', (v_bi_count_after - v_bi_count_before);
    RAISE NOTICE '   BomInstanceLines created: %', (v_bil_count_after - v_bil_count_before);
    
    IF v_bi_count_after = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ PROBLEM: No BomInstances were created';
        IF v_qlc_count = 0 THEN
            RAISE NOTICE '   → QuoteLineComponents count is 0. Generate QuoteLineComponents first using generate_configured_bom_for_quote_line()';
        ELSIF v_so_line_count = 0 THEN
            RAISE NOTICE '   → SalesOrderLines count is 0. Cannot create BOM without SalesOrderLines';
        ELSE
            RAISE NOTICE '   → Function executed but did not create BomInstances. Check function logs for errors.';
        END IF;
    ELSIF v_bil_count_after = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  WARNING: BomInstances created but no BomInstanceLines';
        RAISE NOTICE '   → Check QuoteLineComponents have catalog_item_id and are not deleted';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '✅ SUCCESS: BOM created successfully';
    END IF;
    
END $$;


