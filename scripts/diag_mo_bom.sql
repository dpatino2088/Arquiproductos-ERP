-- ====================================================
-- Script de Diagnóstico: Manufacturing Order BOM
-- ====================================================
-- USO: Reemplazar :mo_id con el UUID del ManufacturingOrder
-- Ejemplo: \set mo_id '137809b3-4070-4d03-966c-9b1212bf6c1d'
-- ====================================================

\set mo_id '137809b3-4070-4d03-966c-9b1212bf6c1d'

-- ====================================================
-- A) ManufacturingOrder existe y su sales_order_id
-- ====================================================
SELECT 
    'A) ManufacturingOrder' AS check_name,
    id,
    sales_order_id,
    organization_id,
    status,
    deleted,
    created_at
FROM "ManufacturingOrders"
WHERE id = :'mo_id';

-- ====================================================
-- B) Count ManufacturingOrderLines
-- ====================================================
SELECT 
    'B) ManufacturingOrderLines Count' AS check_name,
    COUNT(*) AS count_lines,
    COUNT(CASE WHEN deleted = false AND archived = false THEN 1 END) AS count_active
FROM "ManufacturingOrderLines"
WHERE manufacturing_order_id = :'mo_id';

-- ====================================================
-- C) Count SalesOrderLines del SalesOrder
-- ====================================================
SELECT 
    'C) SalesOrderLines Count' AS check_name,
    COUNT(*) AS count_sol,
    COUNT(CASE WHEN sol.deleted = false THEN 1 END) AS count_active
FROM "SalesOrderLines" sol
INNER JOIN "ManufacturingOrders" mo ON mo.sales_order_id = sol.sales_order_id
WHERE mo.id = :'mo_id';

-- ====================================================
-- D) Count BomInstances por manufacturing_order_id
-- ====================================================
SELECT 
    'D) BomInstances Count' AS check_name,
    COUNT(*) AS count_instances,
    COUNT(CASE WHEN deleted = false THEN 1 END) AS count_active
FROM "BomInstances"
WHERE manufacturing_order_id = :'mo_id';

-- ====================================================
-- E) Count BomInstanceLines join BomInstances
-- ====================================================
SELECT 
    'E) BomInstanceLines Count' AS check_name,
    COUNT(*) AS count_lines,
    COUNT(CASE WHEN bil.deleted = false AND bi.deleted = false THEN 1 END) AS count_active
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.manufacturing_order_id = :'mo_id';

-- ====================================================
-- F) Mostrar BomInstances creados con bom_template_id
-- ====================================================
SELECT 
    'F) BomInstances Details' AS check_name,
    bi.id,
    bi.bom_template_id,
    bi.sales_order_line_id,
    bi.manufacturing_order_id,
    bi.labor_cost,
    bi.total_cost_with_labor,
    bi.deleted,
    bi.created_at,
    bi.generated_at
FROM "BomInstances" bi
WHERE bi.manufacturing_order_id = :'mo_id'
ORDER BY bi.created_at DESC
LIMIT 50;

-- ====================================================
-- G) Count BomTemplateComponents por cada bom_template_id
-- ====================================================
SELECT 
    'G) BomTemplateComponents Count' AS check_name,
    btc.bom_template_id,
    bt.name AS template_name,
    COUNT(*) AS components_count,
    COUNT(CASE WHEN btc.deleted = false THEN 1 END) AS components_active,
    COUNT(CASE WHEN btc.component_item_id IS NOT NULL THEN 1 END) AS components_with_item
FROM "BomTemplateComponents" btc
LEFT JOIN "BOMTemplates" bt ON bt.id = btc.bom_template_id
WHERE btc.bom_template_id IN (
    SELECT DISTINCT bom_template_id 
    FROM "BomInstances" 
    WHERE manufacturing_order_id = :'mo_id' 
    AND deleted = false
    AND bom_template_id IS NOT NULL
)
GROUP BY btc.bom_template_id, bt.name
ORDER BY btc.bom_template_id;

-- ====================================================
-- H) ManufacturingOrderLines con SalesOrderLines details
-- ====================================================
SELECT 
    'H) ManufacturingOrderLines Details' AS check_name,
    mol.id AS mol_id,
    mol.sales_order_line_id,
    sol.product_type,
    sol.collection_name,
    sol.variant_name,
    sol.quote_line_id,
    mol.deleted AS mol_deleted,
    mol.archived AS mol_archived
FROM "ManufacturingOrderLines" mol
LEFT JOIN "SalesOrderLines" sol ON sol.id = mol.sales_order_line_id
WHERE mol.manufacturing_order_id = :'mo_id'
ORDER BY mol.created_at ASC;

-- ====================================================
-- I) BOM Templates disponibles por product_type
-- ====================================================
SELECT 
    'I) Available BOM Templates' AS check_name,
    pt.code AS product_type,
    bt.id AS bom_template_id,
    bt.name AS template_name,
    bt.active,
    bt.deleted,
    COUNT(btc.id) AS components_count
FROM "SalesOrderLines" sol
INNER JOIN "ManufacturingOrders" mo ON mo.sales_order_id = sol.sales_order_id
INNER JOIN "ProductTypes" pt ON pt.code = sol.product_type
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
LEFT JOIN "BomTemplateComponents" btc ON btc.bom_template_id = bt.id AND btc.deleted = false
WHERE mo.id = :'mo_id'
    AND sol.deleted = false
GROUP BY pt.code, bt.id, bt.name, bt.active, bt.deleted
ORDER BY pt.code, bt.created_at DESC;

