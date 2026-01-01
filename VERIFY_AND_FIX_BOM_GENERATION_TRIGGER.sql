-- ====================================================
-- Verificar y Corregir Trigger de Generación de BOM
-- ====================================================
-- Este script verifica que el trigger que genera BOM
-- cuando se crea un Manufacturing Order esté activo
-- ====================================================

-- 1. Verificar si existe la función
SELECT 
    'Function on_manufacturing_order_insert_generate_bom' as check_item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'on_manufacturing_order_insert_generate_bom'
            AND pronamespace = 'public'::regnamespace
        ) THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status;

-- 2. Verificar si existe el trigger
SELECT 
    'Trigger trg_mo_insert_generate_bom' as check_item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'trg_mo_insert_generate_bom'
            AND tgrelid = '"ManufacturingOrders"'::regclass
        ) THEN '✅ EXISTS and ACTIVE'
        ELSE '❌ NOT FOUND'
    END as status;

-- 3. Lista de Manufacturing Orders sin BOMs
SELECT 
    mo.id,
    mo.manufacturing_order_no,
    mo.status,
    mo.sale_order_id,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    CASE 
        WHEN COUNT(DISTINCT bi.id) > 0 THEN '✅ Has BOM'
        ELSE '❌ No BOM'
    END as bom_status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, mo.status, mo.sale_order_id, so.sale_order_no
HAVING COUNT(DISTINCT bi.id) = 0
ORDER BY mo.created_at DESC;






