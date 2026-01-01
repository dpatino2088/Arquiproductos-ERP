-- ============================================================================
-- VERIFICAR SI LOS BOM SE GENERARON CORRECTAMENTE
-- ============================================================================
-- Este script muestra en tablas si los BOM se generaron para todos los Sale Orders

-- 1. Resumen: Sale Orders con y sin BOM
SELECT 
    'RESUMEN' as tipo,
    COUNT(DISTINCT so.id) as total_sale_orders,
    COUNT(DISTINCT CASE WHEN bi.id IS NOT NULL THEN so.id END) as con_bom,
    COUNT(DISTINCT CASE WHEN bi.id IS NULL THEN so.id END) as sin_bom
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.deleted = false;

-- 2. Lista de Sale Orders SIN BOM (si aún existen)
SELECT 
    'SIN_BOM' as tipo,
    so.id as sale_order_id,
    so.sale_order_no,
    so.quote_id,
    COUNT(DISTINCT sol.id) as sale_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "BomInstances" bi2
        WHERE bi2.sale_order_line_id = sol.id AND bi2.deleted = false
    )
GROUP BY so.id, so.sale_order_no, so.quote_id
ORDER BY so.sale_order_no;

-- 3. Lista de Sale Orders CON BOM (verificación)
SELECT 
    'CON_BOM' as tipo,
    so.id as sale_order_id,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sale_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    SUM(bil.qty) as total_qty,
    SUM(bil.total_cost_exw) as total_cost
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no
ORDER BY so.sale_order_no
LIMIT 20;

-- 4. Verificar SaleOrderMaterialList (la vista que usa ApprovedBOMList)
SELECT 
    'MATERIAL_LIST' as tipo,
    sale_order_no,
    COUNT(*) as material_count,
    SUM(total_qty) as total_qty,
    SUM(total_cost_exw) as total_cost
FROM "SaleOrderMaterialList"
GROUP BY sale_order_no
ORDER BY sale_order_no;








