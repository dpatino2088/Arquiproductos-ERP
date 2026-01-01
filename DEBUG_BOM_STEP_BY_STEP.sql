-- ====================================================
-- Debug BOM Generation - Paso por Paso
-- ====================================================
-- Este script verifica cada paso del proceso
-- ====================================================

-- Paso 1: Ver el último MO y su información completa
SELECT 
    'Paso 1: Último MO' as paso,
    mo.manufacturing_order_no,
    mo.sale_order_id,
    mo.organization_id,
    so.sale_order_no,
    so.quote_id
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.deleted = false
ORDER BY mo.created_at DESC
LIMIT 1;

-- Paso 2: Ver las SalesOrderLines de ese MO
SELECT 
    'Paso 2: SalesOrderLines' as paso,
    sol.id as sale_order_line_id,
    sol.quote_line_id,
    sol.sale_order_id
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE mo.deleted = false
ORDER BY mo.created_at DESC, sol.line_number
LIMIT 10;

-- Paso 3: Ver las QuoteLines correspondientes
SELECT 
    'Paso 3: QuoteLines' as paso,
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    pt.name as product_type_name
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE mo.deleted = false
ORDER BY mo.created_at DESC, sol.line_number
LIMIT 10;

-- Paso 4: Ver si existen QuoteLineComponents
SELECT 
    'Paso 4: QuoteLineComponents' as paso,
    ql.id as quote_line_id,
    COUNT(qlc.id) as components_count
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
WHERE mo.deleted = false
GROUP BY mo.id, ql.id
ORDER BY mo.created_at DESC
LIMIT 10;

-- Paso 5: Ver si existen BomInstances
SELECT 
    'Paso 5: BomInstances' as paso,
    COUNT(bi.id) as count
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE mo.deleted = false;

-- Paso 6: Ver columnas de BomInstanceLines
SELECT 
    'Paso 6: BomInstanceLines Schema' as paso,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'BomInstanceLines'
ORDER BY ordinal_position;

