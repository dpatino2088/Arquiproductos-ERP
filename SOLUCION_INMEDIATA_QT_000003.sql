-- ====================================================
-- Solución Inmediata: Crear SalesOrder para QT-000003
-- ====================================================
-- Ejecutar este script completo en Supabase SQL Editor
-- ====================================================

-- Paso 1: Verificar estado actual
SELECT 
    'Estado Actual' as info,
    q.quote_no,
    q.status,
    so.id as sales_order_id,
    so.sale_order_no,
    CASE 
        WHEN so.id IS NULL THEN '❌ No SalesOrder'
        ELSE '✅ SalesOrder exists'
    END as status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;

-- Paso 2: Forzar creación de SalesOrder
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_record RECORD;
    v_so_id uuid;
    v_so_no text;
BEGIN
    -- Obtener quote
    SELECT 
        q.id,
        q.organization_id,
        q.customer_id,
        q.status,
        q.currency,
        q.totals,
        q.notes
    INTO v_quote_record
    FROM "Quotes" q
    WHERE q.quote_no = 'QT-000003'
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Quote QT-000003 not found';
        RETURN;
    END IF;
    
    RAISE NOTICE '🔍 Found Quote: % (Status: %)', v_quote_record.id, v_quote_record.status;
    
    -- Verificar si SalesOrder ya existe
    SELECT so.id INTO v_so_id
    FROM "SalesOrders" so
    WHERE so.quote_id = v_quote_record.id
    AND so.deleted = false;
    
    IF v_so_id IS NOT NULL THEN
        SELECT sale_order_no INTO v_so_no
        FROM "SalesOrders"
        WHERE id = v_so_id;
        
        RAISE NOTICE '✅ SalesOrder already exists: % (%)', v_so_no, v_so_id;
        RETURN;
    END IF;
    
    -- Asegurar que el quote esté aprobado
    IF v_quote_record.status::text ILIKE 'approved' = false THEN
        RAISE NOTICE '⚠️  Quote is not approved. Approving now...';
        UPDATE "Quotes"
        SET status = 'approved'::quote_status,
            updated_at = now()
        WHERE id = v_quote_record.id;
    END IF;
    
    -- Llamar función para crear SalesOrder
    RAISE NOTICE '🔧 Calling ensure_sales_order_for_approved_quote...';
    
    BEGIN
        v_so_id := public.ensure_sales_order_for_approved_quote(v_quote_record.id);
        
        IF v_so_id IS NOT NULL THEN
            SELECT sale_order_no INTO v_so_no
            FROM "SalesOrders"
            WHERE id = v_so_id;
            
            RAISE NOTICE '✅ SUCCESS! SalesOrder created: % (%)', v_so_no, v_so_id;
        ELSE
            RAISE WARNING '⚠️  Function returned NULL';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error: %', SQLERRM;
            RAISE WARNING '   Error Code: %', SQLSTATE;
    END;
END $$;

-- Paso 3: Verificación final
SELECT 
    'Verificación Final' as info,
    q.quote_no,
    q.status,
    so.id as sales_order_id,
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ STILL MISSING - Check logs above'
        ELSE '✅ CREATED SUCCESSFULLY'
    END as result
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;


