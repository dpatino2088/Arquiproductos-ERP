-- ============================================================================
-- VERIFICACIÓN DE PROBLEMAS CON SALE ORDERS (VERSIÓN CON RESULTADOS TABULARES)
-- ============================================================================
-- Esta versión retorna resultados en tablas para visualización en Supabase

-- ========================================================================
-- 1. SALE ORDERS DUPLICADOS POR QUOTE
-- ========================================================================
SELECT 
    'DUPLICADOS' as tipo_problema,
    quote_id,
    organization_id,
    COUNT(*) as sale_order_count,
    STRING_AGG(sale_order_no, ', ' ORDER BY sale_order_no) as sale_order_nos,
    STRING_AGG(id::TEXT, ', ' ORDER BY created_at DESC) as sale_order_ids
FROM "SaleOrders"
WHERE deleted = false AND quote_id IS NOT NULL
GROUP BY quote_id, organization_id
HAVING COUNT(*) > 1
ORDER BY quote_id;

-- ========================================================================
-- 2. SALE ORDERS SIN CUSTOMER_ID
-- ========================================================================
SELECT 
    'SIN_CUSTOMER_ID' as tipo_problema,
    id as sale_order_id,
    sale_order_no,
    quote_id,
    organization_id,
    created_at
FROM "SaleOrders"
WHERE deleted = false AND customer_id IS NULL
ORDER BY created_at DESC
LIMIT 50;

-- ========================================================================
-- 3. SALE ORDERS SIN ORGANIZATION_ID
-- ========================================================================
SELECT 
    'SIN_ORGANIZATION_ID' as tipo_problema,
    id as sale_order_id,
    sale_order_no,
    quote_id,
    customer_id,
    created_at
FROM "SaleOrders"
WHERE deleted = false AND organization_id IS NULL
ORDER BY created_at DESC
LIMIT 50;

-- ========================================================================
-- 4. SALE ORDERS SIN SALEORDERLINES
-- ========================================================================
SELECT 
    'SIN_SALEORDERLINES' as tipo_problema,
    so.id as sale_order_id,
    so.sale_order_no,
    so.quote_id,
    so.organization_id,
    so.created_at
FROM "SaleOrders" so
WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SaleOrderLines" sol
        WHERE sol.sale_order_id = so.id AND sol.deleted = false
    )
ORDER BY so.created_at DESC
LIMIT 50;

-- ========================================================================
-- 5. SALE ORDERS SIN BOM
-- ========================================================================
SELECT 
    'SIN_BOM' as tipo_problema,
    so.id as sale_order_id,
    so.sale_order_no,
    so.quote_id,
    so.organization_id,
    COUNT(DISTINCT sol.id) as line_count,
    so.created_at
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "BomInstances" bi
        WHERE bi.sale_order_line_id = sol.id AND bi.deleted = false
    )
GROUP BY so.id, so.sale_order_no, so.quote_id, so.organization_id, so.created_at
ORDER BY so.created_at DESC
LIMIT 50;

-- ========================================================================
-- 6. RESUMEN DE CONTEO
-- ========================================================================
SELECT 
    'RESUMEN' as tipo_problema,
    (SELECT COUNT(*) FROM (
        SELECT quote_id, organization_id
        FROM "SaleOrders"
        WHERE deleted = false AND quote_id IS NOT NULL
        GROUP BY quote_id, organization_id
        HAVING COUNT(*) > 1
    ) duplicates) as sale_orders_duplicados,
    (SELECT COUNT(*) FROM "SaleOrders" WHERE deleted = false AND customer_id IS NULL) as sin_customer_id,
    (SELECT COUNT(*) FROM "SaleOrders" WHERE deleted = false AND organization_id IS NULL) as sin_organization_id,
    (SELECT COUNT(*) FROM "SaleOrders" so
     WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = so.id AND sol.deleted = false
        )) as sin_saleorderlines,
    (SELECT COUNT(*) FROM "SaleOrders" so
     WHERE so.deleted = false
        AND EXISTS (
            SELECT 1 FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = so.id AND sol.deleted = false
        )
        AND NOT EXISTS (
            SELECT 1 FROM "SaleOrderLines" sol
            INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
            WHERE sol.sale_order_id = so.id AND sol.deleted = false AND bi.deleted = false
        )) as sin_bom;








