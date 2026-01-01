-- ====================================================
-- Verificar Status de Sales Orders
-- ====================================================
-- Este query muestra los Sales Orders y su status
-- para entender por qué no aparecen en Order List
-- ====================================================

-- 1. Contar Sales Orders por status
SELECT 
    status,
    COUNT(*) as total,
    CASE 
        WHEN status = 'Draft' THEN '⚠️ NO aparecen en Order List (necesitan cambiar a Confirmed)'
        WHEN status = 'Confirmed' THEN '✅ Aparecen en Order List'
        ELSE '❓ Status desconocido'
    END as explicacion
FROM "SalesOrders"
WHERE deleted = false
GROUP BY status
ORDER BY status;

-- 2. Lista completa de Sales Orders con sus Manufacturing Orders
SELECT 
    so.id,
    so.sale_order_no,
    so.status as so_status,
    so.order_progress_status,
    COUNT(mo.id) as manufacturing_orders_count,
    STRING_AGG(mo.manufacturing_order_no, ', ') as manufacturing_order_nos,
    STRING_AGG(mo.status::text, ', ') as mo_statuses,
    CASE 
        WHEN so.status = 'Draft' THEN '⚠️ NO aparece en Order List (status = Draft)'
        WHEN so.status = 'Confirmed' AND COUNT(mo.id) > 0 THEN '✅ Tiene MO, NO aparece en Order List'
        WHEN so.status = 'Confirmed' AND COUNT(mo.id) = 0 THEN '✅ Aparece en Order List (listo para crear MO)'
        ELSE '❓'
    END as donde_aparece
FROM "SalesOrders" so
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no, so.status, so.order_progress_status
ORDER BY so.created_at DESC;






