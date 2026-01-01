-- ====================================================
-- DIAGNÓSTICO: Verificar BOM para Manufacturing Order
-- ====================================================
-- Script para verificar si existen BomInstances para un SalesOrder

-- 1. Verificar MO-000001 y su SalesOrder asociado
SELECT 
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.status as mo_status,
    mo.sale_order_id,
    so.sale_order_no,
    so.status as so_status,
    so.quote_id,
    q.quote_no
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "Quotes" q ON q.id = so.quote_id
WHERE mo.manufacturing_order_no = 'MO-000001'
OR mo.id = 'cc8fb87f-c851-4536-bc12-5041479cbf91'
OR so.sale_order_no = 'SO-053830';

-- 2. Verificar SalesOrderLines para SO-053830
SELECT 
    sol.id as sol_id,
    sol.line_number,
    sol.product_type,
    sol.product_type_id,
    sol.width_m,
    sol.height_m,
    sol.qty,
    COUNT(DISTINCT bi.id) as bom_instances_count
FROM "SalesOrderLines" sol
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-053830'
AND sol.deleted = false
GROUP BY sol.id, sol.line_number, sol.product_type, sol.product_type_id, sol.width_m, sol.height_m, sol.qty
ORDER BY sol.line_number;

-- 3. Verificar BomInstances para SO-053830
SELECT 
    bi.id as bom_instance_id,
    bi.sale_order_line_id,
    sol.line_number,
    bi.bom_template_id,
    bt.name as template_name,
    bi.status,
    bi.created_at,
    bi.updated_at,
    bi.deleted,
    COUNT(DISTINCT bil.id) as bom_lines_count
FROM "BomInstances" bi
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-053830'
GROUP BY bi.id, bi.sale_order_line_id, sol.line_number, bi.bom_template_id, bt.name, bi.status, bi.created_at, bi.updated_at, bi.deleted
ORDER BY sol.line_number;

-- 4. Verificar BomInstanceLines para SO-053830
SELECT 
    bil.id,
    bil.bom_instance_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.description,
    bil.deleted
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-053830'
AND bil.deleted = false
ORDER BY sol.line_number, bil.id
LIMIT 50;

-- 5. Verificar QuoteLineComponents para el Quote asociado (para debugging)
SELECT 
    qlc.id,
    qlc.quote_line_id,
    ql.id as quote_line_id_full,
    qlc.component_role,
    qlc.catalog_item_id,
    ci.sku,
    qlc.qty,
    qlc.uom,
    qlc.source,
    qlc.deleted
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SalesOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-053830'
AND qlc.deleted = false
ORDER BY ql.created_at, qlc.component_role
LIMIT 50;

