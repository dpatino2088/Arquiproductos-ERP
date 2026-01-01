-- ============================================================================
-- SOLO DIAGNÓSTICO: SO-000011, SO-000012, SO-000013
-- Ejecuta esto primero para ver qué está pasando
-- ============================================================================

-- 1. Verificar QuoteLines y product_type_id
SELECT 
    '1. QuoteLines' as paso,
    so.sale_order_no,
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
    ql.qty,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ SIN product_type_id'
        ELSE '✅ Tiene product_type_id'
    END as status
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
ORDER BY so.sale_order_no;

-- 2. Verificar BOMTemplates
SELECT 
    '2. BOMTemplates' as paso,
    so.sale_order_no,
    ql.product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    CASE 
        WHEN bt.id IS NULL THEN '❌ NO HAY BOMTemplate'
        ELSE '✅ Tiene BOMTemplate'
    END as status
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id AND bt.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no, ql.product_type_id, pt.name, bt.id, bt.name
ORDER BY so.sale_order_no;

-- 3. Verificar QuoteLineComponents existentes
SELECT 
    '3. QuoteLineComponents' as paso,
    so.sale_order_no,
    ql.id as quote_line_id,
    COUNT(qlc.id) as component_count,
    STRING_AGG(DISTINCT qlc.component_role, ', ' ORDER BY qlc.component_role) as component_roles
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no, ql.id
ORDER BY so.sale_order_no;

-- 4. Verificar Quotes (estado)
SELECT 
    '4. Quotes Status' as paso,
    so.sale_order_no,
    q.id as quote_id,
    q.quote_no,
    q.status as quote_status,
    CASE 
        WHEN q.status = 'approved' THEN '✅ Aprobado'
        ELSE '❌ No aprobado: ' || q.status
    END as status
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
INNER JOIN "Quotes" q ON q.id = ql.quote_id AND q.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.sale_order_no, q.id, q.quote_no, q.status
ORDER BY so.sale_order_no;








