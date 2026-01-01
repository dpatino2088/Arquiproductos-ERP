-- ==============================================================================
-- VERIFICACIÓN COMPLETA DEL SISTEMA BOM
-- ==============================================================================
-- Este script verifica todo el flujo de datos del BOM system
-- ==============================================================================

DO $$
DECLARE
    v_org_id uuid;
    v_count integer;
BEGIN
    -- Get organization ID
    SELECT id INTO v_org_id FROM "Organizations" WHERE deleted = false LIMIT 1;
    
    RAISE NOTICE '╔══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  VERIFICACIÓN COMPLETA - BOM SYSTEM                      ║';
    RAISE NOTICE '╚══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    RAISE NOTICE '🏢 Organization: %', v_org_id;
    RAISE NOTICE '';
    
    -- 1. Sale Orders
    RAISE NOTICE '1️⃣  SALE ORDERS';
    RAISE NOTICE '   ─────────────────────────────────────────────────────────';
    SELECT COUNT(*) INTO v_count FROM "SaleOrders" WHERE organization_id = v_org_id AND deleted = false;
    RAISE NOTICE '   Total Sale Orders: %', v_count;
    
    -- 2. Sale Order Lines
    RAISE NOTICE '';
    RAISE NOTICE '2️⃣  SALE ORDER LINES';
    RAISE NOTICE '   ─────────────────────────────────────────────────────────';
    SELECT COUNT(*) INTO v_count 
    FROM "SaleOrderLines" sol
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.organization_id = v_org_id AND sol.deleted = false;
    RAISE NOTICE '   Total Sale Order Lines: %', v_count;
    
    -- 3. BomInstances
    RAISE NOTICE '';
    RAISE NOTICE '3️⃣  BOM INSTANCES';
    RAISE NOTICE '   ─────────────────────────────────────────────────────────';
    SELECT COUNT(*) INTO v_count 
    FROM "BomInstances" bi
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.organization_id = v_org_id AND bi.deleted = false;
    RAISE NOTICE '   Total BOM Instances: %', v_count;
    
    -- 4. BomInstanceLines
    RAISE NOTICE '';
    RAISE NOTICE '4️⃣  BOM INSTANCE LINES';
    RAISE NOTICE '   ─────────────────────────────────────────────────────────';
    SELECT COUNT(*) INTO v_count 
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.organization_id = v_org_id AND bil.deleted = false;
    RAISE NOTICE '   Total BOM Instance Lines: %', v_count;
    
    -- 5. SaleOrderMaterialList (View)
    RAISE NOTICE '';
    RAISE NOTICE '5️⃣  SALE ORDER MATERIAL LIST (View)';
    RAISE NOTICE '   ─────────────────────────────────────────────────────────';
    SELECT COUNT(*) INTO v_count 
    FROM "SaleOrderMaterialList" soml
    WHERE soml.sale_order_id IN (SELECT id FROM "SaleOrders" WHERE organization_id = v_org_id AND deleted = false);
    RAISE NOTICE '   Total Material List Items: %', v_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ Verificación completa.';
    RAISE NOTICE '';
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE '📊 SAMPLE DATA FROM SALEORDERMATERIALLIST:';
    RAISE NOTICE '';
    
    -- Show sample data
    FOR v_count IN 1..10 LOOP
        DECLARE
            r record;
        BEGIN
            SELECT 
                soml.sale_order_no,
                soml.sku,
                soml.item_name,
                soml.total_qty,
                soml.uom,
                soml.total_cost_exw
            INTO r
            FROM "SaleOrderMaterialList" soml
            ORDER BY soml.sale_order_no, soml.sku
            OFFSET v_count - 1
            LIMIT 1;
            
            EXIT WHEN NOT FOUND;
            
            RAISE NOTICE '   % | % | % | % % | $%', 
                r.sale_order_no, r.sku, r.item_name, r.total_qty, r.uom, r.total_cost_exw::numeric(10,2);
        END;
    END LOOP;
    
    RAISE NOTICE '';
    
END $$;

