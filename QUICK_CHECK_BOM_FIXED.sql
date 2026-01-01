-- ============================================================================
-- VERIFICACIÓN RÁPIDA: ¿Se corrigieron los BOM?
-- ============================================================================
-- Este script verifica rápidamente si los 3 Sale Orders sin BOM fueron corregidos

-- Contar Sale Orders sin BOM
SELECT 
    'Sale Orders sin BOM' as verificacion,
    COUNT(DISTINCT so.id) as cantidad
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "BomInstances" bi
        WHERE bi.sale_order_line_id = sol.id AND bi.deleted = false
    );

-- Listar los Sale Orders sin BOM (si aún existen)
SELECT 
    so.id as sale_order_id,
    so.sale_order_no,
    so.quote_id,
    COUNT(DISTINCT sol.id) as line_count
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "BomInstances" bi
        WHERE bi.sale_order_line_id = sol.id AND bi.deleted = false
    )
GROUP BY so.id, so.sale_order_no, so.quote_id
ORDER BY so.created_at DESC;








