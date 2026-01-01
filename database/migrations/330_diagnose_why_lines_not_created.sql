-- ====================================================
-- Migration 330: Diagnose Why SalesOrderLines Not Created
-- ====================================================
-- Diagnóstico para entender por qué no se crearon las líneas
-- ====================================================

-- PASO 1: Verificar si existen QuoteLines para estos SalesOrders
SELECT 
    'PASO 1: QuoteLines for SalesOrders without lines' as step,
    so.id as sales_order_id,
    so.sale_order_no,
    so.quote_id,
    COUNT(ql.id) as quote_lines_count,
    CASE 
        WHEN COUNT(ql.id) = 0 THEN '❌ NO QUOTE LINES'
        ELSE '✅ Has ' || COUNT(ql.id) || ' QuoteLine(s)'
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

-- PASO 2: Verificar estructura de QuoteLines (para entender qué columnas tenemos)
SELECT 
    'PASO 2: Sample QuoteLine structure' as step,
    ql.id,
    ql.quote_id,
    ql.qty,
    ql.width_m,
    ql.height_m,
    ql.organization_id,
    ql.product_type,
    ql.drive_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.tube_type,
    ql.operating_system_variant
FROM "QuoteLines" ql
WHERE ql.quote_id IN (
    SELECT DISTINCT so.quote_id
    FROM "SalesOrders" so
    WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = so.id AND sol.deleted = false
    )
)
AND ql.deleted = false
LIMIT 5;

-- PASO 3: Intentar crear UNA línea manualmente para ver el error exacto
DO $$
DECLARE
    v_so_id uuid := '0b9143a3-b69b-4e15-a2dd-6b10028963e9'; -- SO-090156
    v_ql_id uuid;
    v_line_number integer;
    v_so_line_id uuid;
    v_org_id uuid;
BEGIN
    -- Obtener organization_id del SalesOrder
    SELECT organization_id INTO v_org_id
    FROM "SalesOrders"
    WHERE id = v_so_id;
    
    RAISE NOTICE 'Testing with SalesOrder % (org: %)', v_so_id, v_org_id;
    
    -- Obtener primer QuoteLine
    SELECT id INTO v_ql_id
    FROM "QuoteLines"
    WHERE quote_id = (
        SELECT quote_id FROM "SalesOrders" WHERE id = v_so_id
    )
    AND deleted = false
    ORDER BY created_at
    LIMIT 1;
    
    IF v_ql_id IS NULL THEN
        RAISE NOTICE '❌ No QuoteLine found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found QuoteLine: %', v_ql_id;
    
    -- Get line number
    SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_so_id;
    
    RAISE NOTICE 'Line number: %', v_line_number;
    
    -- Try to insert (minimal columns first to see if it works)
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
            1,
            v_org_id,
            false,
            now(),
            now()
        ) RETURNING id INTO v_so_line_id;
        
        RAISE NOTICE '✅ SUCCESS! Created SalesOrderLine: %', v_so_line_id;
        
        -- Rollback for testing
        ROLLBACK;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ ERROR: %', SQLERRM;
            RAISE NOTICE '   SQLSTATE: %', SQLSTATE;
    END;
END $$;


