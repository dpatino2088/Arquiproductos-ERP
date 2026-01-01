-- ============================================================================
-- DIAGNÓSTICO COMPLETO EN UNA SOLA CONSULTA
-- Muestra toda la información necesaria para identificar el problema
-- ============================================================================

SELECT 
    so.sale_order_no,
    q.quote_no,
    q.status as quote_status,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.organization_id as ql_org_id,
    so.organization_id as so_org_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.side_channel,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty,
    -- BOMTemplate
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    bt.active as bom_template_active,
    bt.organization_id as bt_org_id,
    -- QuoteLineComponents
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as qlc_count,
    STRING_AGG(DISTINCT qlc.component_role, ', ' ORDER BY qlc.component_role) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as qlc_roles,
    -- BomInstance
    bi.id as bom_instance_id,
    COUNT(DISTINCT bil.id) FILTER (WHERE bil.deleted = false) as bil_count,
    -- Diagnóstico
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ SIN product_type_id'
        WHEN bt.id IS NULL THEN '❌ NO HAY BOMTemplate'
        WHEN bt.active = false THEN '❌ BOMTemplate INACTIVO'
        WHEN ql.organization_id IS NULL THEN '⚠️ QuoteLine sin organization_id'
        WHEN ql.organization_id != so.organization_id THEN '⚠️ organization_id mismatch'
        WHEN COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) = 0 THEN '⚠️ NO HAY QuoteLineComponents'
        WHEN bi.id IS NULL THEN '⚠️ NO HAY BomInstance'
        WHEN COUNT(DISTINCT bil.id) FILTER (WHERE bil.deleted = false) = 0 THEN '⚠️ NO HAY BomInstanceLines'
        ELSE '✅ OK'
    END as diagnostico
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
INNER JOIN "Quotes" q ON q.id = ql.quote_id AND q.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.deleted = false
    AND (bt.organization_id = ql.organization_id OR bt.organization_id IS NULL)
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY 
    so.sale_order_no,
    q.quote_no,
    q.status,
    ql.id,
    ql.product_type_id,
    pt.name,
    ql.organization_id,
    so.organization_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.side_channel,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty,
    bt.id,
    bt.name,
    bt.active,
    bt.organization_id,
    bi.id
ORDER BY so.sale_order_no;








