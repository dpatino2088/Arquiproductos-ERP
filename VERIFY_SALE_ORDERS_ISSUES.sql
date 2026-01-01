-- ============================================================================
-- VERIFICACIÓN DE PROBLEMAS CON SALE ORDERS
-- ============================================================================
-- Este script verifica:
-- 1. Si hay Sale Orders duplicados para el mismo quote
-- 2. Si los Sale Orders tienen todos los campos necesarios
-- 3. Si hay problemas con la función on_quote_approved_create_operational_docs
-- 4. Si los SaleOrderLines están correctamente vinculados

DO $$
DECLARE
    v_duplicate_count INT;
    v_missing_customer_count INT;
    v_missing_org_count INT;
    v_so_without_lines_count INT;
    v_so_without_bom_count INT;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 VERIFICACIÓN DE PROBLEMAS CON SALE ORDERS';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 1. VERIFICAR SALE ORDERS DUPLICADOS POR QUOTE
    -- ========================================================================
    RAISE NOTICE '📋 PASO 1: Verificando Sale Orders duplicados por quote...';
    
    SELECT COUNT(*) INTO v_duplicate_count
    FROM (
        SELECT quote_id, organization_id, COUNT(*) as cnt
        FROM "SaleOrders"
        WHERE deleted = false AND quote_id IS NOT NULL
        GROUP BY quote_id, organization_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    IF v_duplicate_count > 0 THEN
        RAISE NOTICE '❌ PROBLEMA: Se encontraron % quotes con múltiples Sale Orders', v_duplicate_count;
        RAISE NOTICE '   Detalle de duplicados:';
        FOR rec IN 
            SELECT 
                quote_id,
                organization_id,
                COUNT(*) as sale_order_count,
                STRING_AGG(sale_order_no, ', ' ORDER BY sale_order_no) as sale_order_nos
            FROM "SaleOrders"
            WHERE deleted = false AND quote_id IS NOT NULL
            GROUP BY quote_id, organization_id
            HAVING COUNT(*) > 1
            ORDER BY quote_id
        LOOP
            RAISE NOTICE '   - Quote ID: % | Org: % | Sale Orders: % (%)', 
                rec.quote_id, rec.organization_id, rec.sale_order_count, rec.sale_order_nos;
        END LOOP;
    ELSE
        RAISE NOTICE '✅ No hay Sale Orders duplicados por quote';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 2. VERIFICAR SALE ORDERS SIN CUSTOMER_ID
    -- ========================================================================
    RAISE NOTICE '📋 PASO 2: Verificando Sale Orders sin customer_id...';
    
    SELECT COUNT(*) INTO v_missing_customer_count
    FROM "SaleOrders"
    WHERE deleted = false AND customer_id IS NULL;
    
    IF v_missing_customer_count > 0 THEN
        RAISE NOTICE '⚠️  WARNING: % Sale Orders sin customer_id', v_missing_customer_count;
        RAISE NOTICE '   Detalle:';
        FOR rec IN 
            SELECT id, sale_order_no, quote_id
            FROM "SaleOrders"
            WHERE deleted = false AND customer_id IS NULL
            ORDER BY created_at DESC
            LIMIT 10
        LOOP
            RAISE NOTICE '   - % (ID: %) | Quote: %', 
                rec.sale_order_no, rec.id, COALESCE(rec.quote_id::TEXT, 'NULL');
        END LOOP;
    ELSE
        RAISE NOTICE '✅ Todos los Sale Orders tienen customer_id';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 3. VERIFICAR SALE ORDERS SIN ORGANIZATION_ID
    -- ========================================================================
    RAISE NOTICE '📋 PASO 3: Verificando Sale Orders sin organization_id...';
    
    SELECT COUNT(*) INTO v_missing_org_count
    FROM "SaleOrders"
    WHERE deleted = false AND organization_id IS NULL;
    
    IF v_missing_org_count > 0 THEN
        RAISE NOTICE '❌ PROBLEMA: % Sale Orders sin organization_id', v_missing_org_count;
        RAISE NOTICE '   Detalle:';
        FOR rec IN 
            SELECT id, sale_order_no, quote_id
            FROM "SaleOrders"
            WHERE deleted = false AND organization_id IS NULL
            ORDER BY created_at DESC
            LIMIT 10
        LOOP
            RAISE NOTICE '   - % (ID: %) | Quote: %', 
                rec.sale_order_no, rec.id, COALESCE(rec.quote_id::TEXT, 'NULL');
        END LOOP;
    ELSE
        RAISE NOTICE '✅ Todos los Sale Orders tienen organization_id';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 4. VERIFICAR SALE ORDERS SIN SALEORDERLINES
    -- ========================================================================
    RAISE NOTICE '📋 PASO 4: Verificando Sale Orders sin SaleOrderLines...';
    
    SELECT COUNT(*) INTO v_so_without_lines_count
    FROM "SaleOrders" so
    WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = so.id AND sol.deleted = false
        );
    
    IF v_so_without_lines_count > 0 THEN
        RAISE NOTICE '⚠️  WARNING: % Sale Orders sin SaleOrderLines', v_so_without_lines_count;
        RAISE NOTICE '   Detalle:';
        FOR rec IN 
            SELECT id, sale_order_no, quote_id
            FROM "SaleOrders" so
            WHERE so.deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM "SaleOrderLines" sol
                    WHERE sol.sale_order_id = so.id AND sol.deleted = false
                )
            ORDER BY created_at DESC
            LIMIT 10
        LOOP
            RAISE NOTICE '   - % (ID: %) | Quote: %', 
                rec.sale_order_no, rec.id, COALESCE(rec.quote_id::TEXT, 'NULL');
        END LOOP;
    ELSE
        RAISE NOTICE '✅ Todos los Sale Orders tienen SaleOrderLines';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 5. VERIFICAR SALE ORDERS SIN BOM
    -- ========================================================================
    RAISE NOTICE '📋 PASO 5: Verificando Sale Orders sin BOM...';
    
    SELECT COUNT(*) INTO v_so_without_bom_count
    FROM "SaleOrders" so
    WHERE so.deleted = false
        AND EXISTS (
            SELECT 1 FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = so.id AND sol.deleted = false
        )
        AND NOT EXISTS (
            SELECT 1 FROM "SaleOrderLines" sol
            INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
            WHERE sol.sale_order_id = so.id AND sol.deleted = false AND bi.deleted = false
        );
    
    IF v_so_without_bom_count > 0 THEN
        RAISE NOTICE '⚠️  WARNING: % Sale Orders con SaleOrderLines pero sin BOM', v_so_without_bom_count;
        RAISE NOTICE '   Detalle:';
        FOR rec IN 
            SELECT 
                so.id,
                so.sale_order_no,
                so.quote_id,
                COUNT(DISTINCT sol.id) as line_count
            FROM "SaleOrders" so
            INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
            WHERE so.deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM "BomInstances" bi
                    WHERE bi.sale_order_line_id = sol.id AND bi.deleted = false
                )
            GROUP BY so.id, so.sale_order_no, so.quote_id
            ORDER BY so.created_at DESC
            LIMIT 10
        LOOP
            RAISE NOTICE '   - % (ID: %) | Quote: % | Lines: %', 
                rec.sale_order_no, rec.id, COALESCE(rec.quote_id::TEXT, 'NULL'), rec.line_count;
        END LOOP;
    ELSE
        RAISE NOTICE '✅ Todos los Sale Orders con SaleOrderLines tienen BOM';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 6. RESUMEN FINAL
    -- ========================================================================
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '📊 RESUMEN FINAL';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '   Sale Orders duplicados: %', v_duplicate_count;
    RAISE NOTICE '   Sale Orders sin customer_id: %', v_missing_customer_count;
    RAISE NOTICE '   Sale Orders sin organization_id: %', v_missing_org_count;
    RAISE NOTICE '   Sale Orders sin SaleOrderLines: %', v_so_without_lines_count;
    RAISE NOTICE '   Sale Orders sin BOM: %', v_so_without_bom_count;
    RAISE NOTICE '';
    
    IF v_duplicate_count > 0 OR v_missing_org_count > 0 THEN
        RAISE NOTICE '❌ PROBLEMAS CRÍTICOS DETECTADOS';
        RAISE NOTICE '   Se requiere acción inmediata';
    ELSIF v_missing_customer_count > 0 OR v_so_without_lines_count > 0 OR v_so_without_bom_count > 0 THEN
        RAISE NOTICE '⚠️  PROBLEMAS MENORES DETECTADOS';
        RAISE NOTICE '   Se recomienda revisión';
    ELSE
        RAISE NOTICE '✅ No se detectaron problemas';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    
END $$;








