-- ====================================================
-- Migration 349: Execute generate_bom with detailed logging
-- ====================================================
-- This will show what the function is actually doing
-- ====================================================

-- First, let's manually trace through what the function should do
DO $$
DECLARE
    v_mo_id uuid;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_quote_line_id uuid;
    v_organization_id uuid;
    v_bi_exists boolean;
    v_qlc_count integer;
BEGIN
    -- Get MO-000003
    SELECT mo.id, mo.sale_order_id, mo.organization_id
    INTO v_mo_id, v_sale_order_id, v_organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND mo.deleted = false
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE EXCEPTION 'MO-000003 not found';
    END IF;
    
    RAISE NOTICE '📋 MO ID: %', v_mo_id;
    RAISE NOTICE '   Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Get SalesOrderLine
    SELECT sol.id, sol.quote_line_id
    INTO v_sale_order_line_id, v_quote_line_id
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = v_sale_order_id
    AND sol.deleted = false
    LIMIT 1;
    
    IF v_sale_order_line_id IS NULL THEN
        RAISE NOTICE '❌ No SalesOrderLines found';
        RETURN;
    END IF;
    
    RAISE NOTICE '📝 SalesOrderLine ID: %', v_sale_order_line_id;
    RAISE NOTICE '   QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '';
    
    -- Check if BomInstance exists
    SELECT EXISTS(
        SELECT 1 FROM "BomInstances" bi
        WHERE bi.sale_order_line_id = v_sale_order_line_id
        AND bi.deleted = false
    ) INTO v_bi_exists;
    
    RAISE NOTICE '🏗️  BomInstance exists: %', v_bi_exists;
    
    -- Count QuoteLineComponents
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents" qlc
    WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
    
    RAISE NOTICE '🧩 QuoteLineComponents count: %', v_qlc_count;
    RAISE NOTICE '';
    
    IF NOT v_bi_exists THEN
        RAISE NOTICE '✅ BomInstance should be created (does not exist)';
        RAISE NOTICE '   QuoteLineComponents available: %', v_qlc_count;
    ELSE
        RAISE NOTICE '⏭️  BomInstance already exists, skipping creation';
    END IF;
    
END $$;

-- Now execute the actual function and capture result
SELECT public.generate_bom_for_manufacturing_order(
    (SELECT id FROM "ManufacturingOrders" WHERE manufacturing_order_no = 'MO-000003' AND deleted = false LIMIT 1)
) as function_result;


