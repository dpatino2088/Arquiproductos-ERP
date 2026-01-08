-- ====================================================
-- Query de Verificación: Columnas de Pricing en SalesOrderLines
-- ====================================================
-- Verifica que las columnas de pricing se hayan creado correctamente
-- ====================================================

-- 1. Verificar columnas de pricing en SalesOrderLines
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SalesOrderLines'
AND column_name IN (
    'list_unit_price_snapshot',
    'unit_price_snapshot',
    'unit_cost_snapshot',
    'total_unit_cost_snapshot',
    'computed_qty',
    'discount_pct_used',
    'customer_type_snapshot',
    'price_basis',
    'margin_pct_used',
    'measure_basis_snapshot'
)
ORDER BY column_name;

-- 2. Verificar SalesOrderLines con pricing
SELECT 
    COUNT(*) as total_lines,
    COUNT(list_unit_price_snapshot) as with_list_price,
    COUNT(unit_price_snapshot) as with_unit_price,
    COUNT(discount_pct_used) as with_discount
FROM "SalesOrderLines"
WHERE deleted = false
AND quote_line_id IS NOT NULL;

-- 3. Ejemplo de SalesOrderLine con pricing
SELECT 
    sol.id,
    sol.line_number,
    sol.list_unit_price_snapshot as msrp_sale_out,
    sol.unit_price_snapshot as net_price,
    sol.discount_pct_used,
    sol.customer_type_snapshot,
    sol.computed_qty,
    ql.list_unit_price_snapshot as ql_msrp_sale_out,
    ql.unit_price_snapshot as ql_net_price,
    ql.discount_pct_used as ql_discount
FROM "SalesOrderLines" sol
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE sol.deleted = false
AND sol.quote_line_id IS NOT NULL
ORDER BY sol.created_at DESC
LIMIT 5;


