-- ====================================================
-- Verificar Manufacturing Orders
-- ====================================================
-- Este script verifica qué Manufacturing Orders existen
-- y su status para entender por qué no aparecen en la página
-- ====================================================

-- 1. Contar Manufacturing Orders por status
SELECT 
    status,
    COUNT(*) as total
FROM "ManufacturingOrders"
WHERE deleted = false
GROUP BY status
ORDER BY status;

-- 2. Lista completa de Manufacturing Orders
SELECT 
    mo.id,
    mo.manufacturing_order_no,
    mo.status,
    mo.sale_order_id,
    so.sale_order_no,
    so.status as sales_order_status,
    mo.priority,
    mo.created_at,
    mo.organization_id,
    CASE 
        WHEN mo.status = 'planned' THEN '⚠️ Aparece en Order List (no en Manufacturing Orders)'
        WHEN mo.status = 'draft' THEN '✅ Aparece en Manufacturing Orders'
        WHEN mo.status = 'in_production' THEN '✅ Aparece en Manufacturing Orders'
        WHEN mo.status = 'completed' THEN '✅ Aparece en Manufacturing Orders'
        WHEN mo.status = 'cancelled' THEN '✅ Aparece en Manufacturing Orders'
        ELSE '❓ Status desconocido'
    END as donde_aparece
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
WHERE mo.deleted = false
ORDER BY mo.created_at DESC;

-- 3. Verificar si hay problemas con organization_id
SELECT 
    'Total MOs' as check_item,
    COUNT(*) as total
FROM "ManufacturingOrders"
WHERE deleted = false
UNION ALL
SELECT 
    'MOs con organization_id NULL' as check_item,
    COUNT(*) as total
FROM "ManufacturingOrders"
WHERE deleted = false
AND organization_id IS NULL
UNION ALL
SELECT 
    'MOs con sale_order_id NULL' as check_item,
    COUNT(*) as total
FROM "ManufacturingOrders"
WHERE deleted = false
AND sale_order_id IS NULL;






