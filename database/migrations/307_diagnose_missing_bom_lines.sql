-- ====================================================
-- Migration 307: Diagnose why BomInstanceLines are not being created
-- ====================================================

-- Step 1: Check if QuoteLineComponents exist for the QuoteLines
DO $$
DECLARE
    v_mo_id uuid;
    v_sale_order_id uuid;
    v_bom_instance_record RECORD;
    v_qlc_count integer;
    v_qlc_with_source integer;
    rec RECORD;
BEGIN
    RAISE NOTICE '🔍 Diagnosing missing BomInstanceLines...';
    RAISE NOTICE '';
    
    -- Get Manufacturing Order details
    SELECT mo.id, mo.sale_order_id
    INTO v_mo_id, v_sale_order_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000002'
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder MO-000002 not found';
    END IF;
    
    RAISE NOTICE 'Manufacturing Order ID: %', v_mo_id;
    RAISE NOTICE 'Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '';
    
    -- Check each BomInstance
    FOR v_bom_instance_record IN
        SELECT bi.id as bom_instance_id, bi.quote_line_id
        FROM "BomInstances" bi
        JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order_id
        AND bi.deleted = false
        AND sol.deleted = false
    LOOP
        RAISE NOTICE '--- BomInstance: % ---', v_bom_instance_record.bom_instance_id;
        RAISE NOTICE 'QuoteLine ID: %', v_bom_instance_record.quote_line_id;
        
        -- Count all QuoteLineComponents
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
        AND qlc.deleted = false;
        
        RAISE NOTICE 'Total QuoteLineComponents (not deleted): %', v_qlc_count;
        
        -- Count QuoteLineComponents with source = 'configured_component'
        SELECT COUNT(*) INTO v_qlc_with_source
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        RAISE NOTICE 'QuoteLineComponents with source=configured_component: %', v_qlc_with_source;
        
        -- Show all sources
        RAISE NOTICE 'All sources for this QuoteLine:';
        FOR rec IN
            SELECT DISTINCT qlc.source, COUNT(*) as count
            FROM "QuoteLineComponents" qlc
            WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
            AND qlc.deleted = false
            GROUP BY qlc.source
        LOOP
            RAISE NOTICE '  - %: %', rec.source, rec.count;
        END LOOP;
        
        -- Show sample QuoteLineComponents
        RAISE NOTICE 'Sample QuoteLineComponents:';
        FOR rec IN
            SELECT 
                qlc.id,
                qlc.component_role,
                qlc.source,
                qlc.catalog_item_id,
                qlc.qty,
                qlc.uom,
                ci.sku
            FROM "QuoteLineComponents" qlc
            LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
            AND qlc.deleted = false
            LIMIT 10
        LOOP
            RAISE NOTICE '  - Role: %, Source: %, SKU: %, Qty: %, UOM: %', 
                rec.component_role, rec.source, COALESCE(rec.sku, 'NULL'), rec.qty, rec.uom;
        END LOOP;
        
        -- Check existing BomInstanceLines
        SELECT COUNT(*) INTO v_qlc_count
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = v_bom_instance_record.bom_instance_id
        AND bil.deleted = false;
        
        RAISE NOTICE 'Existing BomInstanceLines: %', v_qlc_count;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '✅ Diagnosis complete.';
    
END $$;

