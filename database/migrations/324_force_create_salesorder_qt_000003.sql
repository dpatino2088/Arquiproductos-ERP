-- ====================================================
-- Migration 324: Force Create SalesOrder for QT-000003
-- ====================================================
-- Si el trigger no funcionó, este script fuerza la creación del SalesOrder
-- ====================================================

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
        RAISE EXCEPTION 'Quote % not found', v_quote_no;
    END IF;
    
    RAISE NOTICE '🔍 Found Quote % (%)', v_quote_no, v_quote_id;
    
    -- Verificar status
    DECLARE
        v_status text;
        v_org_id uuid;
    BEGIN
        SELECT status::text, organization_id INTO v_status, v_org_id
        FROM "Quotes"
        WHERE id = v_quote_id;
        
        RAISE NOTICE '  Status: %', v_status;
        RAISE NOTICE '  Organization ID: %', v_org_id;
        
        IF v_status::text ILIKE 'approved' = false THEN
            RAISE WARNING '⚠️  Quote is not approved. Current status: %', v_status;
            RAISE NOTICE '  Attempting to approve quote first...';
            
            -- Aprobar el quote primero
            UPDATE "Quotes"
            SET status = 'approved'::quote_status,
                updated_at = now()
            WHERE id = v_quote_id;
            
            RAISE NOTICE '✅ Quote approved';
        END IF;
    END;
    
    -- Verificar si SalesOrder ya existe
    SELECT so.id INTO v_so_id
    FROM "SalesOrders" so
    WHERE so.quote_id = v_quote_id
    AND so.deleted = false
    LIMIT 1;
    
    IF v_so_id IS NOT NULL THEN
        DECLARE
            v_so_no text;
        BEGIN
            SELECT sale_order_no INTO v_so_no
            FROM "SalesOrders"
            WHERE id = v_so_id;
            
            RAISE NOTICE '✅ SalesOrder already exists: % (%)', v_so_no, v_so_id;
            RETURN;
        END;
    END IF;
    
    -- Llamar función ensure_sales_order_for_approved_quote
    RAISE NOTICE '🔧 Calling ensure_sales_order_for_approved_quote...';
    
    BEGIN
        v_so_id := public.ensure_sales_order_for_approved_quote(v_quote_id);
        
        IF v_so_id IS NOT NULL THEN
            DECLARE
                v_so_no text;
            BEGIN
                SELECT sale_order_no INTO v_so_no
                FROM "SalesOrders"
                WHERE id = v_so_id;
                
                RAISE NOTICE '✅ SalesOrder created successfully: % (%)', v_so_no, v_so_id;
            END;
        ELSE
            RAISE EXCEPTION 'Function returned NULL - check function implementation';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error calling ensure_sales_order_for_approved_quote: %', SQLERRM;
    END;
END $$;

-- Verificación final
SELECT 
    q.id,
    q.quote_no,
    q.status,
    so.id as sales_order_id,
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ PROBLEM: No SalesOrder'
        ELSE '✅ OK: SalesOrder exists'
    END as verification
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;


