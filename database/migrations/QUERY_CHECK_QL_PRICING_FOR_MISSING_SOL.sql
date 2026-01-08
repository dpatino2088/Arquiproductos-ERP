-- ====================================================
-- Verificar si las QuoteLines correspondientes tienen pricing
-- ====================================================
-- Para las 2 SalesOrderLines sin pricing, verifica si sus QuoteLines tienen pricing
-- ====================================================

SELECT 
    sol.id as sol_id,
    sol.line_number,
    sol.quote_line_id,
    -- SalesOrderLine pricing (actual)
    sol.list_unit_price_snapshot as sol_msrp,
    sol.unit_price_snapshot as sol_net_price,
    sol.discount_pct_used as sol_discount,
    -- QuoteLine pricing (debería copiarse)
    ql.list_unit_price_snapshot as ql_msrp,
    ql.unit_price_snapshot as ql_net_price,
    ql.discount_pct_used as ql_discount,
    ql.unit_cost_snapshot as ql_cost,
    ql.total_unit_cost_snapshot as ql_total_cost,
    ql.computed_qty as ql_computed_qty,
    ql.customer_type_snapshot as ql_customer_type,
    ql.price_basis as ql_price_basis,
    ql.margin_pct_used as ql_margin,
    ql.measure_basis_snapshot as ql_measure_basis,
    ql.deleted as ql_deleted,
    -- Status
    CASE 
        WHEN ql.id IS NULL THEN '❌ QuoteLine no existe'
        WHEN ql.deleted = true THEN '⚠️ QuoteLine está deleted'
        WHEN ql.list_unit_price_snapshot IS NULL OR ql.list_unit_price_snapshot = 0 THEN '❌ QuoteLine sin MSRP'
        WHEN ql.unit_price_snapshot IS NULL OR ql.unit_price_snapshot = 0 THEN '❌ QuoteLine sin net price'
        ELSE '✅ QuoteLine tiene pricing - puede copiarse'
    END as status
FROM "SalesOrderLines" sol
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE sol.deleted = false
AND sol.quote_line_id IS NOT NULL
AND (
    sol.list_unit_price_snapshot IS NULL 
    OR sol.list_unit_price_snapshot = 0
    OR sol.unit_price_snapshot IS NULL 
    OR sol.unit_price_snapshot = 0
)
ORDER BY sol.created_at DESC;


