-- ====================================================
-- Migration 332: Backfill SalesOrderLines (Robust Version)
-- ====================================================
-- Versión robusta que maneja todos los casos y muestra errores claramente
-- ====================================================

DO $$
DECLARE
    v_so RECORD;
    v_ql RECORD;
    v_line_number integer;
    v_so_line_id uuid;
    v_created_count integer := 0;
    v_error_count integer := 0;
    v_total_sos integer := 0;
    v_error_text text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔧 Backfilling missing SalesOrderLines';
    RAISE NOTICE '========================================';
    
    -- Contar cuántos SalesOrders sin líneas
    SELECT COUNT(*) INTO v_total_sos
    FROM "SalesOrders" so
    WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = so.id
        AND sol.deleted = false
    );
    
    RAISE NOTICE 'Found % SalesOrder(s) without lines', v_total_sos;
    RAISE NOTICE '';
    
    FOR v_so IN
        SELECT 
            so.id, 
            so.quote_id, 
            so.organization_id,
            so.sale_order_no
        FROM "SalesOrders" so
        WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1
            FROM "SalesOrderLines" sol
            WHERE sol.sale_order_id = so.id
            AND sol.deleted = false
        )
        ORDER BY so.created_at
    LOOP
        RAISE NOTICE '📦 Processing: % (ID: %)', v_so.sale_order_no, v_so.id;
        RAISE NOTICE '   Quote ID: %', v_so.quote_id;
        RAISE NOTICE '   Org ID: %', v_so.organization_id;
        
        -- Verificar QuoteLines
        DECLARE
            v_ql_count integer := 0;
        BEGIN
            SELECT COUNT(*) INTO v_ql_count
            FROM "QuoteLines"
            WHERE quote_id = v_so.quote_id
            AND deleted = false;
            
            RAISE NOTICE '   QuoteLines found: %', v_ql_count;
            
            IF v_ql_count = 0 THEN
                RAISE WARNING '   ⚠️  SKIPPING: No QuoteLines for this Quote';
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
        END;
        
        -- Procesar cada QuoteLine
        FOR v_ql IN
            SELECT 
                id, 
                qty, 
                width_m, 
                height_m, 
                area, 
                position,
                product_type,
                product_type_id
            FROM "QuoteLines"
            WHERE quote_id = v_so.quote_id
            AND deleted = false
            ORDER BY created_at
        LOOP
            -- Verificar si ya existe
            SELECT id INTO v_so_line_id
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND quote_line_id = v_ql.id
            AND deleted = false;
            
            IF v_so_line_id IS NOT NULL THEN
                RAISE NOTICE '   ⏭️  Line already exists for QuoteLine %', v_ql.id;
                CONTINUE;
            END IF;
            
            -- Get line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND deleted = false;
            
            RAISE NOTICE '   📝 Creating line % for QuoteLine %', v_line_number, v_ql.id;
            
            -- Intentar insert con manejo de errores robusto
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sale_order_id,
                    quote_line_id,
                    line_number,
                    qty,
                    width_m,
                    height_m,
                    area,
                    position,
                    product_type,
                    product_type_id,
                    organization_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_so.id,
                    v_ql.id,
                    v_line_number,
                    COALESCE(v_ql.qty, 1),
                    v_ql.width_m,
                    v_ql.height_m,
                    v_ql.area,
                    v_ql.position,
                    v_ql.product_type,
                    v_ql.product_type_id,
                    v_so.organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_so_line_id;
                
                v_created_count := v_created_count + 1;
                RAISE NOTICE '   ✅ SUCCESS: Created SalesOrderLine %', v_so_line_id;
                
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_text := SQLERRM;
                    v_error_count := v_error_count + 1;
                    RAISE WARNING '   ❌ ERROR creating line for QuoteLine %:', v_ql.id;
                    RAISE WARNING '      Message: %', v_error_text;
                    RAISE WARNING '      SQLSTATE: %', SQLSTATE;
                    -- Continuar con el siguiente
            END;
        END LOOP;
        
        RAISE NOTICE '   ✅ Completed: %', v_so.sale_order_no;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Backfill Summary:';
    RAISE NOTICE '   Processed: % SalesOrder(s)', v_total_sos;
    RAISE NOTICE '   Created: % SalesOrderLine(s)', v_created_count;
    RAISE NOTICE '   Errors: %', v_error_count;
    RAISE NOTICE '========================================';
END $$;

-- Verificación final
SELECT 
    'Final Verification' as check_name,
    COUNT(*) as so_without_lines,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All SalesOrders have SalesOrderLines'
        ELSE '❌ ' || COUNT(*) || ' SalesOrder(s) still missing lines'
    END as status
FROM "SalesOrders" so
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
);


