-- ====================================================
-- DIAGNÓSTICO: Por qué no se muestran los BOMs en la UI
-- ====================================================
-- Verificar que todos los IDs y organization_ids coincidan

-- 1. Verificar ManufacturingOrder y su sale_order_id
SELECT 
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.sale_order_id,
    mo.organization_id as mo_org_id,
    mo.status as mo_status,
    so.id as so_id,
    so.sale_order_no,
    so.organization_id as so_org_id
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.manufacturing_order_no = 'MO-000001'
OR mo.id = 'cc8fb87f-c851-4536-bc12-5041479cbf91';

-- 2. Verificar que los organization_ids coincidan
SELECT 
    'ManufacturingOrder' as table_name,
    mo.organization_id,
    COUNT(*) as count
FROM "ManufacturingOrders" mo
WHERE mo.id = 'cc8fb87f-c851-4536-bc12-5041479cbf91'
GROUP BY mo.organization_id
UNION ALL
SELECT 
    'SalesOrder' as table_name,
    so.organization_id,
    COUNT(*) as count
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-053830'
GROUP BY so.organization_id
UNION ALL
SELECT 
    'SalesOrderLines' as table_name,
    sol.organization_id,
    COUNT(*) as count
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-053830'
GROUP BY sol.organization_id
UNION ALL
SELECT 
    'BomInstances' as table_name,
    bi.organization_id,
    COUNT(*) as count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-053830'
GROUP BY bi.organization_id
UNION ALL
SELECT 
    'BomInstanceLines' as table_name,
    bil.organization_id,
    COUNT(*) as count
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-053830'
GROUP BY bil.organization_id;

-- 3. Verificar la cadena completa: MO -> SO -> SOL -> BI -> BIL
SELECT 
    mo.manufacturing_order_no,
    mo.organization_id as mo_org_id,
    so.sale_order_no,
    so.organization_id as so_org_id,
    sol.id as sol_id,
    sol.organization_id as sol_org_id,
    bi.id as bi_id,
    bi.organization_id as bi_org_id,
    COUNT(DISTINCT bil.id) as bil_count,
    bil.organization_id as bil_org_id
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000001'
OR mo.id = 'cc8fb87f-c851-4536-bc12-5041479cbf91'
GROUP BY 
    mo.manufacturing_order_no,
    mo.organization_id,
    so.sale_order_no,
    so.organization_id,
    sol.id,
    sol.organization_id,
    bi.id,
    bi.organization_id,
    bil.organization_id
ORDER BY sol.id, bi.id;

-- 4. Verificar si hay problemas de RLS (verificar permisos)
-- Esta query verifica que todos los registros tengan organization_id consistente
SELECT 
    CASE 
        WHEN mo.organization_id != so.organization_id THEN '❌ MO y SO tienen organization_id diferente'
        WHEN so.organization_id != sol.organization_id THEN '❌ SO y SOL tienen organization_id diferente'
        WHEN sol.organization_id != bi.organization_id THEN '❌ SOL y BI tienen organization_id diferente'
        WHEN bi.organization_id != bil.organization_id THEN '❌ BI y BIL tienen organization_id diferente'
        ELSE '✅ Todos los organization_ids coinciden'
    END as status_check,
    mo.organization_id as mo_org,
    so.organization_id as so_org,
    sol.organization_id as sol_org,
    bi.organization_id as bi_org,
    bil.organization_id as bil_org
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000001'
OR mo.id = 'cc8fb87f-c851-4536-bc12-5041479cbf91'
LIMIT 1;




