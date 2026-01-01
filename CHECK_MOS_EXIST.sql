-- Verificar si los MOs existen
SELECT 
    mo.manufacturing_order_no,
    mo.sale_order_id,
    mo.deleted
FROM "ManufacturingOrders" mo
ORDER BY mo.created_at DESC;






