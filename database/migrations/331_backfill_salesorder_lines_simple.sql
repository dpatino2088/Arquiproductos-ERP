-- ====================================================
-- Migration 331: Backfill SalesOrderLines (Simplified)
-- ====================================================
-- Versión simplificada que muestra errores claramente
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
BEGIN
    RAISE NOTICE '🔧 Backfilling missing SalesOrderLines (Simplified)...';
    
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
    
    RAISE NOTICE '  Found % SalesOrder(s) without lines', v_total_sos;
    
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
        RAISE NOTICE '';
        RAISE NOTICE '  📦 Processing SalesOrder: % (%)', v_so.sale_order_no, v_so.id;
        RAISE NOTICE '     Quote ID: %', v_so.quote_id;
        
        -- Verificar si hay QuoteLines
        FOR v_ql IN
            SELECT id, qty, width_m, height_m, area, position
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
                RAISE NOTICE '     ⏭️  Line already exists for QuoteLine %', v_ql.id;
                CONTINUE;
            END IF;
            
            -- Get line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND deleted = false;
            
            RAISE NOTICE '     📝 Creating line % for QuoteLine %', v_line_number, v_ql.id;
            
            -- Intentar insert con columnas básicas
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
                    v_so.organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_so_line_id;
                
                v_created_count := v_created_count + 1;
                RAISE NOTICE '     ✅ Created SalesOrderLine: %', v_so_line_id;
                
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    RAISE NOTICE '     ❌ ERROR: %', SQLERRM;
                    RAISE NOTICE '        SQLSTATE: %', SQLSTATE;
                    -- Continuar con el siguiente
            END;
        END LOOP;
        
        -- Si no encontró QuoteLines
        IF NOT FOUND THEN
            RAISE NOTICE '     ⚠️  WARNING: No QuoteLines found for this Quote';
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Backfill complete:';
    RAISE NOTICE '   - Processed: % SalesOrder(s)', v_total_sos;
    RAISE NOTICE '   - Created: % SalesOrderLine(s)', v_created_count;
    RAISE NOTICE '   - Errors: %', v_error_count;
END $$;

-- Verificación final
SELECT 
    'Verificación Final' as check_name,
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


