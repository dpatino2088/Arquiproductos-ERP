-- ====================================================
-- Verificar Status de Manufacturing Orders
-- ====================================================
-- Este query muestra los MOs y su status para entender
-- por qué no aparecen en Manufacturing Orders
-- ====================================================

SELECT 
    mo.id,
    mo.manufacturing_order_no,
    mo.status,
    mo.sale_order_id,
    so.sale_order_no,
    so.status as sales_order_status,
    mo.organization_id,
    mo.created_at,
    CASE 
        WHEN mo.status = 'planned' THEN '⚠️ Aparece SOLO en Order List (NO en Manufacturing Orders)'
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

-- Resumen por status
SELECT 
    status,
    COUNT(*) as total,
    CASE 
        WHEN status = 'planned' THEN '⚠️ NO aparecen en Manufacturing Orders (solo en Order List)'
        ELSE '✅ Aparecen en Manufacturing Orders'
    END as explicacion
FROM "ManufacturingOrders"
WHERE deleted = false
GROUP BY status
ORDER BY status;






