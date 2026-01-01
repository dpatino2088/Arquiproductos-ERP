-- ====================================================
-- Migration 327: Fix Missing sale_order_no
-- ====================================================
-- Diagnóstico y corrección de SalesOrders sin sale_order_no
-- ====================================================

-- PASO 1: Identificar SalesOrders sin sale_order_no
SELECT 
    'SalesOrders sin sale_order_no' as diagnosis,
    id,
    sale_order_no,
    quote_id,
    organization_id,
    status,
    created_at
FROM "SalesOrders"
WHERE deleted = false
AND (sale_order_no IS NULL OR sale_order_no = '');

-- PASO 2: Corregir SalesOrders sin sale_order_no
DO $$
DECLARE
    v_so RECORD;
    v_next_counter integer;
    v_sale_order_no text;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Fixing SalesOrders without sale_order_no...';
    
    FOR v_so IN
        SELECT 
            so.id,
            so.organization_id,
            so.quote_id
        FROM "SalesOrders" so
        WHERE so.deleted = false
        AND (so.sale_order_no IS NULL OR so.sale_order_no = '')
        ORDER BY so.created_at
    LOOP
        BEGIN
            -- Generate sale_order_no
            BEGIN
                -- Try using counter function
                v_next_counter := public.get_next_counter_value(
                    v_so.organization_id, 
                    'sale_order'
                );
                v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Error generating sale_order_no via counter: %, using fallback', SQLERRM;
                    -- Fallback: use MAX + 1
                    SELECT COALESCE(
                        MAX(CAST(SUBSTRING(sale_order_no FROM 'SO-(\d+)') AS INTEGER)), 
                        0
                    ) + 1
                    INTO v_next_counter
                    FROM "SalesOrders"
                    WHERE organization_id = v_so.organization_id
                    AND sale_order_no ~ '^SO-\d+$'
                    AND sale_order_no IS NOT NULL;
                    
                    v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
            END;
            
            -- Update SalesOrder with sale_order_no
            UPDATE "SalesOrders"
            SET sale_order_no = v_sale_order_no,
                updated_at = now()
            WHERE id = v_so.id;
            
            v_count := v_count + 1;
            RAISE NOTICE '  ✅ Fixed SalesOrder %: %', v_so.id, v_sale_order_no;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Failed to fix SalesOrder %: %', v_so.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Fixed % SalesOrders', v_count;
END $$;

-- PASO 3: Verificación final
SELECT 
    'Verificación Final' as check_name,
    COUNT(*) as salesorders_without_no,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All SalesOrders have sale_order_no'
        ELSE '❌ Still missing sale_order_no'
    END as status
FROM "SalesOrders"
WHERE deleted = false
AND (sale_order_no IS NULL OR sale_order_no = '');


