-- ====================================================
-- Test Script CORREGIDO: Verificar Trigger Quote Approved
-- ====================================================
-- PASO 1: Ya lo hiciste - encontraste las Quotes
-- PASO 2: Aprobar una Quote (REEMPLAZA EL ID)
-- ====================================================

-- PASO 2: Aprobar la Quote
-- ⚠️ REEMPLAZA 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2' con el ID real de la Quote que quieres aprobar
UPDATE "Quotes"
SET status = 'approved',
    updated_at = NOW()
WHERE id = 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2'  -- ⚠️ CAMBIA ESTE ID
AND deleted = false
AND status != 'approved';

-- ====================================================
-- PASO 3: Verificar SalesOrder creado
-- ====================================================
-- ⚠️ REEMPLAZA el ID con el mismo que usaste arriba
SELECT 
    so.id as sales_order_id,
    so.sale_order_no,
    so.status,
    so.quote_id,
    so.subtotal,
    so.tax,
    so.total,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2'  -- ⚠️ CAMBIA ESTE ID
AND so.deleted = false;

-- ====================================================
-- PASO 4: Verificar SalesOrderLines creados
-- ====================================================
-- ⚠️ REEMPLAZA el ID con el mismo que usaste arriba
SELECT 
    sol.id,
    sol.line_number,
    sol.item_name,
    sol.qty,
    sol.unit_price,
    sol.line_total,
    sol.width_m,
    sol.height_m,
    sol.area,
    sol.product_type,
    sol.drive_type,
    sol.hardware_color
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2'  -- ⚠️ CAMBIA ESTE ID
AND sol.deleted = false
ORDER BY sol.line_number;

-- ====================================================
-- PASO 5: Verificar BomInstances creados
-- ====================================================
-- ⚠️ REEMPLAZA el ID con el mismo que usaste arriba
SELECT 
    bi.id as bom_instance_id,
    bi.status,
    sol.line_number,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil WHERE bil.bom_instance_id = bi.id AND bil.deleted = false) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2'  -- ⚠️ CAMBIA ESTE ID
AND bi.deleted = false
ORDER BY sol.line_number;

-- ====================================================
-- PASO 6: Resumen Final
-- ====================================================
-- ⚠️ REEMPLAZA el ID con el mismo que usaste arriba
SELECT 
    'Quote' as tipo,
    q.quote_no as numero,
    q.status,
    q.created_at,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count
FROM "Quotes" q
WHERE q.id = 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2'  -- ⚠️ CAMBIA ESTE ID

UNION ALL

SELECT 
    'SalesOrder',
    so.sale_order_no,
    so.status,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = 'e112194b-fe3d-4b04-bb9a-ddf2c9ae0ab2'  -- ⚠️ CAMBIA ESTE ID
AND so.deleted = false

ORDER BY created_at;




