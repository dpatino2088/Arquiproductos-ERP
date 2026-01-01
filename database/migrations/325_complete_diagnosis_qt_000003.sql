-- ====================================================
-- Migration 325: Complete Diagnosis for QT-000003
-- ====================================================
-- Diagnóstico completo paso a paso
-- ====================================================

-- PASO 1: Verificar Quote existe y su estado
SELECT 
    'PASO 1: Quote Info' as step,
    q.id,
    q.quote_no,
    q.status,
    q.status::text as status_text,
    q.organization_id,
    q.customer_id,
    q.deleted,
    q.updated_at,
    CASE 
        WHEN q.status::text ILIKE 'approved' THEN '✅ Approved'
        ELSE '❌ Not approved: ' || q.status::text
    END as status_check
FROM "Quotes" q
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;

-- PASO 2: Verificar si SalesOrder existe
SELECT 
    'PASO 2: SalesOrder Check' as step,
    so.id as sales_order_id,
    so.sale_order_no,
    so.status as so_status,
    so.created_at,
    so.deleted
FROM "SalesOrders" so
WHERE so.quote_id IN (
    SELECT id FROM "Quotes" WHERE quote_no = 'QT-000003' AND deleted = false
)
AND so.deleted = false;

-- PASO 3: Verificar trigger está habilitado
SELECT 
    'PASO 3: Trigger Status' as step,
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE '⚠️ ' || tgenabled::text
    END as trigger_status
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';

-- PASO 4: Verificar función existe
SELECT 
    'PASO 4: Function Exists' as step,
    proname,
    CASE 
        WHEN prosrc IS NOT NULL THEN '✅ Function exists'
        ELSE '❌ Function missing'
    END as function_status
FROM pg_proc
WHERE proname = 'ensure_sales_order_for_approved_quote';

-- PASO 5: Test manual de la función
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text := 'QT-000003';
    v_so_id uuid;
    v_error_text text;
BEGIN
    -- Obtener quote_id
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE quote_no = v_quote_no
    AND deleted = false
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ PASO 5: Quote % not found', v_quote_no;
        RETURN;
    END IF;
    
    RAISE NOTICE '🔍 PASO 5: Testing ensure_sales_order_for_approved_quote for Quote % (%)', v_quote_no, v_quote_id;
    
    -- Llamar función
    BEGIN
        v_so_id := public.ensure_sales_order_for_approved_quote(v_quote_id);
        
        IF v_so_id IS NOT NULL THEN
            DECLARE
                v_so_no text;
            BEGIN
                SELECT sale_order_no INTO v_so_no
                FROM "SalesOrders"
                WHERE id = v_so_id;
                
                RAISE NOTICE '✅ PASO 5: Function SUCCESS - SalesOrder: % (%)', v_so_no, v_so_id;
            END;
        ELSE
            RAISE WARNING '⚠️  PASO 5: Function returned NULL';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_error_text := SQLERRM;
            RAISE WARNING '❌ PASO 5: Function FAILED - Error: %', v_error_text;
            RAISE WARNING '   Error Code: %', SQLSTATE;
    END;
END $$;

-- PASO 6: Verificar unique index
SELECT 
    'PASO 6: Unique Index' as step,
    indexname,
    CASE 
        WHEN indexname IS NOT NULL THEN '✅ Index exists'
        ELSE '❌ Index missing'
    END as index_status
FROM pg_indexes
WHERE tablename = 'SalesOrders'
AND indexname = 'ux_salesorders_org_quote_active';

-- PASO 7: Resumen final
SELECT 
    'PASO 7: Summary' as step,
    q.quote_no,
    q.status::text as quote_status,
    CASE 
        WHEN q.status::text ILIKE 'approved' AND so.id IS NULL THEN '❌ PROBLEM: Approved but no SO'
        WHEN q.status::text ILIKE 'approved' AND so.id IS NOT NULL THEN '✅ OK: Has SO'
        WHEN q.status::text ILIKE 'approved' = false THEN '⚠️  Not approved'
        ELSE '❓ Unknown'
    END as final_status,
    so.id as sales_order_id,
    so.sale_order_no
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;


