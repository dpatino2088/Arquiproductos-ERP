-- ====================================================
-- Diagnóstico: Por qué no se generan BOMs
-- ====================================================
-- Este script diagnostica por qué MO-000004 no tiene BOMs
-- ====================================================

-- Paso 1: Verificar que el MO existe
SELECT 
    'Paso 1: Verificar MO' as paso,
    mo.id,
    mo.manufacturing_order_no,
    mo.sale_order_id,
    mo.organization_id,
    mo.status,
    so.sale_order_no,
    so.status as so_status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.manufacturing_order_no = 'MO-000004'
AND mo.deleted = false;

-- Paso 2: Verificar SalesOrderLines
SELECT 
    'Paso 2: Verificar SalesOrderLines' as paso,
    sol.id as sol_id,
    sol.sale_order_id,
    sol.quote_line_id,
    sol.line_number,
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE so.sale_order_no = 'SO-000023'
AND sol.deleted = false
ORDER BY sol.line_number;

-- Paso 3: Verificar si existe la función generate_configured_bom_for_quote_line
SELECT 
    'Paso 3: Verificar función' as paso,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'generate_configured_bom_for_quote_line';

-- Paso 4: Verificar BomInstances existentes
SELECT 
    'Paso 4: Verificar BomInstances' as paso,
    bi.id,
    bi.sale_order_line_id,
    bi.quote_line_id,
    bi.organization_id,
    sol.sale_order_id
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000023'
AND bi.deleted = false;

-- Paso 5: Verificar QuoteLines con product_type_id
SELECT 
    'Paso 5: Verificar QuoteLines' as paso,
    ql.id,
    ql.quote_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.width_m,
    ql.height_m,
    ql.qty,
    pt.name as product_type_name
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000023'
AND sol.deleted = false
AND ql.deleted = false
ORDER BY sol.line_number;

-- Paso 6: Intentar generar BOM manualmente para una QuoteLine
-- (Solo mostrar la query, no ejecutarla automáticamente)
SELECT 
    'Paso 6: Query para generar BOM manualmente' as paso,
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.bottom_rail_type,
    COALESCE(ql.cassette, false) as cassette,
    ql.cassette_type,
    COALESCE(ql.side_channel, false) as side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty,
    sol.id as sale_order_line_id
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE so.sale_order_no = 'SO-000023'
AND sol.deleted = false
AND ql.deleted = false
AND ql.product_type_id IS NOT NULL
ORDER BY sol.line_number
LIMIT 1;






