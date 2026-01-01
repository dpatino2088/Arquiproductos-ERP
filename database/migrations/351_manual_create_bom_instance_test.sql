-- ====================================================
-- Migration 351: Manual Create BomInstance Test
-- ====================================================
-- Manually creates a BomInstance to test if it works
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_quote_line_id uuid;
    v_organization_id uuid;
    v_bom_instance_id uuid;
BEGIN
    -- Get MO-000003 details
    SELECT mo.id, mo.sale_order_id, mo.organization_id
    INTO v_mo_id, v_sale_order_id, v_organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND mo.deleted = false
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE EXCEPTION 'MO-000003 not found';
    END IF;
    
    -- Get SalesOrderLine
    SELECT sol.id, sol.quote_line_id
    INTO v_sale_order_line_id, v_quote_line_id
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = v_sale_order_id
    AND sol.deleted = false
    LIMIT 1;
    
    IF v_sale_order_line_id IS NULL THEN
        RAISE EXCEPTION 'No SalesOrderLines found';
    END IF;
    
    RAISE NOTICE '📋 Details:';
    RAISE NOTICE '   MO ID: %', v_mo_id;
    RAISE NOTICE '   Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '   Sale Order Line ID: %', v_sale_order_line_id;
    RAISE NOTICE '   Quote Line ID: %', v_quote_line_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Check if BomInstance already exists
    SELECT id INTO v_bom_instance_id
    FROM "BomInstances"
    WHERE sale_order_line_id = v_sale_order_line_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⚠️  BomInstance already exists: %', v_bom_instance_id;
        RETURN;
    END IF;
    
    RAISE NOTICE '🔧 Creating BomInstance manually...';
    
    -- Try to create BomInstance
    BEGIN
        INSERT INTO "BomInstances" (
            organization_id,
            sale_order_line_id,
            quote_line_id,
            bom_template_id,
            deleted,
            created_at,
            updated_at
        ) VALUES (
            v_organization_id,
            v_sale_order_line_id,
            v_quote_line_id,
            (SELECT bom_template_id FROM "QuoteLines" ql 
             WHERE ql.id = v_quote_line_id 
             AND ql.deleted = false 
             LIMIT 1),
            false,
            now(),
            now()
        ) RETURNING id INTO v_bom_instance_id;
        
        RAISE NOTICE '✅ BomInstance created successfully: %', v_bom_instance_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error creating BomInstance: %', SQLERRM;
            RAISE WARNING '   SQLSTATE: %', SQLSTATE;
    END;
    
END $$;

-- Verify
SELECT 
    'VERIFICATION' as check_type,
    COUNT(*) as bom_instances
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND bi.deleted = false;


