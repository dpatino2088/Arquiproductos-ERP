-- ============================================================================
-- DIAGNÓSTICO: Por qué no se genera BOM automáticamente
-- ============================================================================

-- 1. Verificar si la función on_quote_approved_create_operational_docs existe y está actualizada
SELECT 
    '1. Función on_quote_approved_create_operational_docs' as paso,
    p.proname as function_name,
    pg_get_functiondef(p.oid) LIKE '%v_qlc_count%' as tiene_generacion_automatica,
    CASE 
        WHEN pg_get_functiondef(p.oid) LIKE '%v_qlc_count%' THEN '✅ Tiene generación automática'
        ELSE '❌ NO tiene generación automática (necesita migración 190)'
    END as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname = 'on_quote_approved_create_operational_docs';

-- 2. Verificar Sale Orders sin BOM
SELECT 
    '2. Sale Orders sin BOM' as paso,
    so.sale_order_no,
    so.id as sale_order_id,
    q.quote_no,
    q.status as quote_status,
    so.created_at as sale_order_created_at,
    COUNT(DISTINCT sol.id) as sale_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    COUNT(DISTINCT ql.id) as quote_lines,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.product_type_id IS NOT NULL) as quote_lines_con_product_type,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as quote_line_components
FROM "SaleOrders" so
INNER JOIN "Quotes" q ON q.id = so.quote_id AND q.deleted = false
LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE so.deleted = false
    AND q.status = 'approved'
GROUP BY so.id, so.sale_order_no, q.quote_no, q.status, so.created_at
HAVING COUNT(DISTINCT bil.id) = 0
ORDER BY so.sale_order_no DESC
LIMIT 10;

-- 3. Verificar QuoteLines sin QuoteLineComponents pero con product_type_id
SELECT 
    '3. QuoteLines sin componentes pero con product_type_id' as paso,
    ql.id as quote_line_id,
    q.quote_no,
    so.sale_order_no,
    ql.product_type_id,
    pt.name as product_type_name,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as component_count,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ SIN product_type_id'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) = 0 THEN '⚠️  Tiene product_type_id pero NO tiene componentes'
        ELSE '✅ OK'
    END as diagnostico
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id AND q.deleted = false
LEFT JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id AND sol.deleted = false
LEFT JOIN "SaleOrders" so ON so.id = sol.sale_order_id AND so.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE ql.deleted = false
    AND q.status = 'approved'
    AND ql.product_type_id IS NOT NULL
GROUP BY ql.id, q.quote_no, so.sale_order_no, ql.product_type_id, pt.name
HAVING COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) = 0
ORDER BY q.quote_no DESC, so.sale_order_no DESC
LIMIT 10;

-- 4. Verificar triggers activos
SELECT 
    '4. Triggers activos' as paso,
    tg.trigger_name,
    tg.event_manipulation,
    tg.action_timing,
    tg.action_statement,
    CASE 
        WHEN tg.trigger_name = 'trg_on_quote_approved_create_operational_docs' THEN '✅ Trigger activo'
        ELSE '⚠️  Otro trigger'
    END as status
FROM information_schema.triggers tg
WHERE tg.event_object_table = 'Quotes'
    AND tg.trigger_schema = 'public'
ORDER BY tg.trigger_name;

