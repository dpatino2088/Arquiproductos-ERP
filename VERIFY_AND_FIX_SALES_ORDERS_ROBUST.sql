-- ====================================================
-- Script Robusto para Verificar y Corregir Sales Orders
-- ====================================================
-- Este script verifica que todos los Quotes aprobados tengan Sales Orders
-- y corrige cualquier problema encontrado
-- ====================================================

DO $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_count_fixed integer := 0;
    v_count_verified integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Verificando y corrigiendo Sales Orders para Quotes aprobados';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Verificar Quotes aprobados sin Sales Orders
    FOR v_quote_record IN
        SELECT 
            q.id,
            q.quote_no,
            q.organization_id,
            q.customer_id,
            q.status,
            q.totals,
            q.currency,
            q.notes
        FROM "Quotes" q
        LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND so.id IS NULL
        ORDER BY q.created_at ASC
    LOOP
        BEGIN
            RAISE NOTICE '🔍 Procesando Quote % (ID: %) sin Sales Order...', v_quote_record.quote_no, v_quote_record.id;
            
            -- Intentar crear Sales Order usando la función
            SELECT public.convert_quote_to_sale_order(
                v_quote_record.id,
                v_quote_record.organization_id
            ) INTO v_sale_order_id;
            
            IF v_sale_order_id IS NOT NULL THEN
                v_count_fixed := v_count_fixed + 1;
                RAISE NOTICE '✅ Creado Sales Order % para Quote %', v_sale_order_id, v_quote_record.quote_no;
            ELSE
                RAISE WARNING '⚠️ No se pudo crear Sales Order para Quote %', v_quote_record.quote_no;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error creando Sales Order para Quote %: %', v_quote_record.quote_no, SQLERRM;
        END;
    END LOOP;

    -- Verificar Quotes aprobados CON Sales Orders
    FOR v_quote_record IN
        SELECT 
            q.id,
            q.quote_no,
            so.id as sale_order_id,
            so.sale_order_no,
            so.status as so_status
        FROM "Quotes" q
        INNER JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
        WHERE q.status = 'approved'
        AND q.deleted = false
        ORDER BY q.created_at DESC
        LIMIT 10
    LOOP
        v_count_verified := v_count_verified + 1;
        RAISE NOTICE '✅ Quote % tiene Sales Order % (Status: %)', 
            v_quote_record.quote_no, 
            v_quote_record.sale_order_no,
            v_quote_record.so_status;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Resumen:';
    RAISE NOTICE '  - Sales Orders creados: %', v_count_fixed;
    RAISE NOTICE '  - Sales Orders verificados: %', v_count_verified;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificación final
SELECT 
    'Verificación Final' as tipo,
    COUNT(DISTINCT q.id) as quotes_aprobados,
    COUNT(DISTINCT so.id) as sales_orders_existentes,
    COUNT(DISTINCT CASE WHEN so.id IS NULL THEN q.id END) as quotes_sin_so,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN so.id IS NULL THEN q.id END) = 0 THEN '✅ Todos los Quotes aprobados tienen Sales Orders'
        ELSE '⚠️ Hay Quotes aprobados sin Sales Orders'
    END as estado
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false;






