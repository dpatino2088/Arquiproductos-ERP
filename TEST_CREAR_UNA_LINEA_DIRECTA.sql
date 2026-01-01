-- ====================================================
-- Test: Crear UNA línea directamente para ver error
-- ====================================================
-- Este script intenta crear UNA línea y muestra el error exacto
-- ====================================================

DO $$
DECLARE
    v_so_id uuid;
    v_ql_id uuid;
    v_line_id uuid;
    v_line_number integer;
    v_org_id uuid;
    v_error_text text;
BEGIN
    -- Tomar el primer SalesOrder sin líneas
    SELECT so.id, so.organization_id
    INTO v_so_id, v_org_id
    FROM "SalesOrders" so
    WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = so.id AND sol.deleted = false
    )
    ORDER BY so.created_at
    LIMIT 1;
    
    RAISE NOTICE 'Testing with SalesOrder: %', v_so_id;
    
    -- Obtener primer QuoteLine
    SELECT ql.id INTO v_ql_id
    FROM "QuoteLines" ql
    WHERE ql.quote_id = (SELECT quote_id FROM "SalesOrders" WHERE id = v_so_id)
    AND ql.deleted = false
    ORDER BY ql.created_at
    LIMIT 1;
    
    RAISE NOTICE 'QuoteLine: %', v_ql_id;
    
    -- Get line number
    SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_so_id;
    
    RAISE NOTICE 'Line number: %', v_line_number;
    
    -- INTENTO 1: Solo columnas mínimas requeridas
    BEGIN
        RAISE NOTICE 'Attempt 1: Minimal columns...';
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
        
        RAISE NOTICE '✅ SUCCESS! Created: %', v_line_id;
        -- Rollback para testing
        ROLLBACK;
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_text := SQLERRM;
            RAISE NOTICE '❌ Attempt 1 FAILED: %', v_error_text;
            RAISE NOTICE '   SQLSTATE: %', SQLSTATE;
    END;
    
    -- Si Attempt 1 falló, intentar con qty
    IF v_line_id IS NULL THEN
        BEGIN
            RAISE NOTICE 'Attempt 2: Adding qty...';
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
            
            RAISE NOTICE '✅ SUCCESS! Created: %', v_line_id;
            -- Rollback para testing
            ROLLBACK;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_error_text := SQLERRM;
                RAISE NOTICE '❌ Attempt 2 FAILED: %', v_error_text;
                RAISE NOTICE '   SQLSTATE: %', SQLSTATE;
        END;
    END IF;
    
END $$;


