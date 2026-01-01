-- ====================================================
-- Verificación Rápida: Estado Actual
-- ====================================================
-- Ejecutar ANTES de la migración 332 para confirmar estado
-- ====================================================

-- 1. SalesOrders sin líneas
SELECT 
    'SalesOrders sin líneas' as info,
    so.sale_order_no,
    so.id,
    so.quote_id,
    so.organization_id
FROM "SalesOrders" so
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
)
ORDER BY so.created_at;

-- 2. QuoteLines disponibles para estos SalesOrders
SELECT 
    'QuoteLines disponibles' as info,
    so.sale_order_no,
    COUNT(ql.id) as quote_lines_count
FROM "SalesOrders" so
LEFT JOIN "QuoteLines" ql ON ql.quote_id = so.quote_id AND ql.deleted = false
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
)
GROUP BY so.id, so.sale_order_no
ORDER BY so.created_at;

-- 3. Total de líneas existentes
SELECT 
    'Total SalesOrderLines existentes' as info,
    COUNT(*) as total_lines
FROM "SalesOrderLines"
WHERE deleted = false;


