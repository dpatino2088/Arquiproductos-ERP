-- ====================================================
-- Diagnóstico: Por qué no se crean SalesOrderLines (CORREGIDO)
-- ====================================================
-- Ejecutar en Supabase SQL Editor para diagnosticar
-- ====================================================

-- PASO 1: Verificar si existen QuoteLines para los SalesOrders sin líneas
SELECT 
    'PASO 1: QuoteLines disponibles' as info,
    so.sale_order_no,
    so.id as sales_order_id,
    so.quote_id,
    COUNT(ql.id) as quote_lines_count,
    CASE 
        WHEN COUNT(ql.id) = 0 THEN '❌ NO HAY QUOTE LINES'
        ELSE '✅ Tiene ' || COUNT(ql.id) || ' QuoteLine(s)'
    END as status
FROM "SalesOrders" so
LEFT JOIN "QuoteLines" ql ON ql.quote_id = so.quote_id AND ql.deleted = false
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
)
GROUP BY so.id, so.sale_order_no, so.quote_id
ORDER BY so.created_at;

-- PASO 2: Intentar crear UNA línea manualmente para ver el error
DO $$
DECLARE
    v_so_id uuid;
    v_so_no text;
    v_quote_id uuid;
    v_ql_id uuid;
    v_org_id uuid;
    v_line_number integer;
    v_so_line_id uuid;
    v_error_text text;
    v_ql_qty numeric;
BEGIN
    -- Tomar el primer SalesOrder sin líneas
    SELECT so.id, so.sale_order_no, so.quote_id, so.organization_id
    INTO v_so_id, v_so_no, v_quote_id, v_org_id
    FROM "SalesOrders" so
    WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = so.id AND sol.deleted = false
    )
    ORDER BY so.created_at
    LIMIT 1;
    
    IF v_so_id IS NULL THEN
        RAISE NOTICE '✅ No hay SalesOrders sin líneas';
        RETURN;
    END IF;
    
    RAISE NOTICE '🔍 Probando con SalesOrder: % (%)', v_so_no, v_so_id;
    RAISE NOTICE '   Quote ID: %', v_quote_id;
    RAISE NOTICE '   Organization ID: %', v_org_id;
    
    -- Obtener primer QuoteLine
    SELECT id, qty INTO v_ql_id, v_ql_qty
    FROM "QuoteLines"
    WHERE quote_id = v_quote_id
    AND deleted = false
    ORDER BY created_at
    LIMIT 1;
    
    IF v_ql_id IS NULL THEN
        RAISE NOTICE '❌ PROBLEMA: No hay QuoteLines para este Quote';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ QuoteLine encontrado: % (qty: %)', v_ql_id, v_ql_qty;
    
    -- Get line number
    SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_so_id;
    
    RAISE NOTICE '   Line number: %', v_line_number;
    
    -- Intentar crear con columnas mínimas
    BEGIN
        INSERT INTO "SalesOrderLines" (
            sale_order_id,
            quote_line_id,
            line_number,
            qty,
            organization_id,
            deleted,
            created_at,
            updated_at
        ) VALUES (
            v_so_id,
            v_ql_id,
            v_line_number,
            COALESCE(v_ql_qty, 1),
            v_org_id,
            false,
            now(),
            now()
        ) RETURNING id INTO v_so_line_id;
        
        RAISE NOTICE '✅ SUCCESS! SalesOrderLine creado: %', v_so_line_id;
        
        -- Rollback para testing (comentar si quieres que se cree realmente)
        -- ROLLBACK;
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_text := SQLERRM;
            RAISE NOTICE '❌ ERROR al crear SalesOrderLine:';
            RAISE NOTICE '   Mensaje: %', v_error_text;
            RAISE NOTICE '   Código: %', SQLSTATE;
    END;
END $$;


