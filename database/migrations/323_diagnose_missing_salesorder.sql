-- ====================================================
-- Migration 323: Diagnose Missing SalesOrder
-- ====================================================
-- Diagnóstico completo para identificar por qué no se crea SalesOrder
-- ====================================================

-- Query 1: Verificar quote específico (QT-000003)
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.status::text as status_text,
    q.updated_at,
    q.deleted,
    q.organization_id,
    so.id as sales_order_id,
    so.sale_order_no,
    so.created_at as so_created,
    CASE 
        WHEN q.status::text ILIKE 'approved' AND so.id IS NULL THEN '❌ PROBLEM: Approved but no SO'
        WHEN q.status::text ILIKE 'approved' AND so.id IS NOT NULL THEN '✅ OK: Has SO'
        ELSE 'ℹ️ Not approved'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;

-- Query 2: Verificar trigger está habilitado
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE '⚠️ ' || tgenabled::text
    END as trigger_status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';

-- Query 3: Verificar función ensure_sales_order_for_approved_quote existe
SELECT 
    proname,
    prosrc IS NOT NULL as has_source
FROM pg_proc
WHERE proname = 'ensure_sales_order_for_approved_quote';

-- Query 4: Test manual de ensure_sales_order_for_approved_quote
-- (Reemplazar <QUOTE_ID> con el ID real de QT-000003)
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text := 'QT-000003';
    v_so_id uuid;
BEGIN
    -- Obtener quote_id
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE quote_no = v_quote_no
    AND deleted = false
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ Quote % not found', v_quote_no;
        RETURN;
    END IF;
    
    RAISE NOTICE '🔍 Testing ensure_sales_order_for_approved_quote for Quote % (%)', v_quote_no, v_quote_id;
    
    -- Verificar status actual
    DECLARE
        v_current_status text;
    BEGIN
        SELECT status::text INTO v_current_status
        FROM "Quotes"
        WHERE id = v_quote_id;
        
        RAISE NOTICE '  Current status: %', v_current_status;
        
        IF v_current_status::text ILIKE 'approved' = false THEN
            RAISE NOTICE '⚠️  Quote is not approved. Current status: %', v_current_status;
        END IF;
    END;
    
    -- Llamar función
    BEGIN
        v_so_id := public.ensure_sales_order_for_approved_quote(v_quote_id);
        
        IF v_so_id IS NOT NULL THEN
            RAISE NOTICE '✅ Function returned SalesOrder ID: %', v_so_id;
            
            -- Verificar que existe
            DECLARE
                v_so_no text;
            BEGIN
                SELECT sale_order_no INTO v_so_no
                FROM "SalesOrders"
                WHERE id = v_so_id;
                
                RAISE NOTICE '✅ SalesOrder exists: % (%)', v_so_no, v_so_id;
            END;
        ELSE
            RAISE WARNING '⚠️  Function returned NULL';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error calling function: %', SQLERRM;
    END;
END $$;

-- Query 5: Verificar logs recientes del trigger
-- (Esto requiere acceso a Postgres Logs en Supabase Dashboard)
-- Ir a: Dashboard → Logs → Postgres Logs
-- Buscar: "🔔 Trigger on_quote_approved_create_operational_docs FIRED"

-- Query 6: Verificar si hay errores en la creación de SalesOrder
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.organization_id,
    COUNT(so.id) as sales_order_count
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false
GROUP BY q.id, q.quote_no, q.status, q.organization_id;

-- Query 7: Verificar unique index existe
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'SalesOrders'
AND indexname = 'ux_salesorders_org_quote_active';


