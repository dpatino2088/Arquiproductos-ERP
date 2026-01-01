-- ====================================================
-- DIAGNÓSTICO: Estado de Quotes y SalesOrders
-- ====================================================
-- Script para verificar si los SalesOrders fueron creados
-- o si están eliminados

-- 1. Verificar Quotes aprobados recientes
SELECT 
    q.id as quote_id,
    q.quote_no,
    q.status as quote_status,
    q.created_at as quote_created_at,
    q.updated_at as quote_updated_at,
    COUNT(DISTINCT so.id) as sales_orders_count,
    COUNT(DISTINCT CASE WHEN so.deleted = false THEN so.id END) as active_sales_orders_count,
    COUNT(DISTINCT CASE WHEN so.deleted = true THEN so.id END) as deleted_sales_orders_count,
    STRING_AGG(DISTINCT so.sale_order_no, ', ') FILTER (WHERE so.deleted = false) as active_so_numbers,
    STRING_AGG(DISTINCT so.sale_order_no, ', ') FILTER (WHERE so.deleted = true) as deleted_so_numbers
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id
WHERE q.status = 'approved'
AND q.deleted = false
GROUP BY q.id, q.quote_no, q.status, q.created_at, q.updated_at
ORDER BY q.updated_at DESC NULLS LAST, q.created_at DESC
LIMIT 20;

-- 2. Verificar SalesOrders para QT-000023 específicamente
SELECT 
    q.id as quote_id,
    q.quote_no,
    q.status as quote_status,
    q.created_at as quote_created_at,
    q.updated_at as quote_updated_at,
    so.id as sales_order_id,
    so.sale_order_no,
    so.status as so_status,
    so.deleted,
    so.created_at as so_created_at,
    so.updated_at as so_updated_at
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id
WHERE q.quote_no = 'QT-000023'
ORDER BY so.created_at DESC;

-- 3. Verificar si hay SalesOrders eliminados recientes
SELECT 
    so.id,
    so.sale_order_no,
    so.quote_id,
    q.quote_no,
    so.status,
    so.deleted,
    so.created_at,
    so.updated_at
FROM "SalesOrders" so
LEFT JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.deleted = true
ORDER BY so.updated_at DESC, so.created_at DESC
LIMIT 20;

-- 4. Verificar triggers activos en Quotes
SELECT 
    tgname as trigger_name,
    tgtype::text as trigger_type,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = '"Quotes"'::regclass
AND tgname LIKE '%quote%approved%'
AND NOT tgisinternal;

-- 5. Verificar la función del trigger
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'on_quote_approved_create_operational_docs'
AND n.nspname = 'public';

