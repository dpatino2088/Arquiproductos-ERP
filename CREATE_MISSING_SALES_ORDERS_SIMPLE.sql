-- ====================================================
-- Crear SalesOrders faltantes para Quotes aprobados (Versión Simple)
-- ====================================================
-- Este script usa la función convert_quote_to_sale_order
-- para crear SalesOrders para Quotes aprobados que no los tienen
-- ====================================================

DO $$
DECLARE
    r_quote RECORD;
    v_new_sale_order_id uuid;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Creando SalesOrders faltantes para Quotes aprobados';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Buscar quotes aprobados sin SalesOrder
    FOR r_quote IN
        SELECT 
            q.id, 
            q.quote_no, 
            q.organization_id
        FROM "Quotes" q
        LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND so.id IS NULL -- Solo quotes sin SalesOrder existente
        ORDER BY q.created_at ASC
    LOOP
        BEGIN
            RAISE NOTICE '📋 Procesando Quote % (ID: %)...', r_quote.quote_no, r_quote.id;
            
            -- Usar la función convert_quote_to_sale_order
            SELECT public.convert_quote_to_sale_order(
                r_quote.id, 
                r_quote.organization_id
            ) INTO v_new_sale_order_id;
            
            IF v_new_sale_order_id IS NOT NULL THEN
                v_count := v_count + 1;
                RAISE NOTICE '✅ Creado SalesOrder % para Quote %', v_new_sale_order_id, r_quote.quote_no;
            ELSE
                RAISE WARNING '⚠️ No se pudo crear SalesOrder para Quote %', r_quote.quote_no;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error creando SalesOrder para Quote % (ID: %): %', 
                    r_quote.quote_no, r_quote.id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Proceso completado!';
    RAISE NOTICE '   Total SalesOrders creados: %', v_count;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar resultados
SELECT 
    q.quote_no,
    q.status AS quote_status,
    so.sale_order_no,
    so.status AS so_status,
    so.order_progress_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing SalesOrder'
        ELSE '✅ Has SalesOrder'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;






