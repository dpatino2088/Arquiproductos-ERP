-- Verificar datos de SO-000010 y customer
DO $$
DECLARE
    v_so_id UUID;
    v_customer_id UUID;
    v_customer_name TEXT;
    v_bom_count INT;
    v_material_count INT;
BEGIN
    RAISE NOTICE '=== VERIFICACIÓN DE DATOS SO-000010 ===';
    
    -- 1. Buscar SO-000010
    SELECT id, customer_id INTO v_so_id, v_customer_id
    FROM "SaleOrders"
    WHERE sale_order_no = 'SO-000010' AND deleted = false
    LIMIT 1;
    
    IF v_so_id IS NULL THEN
        RAISE NOTICE '❌ SO-000010 NO ENCONTRADO';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ SO-000010 encontrado: ID = %', v_so_id;
    RAISE NOTICE '   Customer ID = %', v_customer_id;
    
    -- 2. Obtener nombre del customer
    SELECT customer_name INTO v_customer_name
    FROM "DirectoryCustomers"
    WHERE id = v_customer_id;
    
    IF v_customer_name IS NULL THEN
        RAISE NOTICE '⚠️  Customer name NO encontrado para customer_id = %', v_customer_id;
    ELSE
        RAISE NOTICE '✅ Customer name: %', v_customer_name;
    END IF;
    
    -- 3. Verificar SaleOrderLines
    RAISE NOTICE '';
    RAISE NOTICE '📊 SALEORDERLINES para SO-000010:';
    PERFORM * FROM "SaleOrderLines"
    WHERE sale_order_id = v_so_id AND deleted = false;
    
    -- 4. Verificar BomInstances
    RAISE NOTICE '';
    RAISE NOTICE '📊 BOMINSTANCES para SO-000010:';
    SELECT COUNT(*) INTO v_bom_count
    FROM "BomInstances" bi
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so_id AND bi.deleted = false;
    
    RAISE NOTICE '   Total BomInstances: %', v_bom_count;
    
    -- 5. Verificar BomInstanceLines
    RAISE NOTICE '';
    RAISE NOTICE '📊 BOMINSTANCELINES para SO-000010:';
    SELECT COUNT(*) INTO v_material_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so_id AND bil.deleted = false;
    
    RAISE NOTICE '   Total BomInstanceLines: %', v_material_count;
    
    -- 6. Verificar SaleOrderMaterialList view
    RAISE NOTICE '';
    RAISE NOTICE '📊 SALEORDERMATERIALLIST para SO-000010:';
    SELECT COUNT(*) INTO v_material_count
    FROM "SaleOrderMaterialList"
    WHERE sale_order_id = v_so_id;
    
    RAISE NOTICE '   Total materiales en view: %', v_material_count;
    
    -- 7. Mostrar materiales detallados
    RAISE NOTICE '';
    RAISE NOTICE '📋 DETALLE DE MATERIALES:';
    FOR rec IN 
        SELECT 
            sml.sku,
            sml.item_name,
            sml.total_qty,
            sml.uom,
            sml.total_cost_exw
        FROM "SaleOrderMaterialList" sml
        WHERE sml.sale_order_id = v_so_id
        ORDER BY sml.sku
    LOOP
        RAISE NOTICE '   - % | % | Qty: % % | Cost: $%', 
            rec.sku, rec.item_name, rec.total_qty, rec.uom, rec.total_cost_exw;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== FIN DE VERIFICACIÓN ===';
END $$;
