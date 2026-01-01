-- ====================================================
-- Test: Crear UNA línea y mostrar resultados en tabla
-- ====================================================
-- Este script intenta crear una línea y muestra el resultado
-- ====================================================

-- Crear tabla temporal para resultados
CREATE TEMP TABLE IF NOT EXISTS test_results (
    step text,
    status text,
    message text,
    sales_order_line_id uuid
);

TRUNCATE TABLE test_results;

DO $$
DECLARE
    v_so_id uuid;
    v_so_no text;
    v_ql_id uuid;
    v_line_id uuid;
    v_line_number integer;
    v_org_id uuid;
    v_error_text text;
BEGIN
    -- Tomar el primer SalesOrder sin líneas
    SELECT so.id, so.sale_order_no, so.organization_id
    INTO v_so_id, v_so_no, v_org_id
    FROM "SalesOrders" so
    WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = so.id AND sol.deleted = false
    )
    ORDER BY so.created_at
    LIMIT 1;
    
    IF v_so_id IS NULL THEN
        INSERT INTO test_results VALUES ('Check', 'SKIP', 'No SalesOrders without lines', NULL);
        RETURN;
    END IF;
    
    INSERT INTO test_results VALUES ('Step 1', 'INFO', 'Testing with SalesOrder: ' || v_so_no, NULL);
    
    -- Obtener primer QuoteLine
    SELECT ql.id INTO v_ql_id
    FROM "QuoteLines" ql
    WHERE ql.quote_id = (SELECT quote_id FROM "SalesOrders" WHERE id = v_so_id)
    AND ql.deleted = false
    ORDER BY ql.created_at
    LIMIT 1;
    
    IF v_ql_id IS NULL THEN
        INSERT INTO test_results VALUES ('Step 2', 'ERROR', 'No QuoteLine found', NULL);
        RETURN;
    END IF;
    
    INSERT INTO test_results VALUES ('Step 2', 'INFO', 'QuoteLine found: ' || v_ql_id::text, NULL);
    
    -- Get line number
    SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_so_id;
    
    INSERT INTO test_results VALUES ('Step 3', 'INFO', 'Line number: ' || v_line_number::text, NULL);
    
    -- INTENTO 1: Solo columnas mínimas
    BEGIN
        INSERT INTO "SalesOrderLines" (
            sale_order_id,
            quote_line_id,
            line_number,
            organization_id,
            deleted,
            created_at,
            updated_at
        ) VALUES (
            v_so_id,
            v_ql_id,
            v_line_number,
            v_org_id,
            false,
            now(),
            now()
        ) RETURNING id INTO v_line_id;
        
        INSERT INTO test_results VALUES ('Attempt 1', 'SUCCESS', 'Created SalesOrderLine with minimal columns', v_line_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_text := SQLERRM;
            INSERT INTO test_results VALUES ('Attempt 1', 'FAILED', 'Error: ' || v_error_text || ' (SQLSTATE: ' || SQLSTATE || ')', NULL);
            
            -- INTENTO 2: Con qty
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
                )
                SELECT 
                    v_so_id,
                    v_ql_id,
                    v_line_number,
                    COALESCE(ql.qty, 1),
                    v_org_id,
                    false,
                    now(),
                    now()
                FROM "QuoteLines" ql
                WHERE ql.id = v_ql_id
                RETURNING id INTO v_line_id;
                
                INSERT INTO test_results VALUES ('Attempt 2', 'SUCCESS', 'Created SalesOrderLine with qty', v_line_id);
                
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_text := SQLERRM;
                    INSERT INTO test_results VALUES ('Attempt 2', 'FAILED', 'Error: ' || v_error_text || ' (SQLSTATE: ' || SQLSTATE || ')', NULL);
            END;
    END;
END $$;

-- Mostrar resultados
SELECT 
    step,
    status,
    message,
    sales_order_line_id
FROM test_results
ORDER BY 
    CASE step
        WHEN 'Check' THEN 1
        WHEN 'Step 1' THEN 2
        WHEN 'Step 2' THEN 3
        WHEN 'Step 3' THEN 4
        WHEN 'Attempt 1' THEN 5
        WHEN 'Attempt 2' THEN 6
        ELSE 7
    END;


