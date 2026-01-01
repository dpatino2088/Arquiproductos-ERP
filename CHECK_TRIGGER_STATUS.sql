-- ====================================================
-- Verificar Estado del Trigger de BOM
-- ====================================================

-- Paso 1: Verificar si el trigger existe y está activo
SELECT 
    'Trigger Status' as check_type,
    t.tgname as trigger_name,
    c.relname as table_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'ENABLED'
        WHEN 'D' THEN 'DISABLED'
        ELSE 'UNKNOWN'
    END as status,
    pg_get_triggerdef(t.oid) as trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE t.tgname = 'trg_mo_insert_generate_bom'
AND c.relname = 'ManufacturingOrders';

-- Paso 2: Verificar si la función existe
SELECT 
    'Function Status' as check_type,
    routine_name,
    routine_type,
    external_language as language,
    security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'on_manufacturing_order_insert_generate_bom';

-- Paso 3: Contar datos actuales
SELECT 
    'Current Data' as check_type,
    (SELECT COUNT(*) FROM "ManufacturingOrders" WHERE deleted = false) as manufacturing_orders,
    (SELECT COUNT(*) FROM "BomInstances" WHERE deleted = false) as bom_instances,
    (SELECT COUNT(*) FROM "BomInstanceLines" WHERE deleted = false) as bom_instance_lines,
    (SELECT COUNT(*) FROM "QuoteLineComponents" WHERE deleted = false AND source = 'configured_component') as quote_line_components;

-- Paso 4: Ver el último MO creado y si tiene BOM
SELECT 
    'Latest MO Status' as check_type,
    mo.manufacturing_order_no,
    mo.created_at,
    mo.sale_order_id,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    COUNT(DISTINCT qlc.id) as quote_line_components_count
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, mo.created_at, mo.sale_order_id, so.sale_order_no
ORDER BY mo.created_at DESC
LIMIT 3;

-- Paso 5: Verificar QuoteLineComponents para los MOs recientes
SELECT 
    'QuoteLineComponents for Recent MOs' as check_type,
    mo.manufacturing_order_no,
    ql.id as quote_line_id,
    COUNT(qlc.id) as components_count
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, ql.id
ORDER BY mo.created_at DESC
LIMIT 5;






