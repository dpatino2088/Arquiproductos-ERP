-- ============================================================================
-- DIAGNÓSTICO: ¿Por qué no se generan los BOM para SO-000011, SO-000012, SO-000013?
-- ============================================================================

-- 1. Verificar QuoteLines y product_type_id
SELECT 
    'QuoteLines Info' as paso,
    so.sale_order_no,
    sol.id as sale_order_line_id,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.side_channel,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
ORDER BY so.sale_order_no;

-- 2. Verificar si existen BOMTemplates para esos product_type_id
SELECT 
    'BOMTemplates' as paso,
    so.sale_order_no,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    (SELECT COUNT(*) FROM "BOMComponents" bc WHERE bc.bom_template_id = bt.id AND bc.deleted = false) as component_count
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id AND bt.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no, pt.name, bt.id, bt.name
ORDER BY so.sale_order_no, pt.name;

-- 3. Verificar si existen QuoteLineComponents
SELECT 
    'QuoteLineComponents' as paso,
    so.sale_order_no,
    ql.id as quote_line_id,
    COUNT(qlc.id) as component_count,
    STRING_AGG(qlc.component_role, ', ') as component_roles
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no, ql.id
ORDER BY so.sale_order_no;

-- 4. Verificar si los quotes están aprobados
SELECT 
    'Quotes Status' as paso,
    so.sale_order_no,
    q.id as quote_id,
    q.quote_no,
    q.status as quote_status,
    q.organization_id
FROM "SaleOrders" so
INNER JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
ORDER BY so.sale_order_no;

