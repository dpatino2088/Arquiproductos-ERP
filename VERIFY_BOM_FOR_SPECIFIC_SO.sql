-- ============================================================================
-- VERIFICAR BOM PARA SO-000011, SO-000012, SO-000013
-- ============================================================================
-- Este script verifica si estos Sale Orders tienen BOM generados

-- 1. Verificar BomInstances
SELECT 
    'BomInstances' as tipo,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instance_count
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no
ORDER BY so.sale_order_no;

-- 2. Verificar BomInstanceLines
SELECT 
    'BomInstanceLines' as tipo,
    so.sale_order_no,
    COUNT(DISTINCT bil.id) as bom_line_count,
    SUM(bil.qty) as total_qty
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no
ORDER BY so.sale_order_no;

-- 3. Verificar SaleOrderMaterialList view
SELECT 
    'SaleOrderMaterialList' as tipo,
    sale_order_no,
    COUNT(*) as material_count,
    SUM(total_qty) as total_qty,
    SUM(total_cost_exw) as total_cost
FROM "SaleOrderMaterialList"
WHERE sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
GROUP BY sale_order_no
ORDER BY sale_order_no;

-- 4. Detalle de materiales por Sale Order
SELECT 
    sale_order_no,
    category_code,
    sku,
    item_name,
    total_qty,
    uom,
    total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
ORDER BY sale_order_no, category_code, sku;








