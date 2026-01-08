-- =========================================================
-- Diagnóstico: BOM Template faltante para product_type
-- =========================================================
-- PROBLEMA: "No active BOMTemplate found for product_type: roller-shade"
-- Este script ayuda a diagnosticar y resolver el problema
-- =========================================================

-- =========================================================
-- PASO 1: Verificar qué product_type tiene el SalesOrderLine
-- =========================================================
SELECT 
    sol.id AS sales_order_line_id,
    sol.product_type,
    sol.collection_name,
    sol.variant_name,
    mo.id AS manufacturing_order_id,
    mo.manufacturing_order_no
FROM "SalesOrderLines" sol
JOIN "ManufacturingOrders" mo ON mo.sales_order_id = sol.sales_order_id
WHERE mo.id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
  AND sol.deleted = false;

-- =========================================================
-- PASO 2: Verificar si existe el ProductType en la tabla
-- =========================================================
SELECT 
    pt.id,
    pt.code,
    pt.name,
    pt.deleted
FROM "ProductTypes" pt
WHERE pt.code = 'roller-shade';

-- =========================================================
-- PASO 3: Verificar si existe BOMTemplate para roller-shade
-- =========================================================
SELECT 
    bt.id AS bom_template_id,
    bt.name AS template_name,
    bt.active,
    bt.deleted,
    pt.code AS product_type_code,
    pt.name AS product_type_name,
    COUNT(bc.id) AS components_count
FROM "BOMTemplates" bt
JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE pt.code = 'roller-shade'
GROUP BY bt.id, bt.name, bt.active, bt.deleted, pt.code, pt.name;

-- =========================================================
-- PASO 4: Ver TODOS los BOM Templates activos disponibles
-- =========================================================
SELECT 
    pt.code AS product_type_code,
    pt.name AS product_type_name,
    bt.id AS bom_template_id,
    bt.name AS template_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) AS components_count
FROM "ProductTypes" pt
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.active = true 
  AND bt.deleted = false
GROUP BY pt.code, pt.name, bt.id, bt.name, bt.active, bt.deleted
ORDER BY pt.code, bt.created_at DESC;

-- =========================================================
-- PASO 5: Si no existe BOMTemplate para roller-shade
-- OPCIONES:
-- =========================================================
-- OPCIÓN A: Crear un BOMTemplate básico para roller-shade
-- (Ejecutar solo si el ProductType existe pero no hay template)
/*
INSERT INTO "BOMTemplates" (
    product_type_id,
    name,
    active,
    deleted,
    organization_id
)
SELECT 
    pt.id,
    'Roller Shade - Default',
    true,
    false,
    mo.organization_id
FROM "ProductTypes" pt
CROSS JOIN "ManufacturingOrders" mo
WHERE pt.code = 'roller-shade'
  AND mo.id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
  AND NOT EXISTS (
    SELECT 1 FROM "BOMTemplates" bt2
    WHERE bt2.product_type_id = pt.id
    AND bt2.active = true
    AND bt2.deleted = false
  )
LIMIT 1;
*/

-- OPCIÓN B: Activar un BOMTemplate existente que esté inactive
/*
UPDATE "BOMTemplates" bt
SET active = true, updated_at = now()
FROM "ProductTypes" pt
WHERE bt.product_type_id = pt.id
  AND pt.code = 'roller-shade'
  AND bt.active = false
  AND bt.deleted = false;
*/

-- =========================================================
-- PASO 6: Después de crear/activar el template, 
-- ejecutar generate_bom_for_manufacturing_order de nuevo
-- =========================================================
-- SELECT public.generate_bom_for_manufacturing_order('fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid);

