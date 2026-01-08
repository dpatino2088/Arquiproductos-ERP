-- ====================================================
-- Diagnóstico: SalesOrderLines sin pricing
-- ====================================================
-- Identifica las líneas específicas que no tienen pricing
-- y verifica por qué el backfill no las actualizó
-- ====================================================

-- 1. Identificar SalesOrderLines sin pricing
SELECT 
    sol.id as sol_id,
    sol.line_number,
    sol.quote_line_id,
    sol.list_unit_price_snapshot as sol_msrp,
    sol.unit_price_snapshot as sol_net_price,
    sol.discount_pct_used as sol_discount,
    sol.created_at as sol_created_at,
    -- Verificar QuoteLine
    ql.id as ql_id,
    ql.list_unit_price_snapshot as ql_msrp,
    ql.unit_price_snapshot as ql_net_price,
    ql.discount_pct_used as ql_discount,
    ql.deleted as ql_deleted,
    ql.created_at as ql_created_at,
    -- Verificar si QuoteLine tiene pricing
    CASE 
        WHEN ql.list_unit_price_snapshot IS NULL OR ql.list_unit_price_snapshot = 0 THEN 'QuoteLine missing MSRP'
        WHEN ql.unit_price_snapshot IS NULL OR ql.unit_price_snapshot = 0 THEN 'QuoteLine missing net price'
        ELSE 'QuoteLine has pricing'
    END as ql_pricing_status
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

-- 2. Verificar si las QuoteLines correspondientes tienen pricing
SELECT 
    COUNT(*) as total_sol_without_pricing,
    COUNT(ql.id) as ql_exists,
    COUNT(CASE WHEN ql.deleted = true THEN 1 END) as ql_deleted,
    COUNT(CASE WHEN ql.list_unit_price_snapshot IS NULL OR ql.list_unit_price_snapshot = 0 THEN 1 END) as ql_missing_msrp,
    COUNT(CASE WHEN ql.unit_price_snapshot IS NULL OR ql.unit_price_snapshot = 0 THEN 1 END) as ql_missing_net_price,
    COUNT(CASE WHEN ql.list_unit_price_snapshot IS NOT NULL AND ql.list_unit_price_snapshot > 0 
              AND ql.unit_price_snapshot IS NOT NULL AND ql.unit_price_snapshot > 0 THEN 1 END) as ql_has_pricing
FROM "SalesOrderLines" sol
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE sol.deleted = false
AND sol.quote_line_id IS NOT NULL
AND (
    sol.list_unit_price_snapshot IS NULL 
    OR sol.list_unit_price_snapshot = 0
    OR sol.unit_price_snapshot IS NULL 
    OR sol.unit_price_snapshot = 0
);

-- 3. Verificar fechas de creación (para ver si fueron creadas después del backfill)
SELECT 
    sol.id,
    sol.created_at as sol_created,
    ql.created_at as ql_created,
    sol.created_at > ql.created_at as sol_created_after_ql,
    CASE 
        WHEN sol.created_at > NOW() - INTERVAL '1 hour' THEN 'Created recently (may need backfill)'
        ELSE 'Created earlier'
    END as timing_note
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


