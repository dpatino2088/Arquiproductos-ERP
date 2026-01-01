-- ====================================================
-- Verificación Final: SalesOrders y Trigger
-- ====================================================
-- Este script verifica que todo esté funcionando correctamente
-- ====================================================

-- 1. Verificar que todos los Quotes aprobados tengan SalesOrders
SELECT 
    'Quotes Aprobados' as categoria,
    COUNT(*) as total
FROM "Quotes"
WHERE status = 'approved' AND deleted = false
UNION ALL
SELECT 
    'SalesOrders para Quotes Aprobados' as categoria,
    COUNT(DISTINCT so.id) as total
FROM "Quotes" q
INNER JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved' AND q.deleted = false
UNION ALL
SELECT 
    'Quotes sin SalesOrders' as categoria,
    COUNT(*) as total
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved' 
AND q.deleted = false
AND so.id IS NULL;

-- 2. Lista completa de Quotes aprobados y sus SalesOrders
SELECT 
    q.quote_no,
    q.status as quote_status,
    so.sale_order_no,
    so.status as so_status,
    so.order_progress_status,
    dc.customer_name,
    so.total,
    so.created_at as so_created_at,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing'
        ELSE '✅ OK'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
LEFT JOIN "DirectoryCustomers" dc ON dc.id = q.customer_id
WHERE q.status = 'approved' AND q.deleted = false
ORDER BY q.created_at DESC;

-- 3. Verificar trigger está activo
SELECT 
    'Trigger Status' as check_item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'trg_on_quote_approved_create_operational_docs'
            AND tgrelid = '"Quotes"'::regclass
        ) THEN '✅ ACTIVE'
        ELSE '❌ NOT FOUND'
    END as status;

-- 4. Verificar función usa tabla correcta
SELECT 
    'Function Table Name' as check_item,
    CASE 
        WHEN pg_get_functiondef(oid) LIKE '%"SalesOrders"%' 
        AND pg_get_functiondef(oid) NOT LIKE '%"SaleOrders"%' THEN '✅ Correct (SalesOrders)'
        WHEN pg_get_functiondef(oid) LIKE '%"SaleOrders"%' THEN '❌ Wrong (SaleOrders singular)'
        ELSE '⚠️ Cannot verify'
    END as status
FROM pg_proc 
WHERE proname = 'on_quote_approved_create_operational_docs'
AND pronamespace = 'public'::regnamespace;






