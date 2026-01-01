-- ============================================================================
-- DIAGNÓSTICO ESPECÍFICO: SO-000014 y SO-000015
-- ============================================================================

-- 1. Verificar QuoteLines y product_type_id
SELECT 
    '1. QuoteLines' as paso,
    so.sale_order_no,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.organization_id,
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
        WHEN ql.organization_id IS NULL THEN '⚠️ SIN organization_id'
        ELSE '✅ OK'
    END as status
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no IN ('SO-000014', 'SO-000015')
    AND so.deleted = false
ORDER BY so.sale_order_no;

-- 2. Verificar QuoteLineComponents
SELECT 
    '2. QuoteLineComponents' as paso,
    so.sale_order_no,
    ql.id as quote_line_id,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as component_count,
    STRING_AGG(DISTINCT qlc.component_role, ', ' ORDER BY qlc.component_role) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as component_roles
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE so.sale_order_no IN ('SO-000014', 'SO-000015')
    AND so.deleted = false
GROUP BY so.sale_order_no, ql.id
ORDER BY so.sale_order_no;

-- 3. Verificar BOMTemplates
SELECT 
    '3. BOMTemplates' as paso,
    so.sale_order_no,
    ql.product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    bt.active as bom_template_active,
    CASE 
        WHEN bt.id IS NULL THEN '❌ NO HAY BOMTemplate'
        WHEN bt.active = false THEN '❌ BOMTemplate INACTIVO'
        ELSE '✅ Tiene BOMTemplate'
    END as status
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.deleted = false
WHERE so.sale_order_no IN ('SO-000014', 'SO-000015')
    AND so.deleted = false
GROUP BY so.sale_order_no, ql.product_type_id, pt.name, bt.id, bt.name, bt.active
ORDER BY so.sale_order_no;

-- 4. Verificar Quotes status
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
WHERE so.sale_order_no IN ('SO-000014', 'SO-000015')
    AND so.deleted = false
GROUP BY so.sale_order_no, q.id, q.quote_no, q.status
ORDER BY so.sale_order_no;








