-- ====================================================
-- Verificar qué pasó con la generación de BOM para SO-000024
-- ====================================================

-- Paso 1: Verificar QuoteLineComponents
SELECT 
    'Paso 1: QuoteLineComponents' as paso,
    qlc.id,
    qlc.quote_line_id,
    qlc.catalog_item_id,
    qlc.component_role,
    qlc.qty,
    qlc.uom,
    qlc.source,
    ci.sku,
    ci.item_name
FROM "QuoteLineComponents" qlc
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000024'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY qlc.created_at;

-- Paso 2: Verificar BomInstances
SELECT 
    'Paso 2: BomInstances' as paso,
    bi.id,
    bi.sale_order_line_id,
    bi.quote_line_id,
    bi.organization_id,
    bi.status,
    sol.sale_order_id,
    so.sale_order_no
FROM "BomInstances" bi
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000024'
OR bi.quote_line_id IN (
    SELECT ql.id 
    FROM "QuoteLines" ql
    INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    WHERE so.sale_order_no = 'SO-000024'
)
AND bi.deleted = false;

-- Paso 3: Verificar BomInstanceLines
SELECT 
    'Paso 3: BomInstanceLines' as paso,
    bil.id,
    bil.bom_instance_id,
    bil.resolved_part_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bi.sale_order_line_id,
    sol.sale_order_id,
    so.sale_order_no
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000024'
OR bi.quote_line_id IN (
    SELECT ql.id 
    FROM "QuoteLines" ql
    INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    WHERE so.sale_order_no = 'SO-000024'
)
AND bil.deleted = false;

-- Paso 4: Verificar QuoteLine específico
SELECT 
    'Paso 4: QuoteLine' as paso,
    ql.id,
    ql.quote_id,
    ql.product_type_id,
    ql.organization_id,
    ql.width_m,
    ql.height_m,
    ql.qty,
    pt.name as product_type_name,
    sol.id as sale_order_line_id,
    so.sale_order_no
FROM "QuoteLines" ql
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000024'
AND ql.deleted = false;






