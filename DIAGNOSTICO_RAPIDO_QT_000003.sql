-- ====================================================
-- Diagnóstico Rápido: QT-000003
-- ====================================================
-- Ejecutar este script en Supabase SQL Editor
-- ====================================================

-- 1. Verificar Quote y SalesOrder
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.organization_id,
    q.updated_at as quote_updated,
    so.id as sales_order_id,
    so.sale_order_no,
    so.created_at as so_created,
    CASE 
        WHEN q.status::text ILIKE 'approved' AND so.id IS NULL THEN '❌ PROBLEM: Approved but no SO'
        WHEN q.status::text ILIKE 'approved' AND so.id IS NOT NULL THEN '✅ OK: Has SO'
        ELSE 'ℹ️ Status: ' || q.status::text
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;

-- 2. Verificar trigger habilitado
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled - THIS IS THE PROBLEM!'
        ELSE '⚠️ ' || tgenabled::text
    END as trigger_status
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';

-- 3. Forzar creación de SalesOrder (si no existe)
DO $$
DECLARE
    v_quote_id uuid;
    v_so_id uuid;
BEGIN
    -- Obtener quote_id
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE quote_no = 'QT-000003'
    AND deleted = false
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ Quote QT-000003 not found';
        RETURN;
    END IF;
    
    -- Verificar si ya existe
    SELECT so.id INTO v_so_id
    FROM "SalesOrders" so
    WHERE so.quote_id = v_quote_id
    AND so.deleted = false
    LIMIT 1;
    
    IF v_so_id IS NOT NULL THEN
        RAISE NOTICE '✅ SalesOrder already exists for QT-000003';
        RETURN;
    END IF;
    
    -- Llamar función para crear
    RAISE NOTICE '🔧 Creating SalesOrder for QT-000003...';
    v_so_id := public.ensure_sales_order_for_approved_quote(v_quote_id);
    
    IF v_so_id IS NOT NULL THEN
        DECLARE
            v_so_no text;
        BEGIN
            SELECT sale_order_no INTO v_so_no
            FROM "SalesOrders"
            WHERE id = v_so_id;
            
            RAISE NOTICE '✅ SalesOrder created: % (%)', v_so_no, v_so_id;
        END;
    ELSE
        RAISE WARNING '⚠️  Function returned NULL';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error: %', SQLERRM;
END $$;

-- 4. Verificación final
SELECT 
    q.quote_no,
    q.status,
    so.sale_order_no,
    CASE 
        WHEN so.id IS NULL THEN '❌ STILL MISSING'
        ELSE '✅ CREATED'
    END as result
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;


