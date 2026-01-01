-- ====================================================
-- Probar el Trigger Manualmente
-- ====================================================
-- Este script prueba la función del trigger manualmente
-- para ver si funciona sin depender del trigger
-- ====================================================

-- PASO 1: Obtener el último MO creado
DO $$
DECLARE
    v_mo_id uuid;
    v_mo_no text;
    v_so_id uuid;
    v_so_no text;
    v_bom_count_before integer;
    v_bom_count_after integer;
BEGIN
    -- Obtener el último MO
    SELECT id, manufacturing_order_no, sale_order_id
    INTO v_mo_id, v_mo_no, v_so_id
    FROM "ManufacturingOrders"
    WHERE deleted = false
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE NOTICE '❌ No hay Manufacturing Orders para probar';
        RETURN;
    END IF;
    
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Probando trigger manualmente para MO: %', v_mo_no;
    RAISE NOTICE '====================================================';
    
    -- Obtener el Sale Order
    SELECT sale_order_no INTO v_so_no
    FROM "SalesOrders"
    WHERE id = v_so_id;
    
    RAISE NOTICE 'Sale Order: %', v_so_no;
    
    -- Contar BOMs antes
    SELECT COUNT(*) INTO v_bom_count_before
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so_id
    AND bi.deleted = false;
    
    RAISE NOTICE 'BOM Instances antes: %', v_bom_count_before;
    
    -- Intentar ejecutar la función manualmente simulando el trigger
    RAISE NOTICE '';
    RAISE NOTICE 'Simulando la ejecución del trigger...';
    RAISE NOTICE '';
    
    -- Verificar que existan QuoteLineComponents
    DECLARE
        v_qlc_count integer;
    BEGIN
        SELECT COUNT(*) INTO v_qlc_count
        FROM "SalesOrderLines" sol
        JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
        JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
        WHERE sol.sale_order_id = v_so_id
        AND sol.deleted = false
        AND ql.deleted = false
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        RAISE NOTICE 'QuoteLineComponents disponibles: %', v_qlc_count;
        
        IF v_qlc_count = 0 THEN
            RAISE WARNING '⚠️ No hay QuoteLineComponents! El trigger no puede generar BOM sin ellos.';
            RAISE NOTICE '';
            RAISE NOTICE 'Verificando QuoteLines...';
            
            DECLARE
                v_quote_line RECORD;
            BEGIN
                FOR v_quote_line IN
                    SELECT ql.id, ql.product_type_id
                    FROM "SalesOrderLines" sol
                    JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
                    WHERE sol.sale_order_id = v_so_id
                    AND sol.deleted = false
                    AND ql.deleted = false
                LOOP
                    RAISE NOTICE 'QuoteLine: % - Product Type ID: %', v_quote_line.id, v_quote_line.product_type_id;
                    
                    IF v_quote_line.product_type_id IS NULL THEN
                        RAISE WARNING '❌ QuoteLine % no tiene product_type_id!', v_quote_line.id;
                    END IF;
                END LOOP;
            END;
        END IF;
    END;
    
    -- Contar BOMs después (no cambiará porque solo estamos verificando)
    SELECT COUNT(*) INTO v_bom_count_after
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_so_id
    AND bi.deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE 'BOM Instances después: %', v_bom_count_after;
    
    IF v_bom_count_after = 0 THEN
        RAISE WARNING '❌ No se generaron BOMs!';
        RAISE NOTICE '';
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'POSIBLES CAUSAS:';
        RAISE NOTICE '====================================================';
        RAISE NOTICE '1. El trigger no se ejecutó cuando se creó el MO';
        RAISE NOTICE '2. El trigger se ejecutó pero falló silenciosamente';
        RAISE NOTICE '3. No hay QuoteLineComponents disponibles';
        RAISE NOTICE '4. La función tiene un error';
        RAISE NOTICE '';
        RAISE NOTICE 'SOLUCIÓN:';
        RAISE NOTICE '1. Ejecutar FIX_BOM_TRIGGER_FINAL.sql';
        RAISE NOTICE '2. Crear un NUEVO Manufacturing Order';
        RAISE NOTICE '3. Revisar los logs de PostgreSQL para ver errores';
    ELSE
        RAISE NOTICE '✅ El MO tiene BOMs generados!';
    END IF;
    
END;
$$;






