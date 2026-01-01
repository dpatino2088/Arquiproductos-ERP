-- ====================================================
-- Test Script FÁCIL: Probar Trigger Quote Approved
-- ====================================================
-- Este script te permite probar el trigger de forma más fácil
-- ====================================================

-- ====================================================
-- OPCIÓN 1: Aprobar la Quote más reciente automáticamente
-- ====================================================
-- Esta query aprueba la Quote más reciente que no esté aprobada
-- y que tenga al menos una línea

DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text;
BEGIN
    -- Encontrar la Quote más reciente sin aprobar
    SELECT q.id, q.quote_no INTO v_quote_id, v_quote_no
    FROM "Quotes" q
    WHERE q.deleted = false
    AND q.status != 'approved'
    AND (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) > 0
    ORDER BY q.created_at DESC
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ No se encontró ninguna Quote para aprobar';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Quote encontrada: % (%)', v_quote_no, v_quote_id;
    
    -- Verificar si ya tiene SalesOrder
    IF EXISTS (
        SELECT 1 FROM "SalesOrders" so 
        WHERE so.quote_id = v_quote_id 
        AND so.deleted = false
    ) THEN
        RAISE NOTICE '⚠️  Esta Quote ya tiene un SalesOrder. No se creará uno nuevo.';
    ELSE
        RAISE NOTICE '✅ Quote no tiene SalesOrder. Aprobando...';
    END IF;
    
    -- Aprobar la Quote
    UPDATE "Quotes"
    SET status = 'approved',
        updated_at = NOW()
    WHERE id = v_quote_id
    AND deleted = false
    AND status != 'approved';
    
    RAISE NOTICE '✅ Quote % aprobada. El trigger debería haber creado el SalesOrder.', v_quote_no;
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Ahora ejecuta la query de verificación con este ID: %', v_quote_id;
END $$;

-- ====================================================
-- OPCIÓN 2: Verificar el resultado (ejecuta esto después de la OPCIÓN 1)
-- ====================================================
-- Reemplaza <quote_id> con el ID que te mostró la query anterior

SELECT 
    'Quote' as tipo,
    q.quote_no as numero,
    q.status,
    q.created_at,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count
FROM "Quotes" q
WHERE q.id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID QUE TE MOSTRÓ LA QUERY ANTERIOR

UNION ALL

SELECT 
    'SalesOrder',
    so.sale_order_no,
    so.status,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL MISMO ID
AND so.deleted = false

ORDER BY created_at;

-- ====================================================
-- OPCIÓN 3: Verificar SalesOrder creado (query completa)
-- ====================================================
-- Reemplaza <quote_id> con el ID de la Quote que aprobaste

SELECT 
    so.id as sales_order_id,
    so.sale_order_no,
    so.status,
    so.quote_id,
    so.subtotal,
    so.tax,
    so.total,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count,
    (SELECT COUNT(*) FROM "BomInstances" bi 
     INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     WHERE sol.sale_order_id = so.id AND bi.deleted = false) as bom_instance_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- ⚠️ REEMPLAZA CON EL ID
AND so.deleted = false;

-- ====================================================
-- OPCIÓN 4: Ver todas las Quotes disponibles con sus IDs
-- ====================================================
-- Esta query te muestra todas las Quotes disponibles con sus IDs
-- para que puedas elegir cuál aprobar manualmente

SELECT 
    q.id,
    q.quote_no,
    q.status,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count,
    q.created_at,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM "SalesOrders" so 
            WHERE so.quote_id = q.id 
            AND so.deleted = false
        ) THEN '✅ Ya tiene SalesOrder'
        ELSE '❌ Sin SalesOrder - LISTA PARA PROBAR'
    END as estado
FROM "Quotes" q
WHERE q.deleted = false
AND q.status != 'approved'
AND (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) > 0
ORDER BY q.created_at DESC
LIMIT 10;

-- ====================================================
-- OPCIÓN 5: Aprobar una Quote específica por quote_no
-- ====================================================
-- Si prefieres usar el quote_no en lugar del ID
-- Reemplaza 'QT-000036' con el número de Quote que quieras aprobar

DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text := 'QT-000036';  -- ⚠️ CAMBIA ESTE NÚMERO
BEGIN
    -- Buscar Quote por número
    SELECT q.id, q.quote_no INTO v_quote_id, v_quote_no
    FROM "Quotes" q
    WHERE q.quote_no = v_quote_no
    AND q.deleted = false
    AND q.status != 'approved';
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE '❌ Quote % no encontrada o ya está aprobada', v_quote_no;
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Aprobando Quote: % (%)', v_quote_no, v_quote_id;
    
    -- Aprobar la Quote
    UPDATE "Quotes"
    SET status = 'approved',
        updated_at = NOW()
    WHERE id = v_quote_id;
    
    RAISE NOTICE '✅ Quote % aprobada exitosamente', v_quote_no;
    RAISE NOTICE '🔍 ID de la Quote: %', v_quote_id;
    RAISE NOTICE '   Usa este ID para las queries de verificación';
END $$;




