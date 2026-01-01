-- ====================================================
-- Cambiar Manufacturing Orders de 'planned' a 'draft'
-- ====================================================
-- Este script cambia el status de los Manufacturing Orders
-- de 'planned' a 'draft' para que aparezcan en Manufacturing Orders
-- ====================================================

-- Ver antes del cambio
SELECT 
    'ANTES' as momento,
    status,
    COUNT(*) as total
FROM "ManufacturingOrders"
WHERE deleted = false
GROUP BY status;

-- Cambiar status de 'planned' a 'draft'
UPDATE "ManufacturingOrders"
SET 
    status = 'draft',
    updated_at = now()
WHERE status = 'planned'
AND deleted = false;

-- Ver después del cambio
SELECT 
    'DESPUÉS' as momento,
    status,
    COUNT(*) as total
FROM "ManufacturingOrders"
WHERE deleted = false
GROUP BY status;

-- Lista completa de Manufacturing Orders
SELECT 
    mo.id,
    mo.manufacturing_order_no,
    mo.status,
    so.sale_order_no,
    so.status as sales_order_status,
    mo.created_at,
    CASE 
        WHEN mo.status = 'planned' THEN '⚠️ NO aparece en Manufacturing Orders'
        ELSE '✅ Aparece en Manufacturing Orders'
    END as donde_aparece
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
WHERE mo.deleted = false
ORDER BY mo.created_at DESC;






