-- ====================================================
-- Verificar por qué el trigger NO se ejecuta
-- ====================================================

-- Paso 1: Verificar todos los triggers en ManufacturingOrders
SELECT 
    'All Triggers on ManufacturingOrders' as check_type,
    t.tgname as trigger_name,
    CASE t.tgenabled
        WHEN 'O' THEN '✅ ENABLED'
        WHEN 'D' THEN '❌ DISABLED'
        ELSE '⚠️ UNKNOWN'
    END as status,
    t.tgtype as trigger_type,
    pg_get_triggerdef(t.oid) as definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'ManufacturingOrders'
ORDER BY t.tgname;

-- Paso 2: Verificar si la función existe
SELECT 
    'Function Check' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    provolatile as volatility,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'on_manufacturing_order_insert_generate_bom'
AND pronamespace = 'public'::regnamespace;

-- Paso 3: Ver el último MO creado
SELECT 
    'Latest MO' as check_type,
    mo.manufacturing_order_no,
    mo.created_at,
    mo.deleted,
    so.sale_order_no
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id
ORDER BY mo.created_at DESC
LIMIT 1;






