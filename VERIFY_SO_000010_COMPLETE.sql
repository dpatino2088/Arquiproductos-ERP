-- ============================================================================
-- VERIFICACIÓN COMPLETA DE SO-000010 Y BOM
-- ============================================================================

DO $$
DECLARE
    v_so_id UUID;
    v_customer_id UUID;
    v_customer_name TEXT;
    v_organization_id UUID;
    v_bom_count INT;
    v_material_count INT;
    v_quote_line_count INT;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 VERIFICACIÓN COMPLETA DE SO-000010 Y BOM';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 1. VERIFICAR SALE ORDER
    -- ========================================================================
    RAISE NOTICE '📋 PASO 1: Verificando SaleOrder SO-000010...';
    
    SELECT id, customer_id, organization_id 
    INTO v_so_id, v_customer_id, v_organization_id
    FROM "SaleOrders"
    WHERE sale_order_no = 'SO-000010' AND deleted = false
    LIMIT 1;
    
    IF v_so_id IS NULL THEN
        RAISE NOTICE '❌ ERROR: SO-000010 NO ENCONTRADO';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ SO-000010 encontrado:';
    RAISE NOTICE '   - ID: %', v_so_id;
    RAISE NOTICE '   - Customer ID: %', v_customer_id;
    RAISE NOTICE '   - Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 2. VERIFICAR CUSTOMER NAME
    -- ========================================================================
    RAISE NOTICE '📋 PASO 2: Verificando Customer Name...';
    
    SELECT customer_name INTO v_customer_name
    FROM "DirectoryCustomers"
    WHERE id = v_customer_id;
    
    IF v_customer_name IS NULL THEN
        RAISE NOTICE '⚠️  WARNING: Customer name NO encontrado para customer_id = %', v_customer_id;
        RAISE NOTICE '   Verificando si el customer existe...';
        PERFORM * FROM "DirectoryCustomers" WHERE id = v_customer_id;
    ELSE
        RAISE NOTICE '✅ Customer name encontrado: %', v_customer_name;
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 3. VERIFICAR SALEORDERLINES
    -- ========================================================================
    RAISE NOTICE '📋 PASO 3: Verificando SaleOrderLines...';
    
    SELECT COUNT(*) INTO v_quote_line_count
    FROM "SaleOrderLines"
    WHERE sale_order_id = v_so_id AND deleted = false;
    
    RAISE NOTICE '   Total SaleOrderLines: %', v_quote_line_count;
    
    IF v_quote_line_count = 0 THEN
        RAISE NOTICE '⚠️  WARNING: No hay SaleOrderLines para SO-000010';
    ELSE
        RAISE NOTICE '   Detalle de SaleOrderLines:';
        FOR rec IN 
            SELECT 
                sol.id,
                sol.quote_line_id,
                ql.product_type_id,
                pt.name as product_type_name
            FROM "SaleOrderLines" sol
            LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
            LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
            WHERE sol.sale_order_id = v_so_id AND sol.deleted = false
        LOOP
            RAISE NOTICE '      - SOL ID: % | QuoteLine ID: % | ProductType: % (%)', 
                rec.id, rec.quote_line_id, rec.product_type_name, rec.product_type_id;
        END LOOP;
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 4. VERIFICAR BOMINSTANCES
    -- ========================================================================
    RAISE NOTICE '📋 PASO 4: Verificando BomInstances...';
    
    SELECT COUNT(*) INTO v_bom_count
    FROM "BomInstances" bi
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so_id AND bi.deleted = false;
    
    RAISE NOTICE '   Total BomInstances: %', v_bom_count;
    
    IF v_bom_count = 0 THEN
        RAISE NOTICE '⚠️  WARNING: No hay BomInstances para SO-000010';
        RAISE NOTICE '   Esto significa que los BOM no se generaron correctamente';
    ELSE
        RAISE NOTICE '   Detalle de BomInstances:';
        FOR rec IN 
            SELECT 
                bi.id,
                bi.sale_order_line_id,
                bi.quote_line_id,
                bi.bom_template_id
            FROM "BomInstances" bi
            INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
            WHERE sol.sale_order_id = v_so_id AND bi.deleted = false
        LOOP
            RAISE NOTICE '      - BOM Instance ID: % | SOL ID: % | QuoteLine ID: % | Template ID: %', 
                rec.id, rec.sale_order_line_id, rec.quote_line_id, rec.bom_template_id;
        END LOOP;
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 5. VERIFICAR BOMINSTANCELINES
    -- ========================================================================
    RAISE NOTICE '📋 PASO 5: Verificando BomInstanceLines...';
    
    SELECT COUNT(*) INTO v_material_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so_id AND bil.deleted = false;
    
    RAISE NOTICE '   Total BomInstanceLines: %', v_material_count;
    
    IF v_material_count = 0 THEN
        RAISE NOTICE '⚠️  WARNING: No hay BomInstanceLines para SO-000010';
        RAISE NOTICE '   Esto significa que los materiales no se generaron correctamente';
    ELSE
        RAISE NOTICE '   Resumen por categoría:';
        FOR rec IN 
            SELECT 
                bil.category_code,
                COUNT(*) as count,
                SUM(bil.qty) as total_qty,
                SUM(bil.total_cost_exw) as total_cost
            FROM "BomInstanceLines" bil
            INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
            INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
            WHERE sol.sale_order_id = v_so_id AND bil.deleted = false
            GROUP BY bil.category_code
            ORDER BY bil.category_code
        LOOP
            RAISE NOTICE '      - %: % items, Qty: %, Cost: $%', 
                COALESCE(rec.category_code, 'NULL'), rec.count, rec.total_qty, rec.total_cost;
        END LOOP;
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 6. VERIFICAR SALEORDERMATERIALLIST VIEW
    -- ========================================================================
    RAISE NOTICE '📋 PASO 6: Verificando SaleOrderMaterialList view...';
    
    SELECT COUNT(*) INTO v_material_count
    FROM "SaleOrderMaterialList"
    WHERE sale_order_id = v_so_id;
    
    RAISE NOTICE '   Total materiales en view: %', v_material_count;
    
    IF v_material_count = 0 THEN
        RAISE NOTICE '⚠️  WARNING: No hay materiales en SaleOrderMaterialList para SO-000010';
        RAISE NOTICE '   Esto significa que la vista no está funcionando correctamente';
    ELSE
        RAISE NOTICE '   Detalle de materiales en view:';
        FOR rec IN 
            SELECT 
                sml.sku,
                sml.item_name,
                sml.category_code,
                sml.total_qty,
                sml.uom,
                sml.avg_unit_cost_exw,
                sml.total_cost_exw
            FROM "SaleOrderMaterialList" sml
            WHERE sml.sale_order_id = v_so_id
            ORDER BY sml.category_code, sml.sku
        LOOP
            RAISE NOTICE '      - % | % | Cat: % | Qty: % % | Unit: $% | Total: $%', 
                rec.sku, rec.item_name, COALESCE(rec.category_code, 'NULL'), 
                rec.total_qty, rec.uom, rec.avg_unit_cost_exw, rec.total_cost_exw;
        END LOOP;
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 7. RESUMEN FINAL
    -- ========================================================================
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '📊 RESUMEN FINAL';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '   Sale Order: SO-000010';
    RAISE NOTICE '   Customer: % (%)', COALESCE(v_customer_name, 'NO ENCONTRADO'), v_customer_id;
    RAISE NOTICE '   SaleOrderLines: %', v_quote_line_count;
    RAISE NOTICE '   BomInstances: %', v_bom_count;
    RAISE NOTICE '   BomInstanceLines: %', v_material_count;
    RAISE NOTICE '   Materiales en View: %', v_material_count;
    RAISE NOTICE '';
    
    IF v_bom_count = 0 OR v_material_count = 0 THEN
        RAISE NOTICE '❌ PROBLEMA DETECTADO: Los BOM no están generados correctamente';
        RAISE NOTICE '   Acción requerida: Regenerar BOM para SO-000010';
    ELSE
        RAISE NOTICE '✅ Los BOM están generados correctamente';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    
END $$;

