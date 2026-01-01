-- ====================================================
-- Verificación: Quotes Aprobados y sus SalesOrders
-- ====================================================

-- Opción 1: Verificar un Quote específico por quote_no
-- (Reemplazar 'QT-000003' con el quote_no que quieres verificar)
SELECT 
    q.id, 
    q.quote_no, 
    q.status, 
    q.updated_at as quote_updated,
    so.id as sales_order_id, 
    so.sale_order_no,
    so.status as so_status,
    so.created_at as so_created,
    CASE 
        WHEN so.id IS NULL THEN '❌ PROBLEM: No SalesOrder'
        ELSE '✅ OK: SalesOrder exists'
    END as verification
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'  -- ⚠️ CAMBIAR POR TU QUOTE_NO
AND q.deleted = false;

-- Opción 2: Verificar TODOS los quotes aprobados (más fácil, no requiere quote_id)
SELECT 
    q.id, 
    q.quote_no, 
    q.status, 
    q.updated_at as quote_updated,
    so.id as sales_order_id, 
    so.sale_order_no,
    so.status as so_status,
    so.created_at as so_created,
    CASE 
        WHEN so.id IS NULL THEN '❌ PROBLEM: No SalesOrder'
        ELSE '✅ OK: SalesOrder exists'
    END as verification
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status::text ILIKE 'approved'
AND q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 10;

-- Opción 3: Resumen rápido (solo cuenta)
SELECT 
    COUNT(*) FILTER (WHERE q.status::text ILIKE 'approved') as total_approved,
    COUNT(*) FILTER (WHERE q.status::text ILIKE 'approved' AND so.id IS NOT NULL) as approved_with_so,
    COUNT(*) FILTER (WHERE q.status::text ILIKE 'approved' AND so.id IS NULL) as approved_without_so,
    CASE 
        WHEN COUNT(*) FILTER (WHERE q.status::text ILIKE 'approved' AND so.id IS NULL) = 0 
        THEN '✅ All approved quotes have SalesOrders'
        ELSE '⚠️ Some approved quotes are missing SalesOrders'
    END as overall_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.deleted = false;


