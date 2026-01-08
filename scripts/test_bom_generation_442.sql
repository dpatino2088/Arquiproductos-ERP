-- =========================================================
-- Script de Prueba: Migración 442 - Auto-create MO Lines + BOM
-- =========================================================
-- USO: Reemplazar :mo_id con el UUID real del ManufacturingOrder
-- Ejemplo: \set mo_id 'fd465c23-2f61-4ff5-954c-6c2a2418186c'
-- =========================================================

\set mo_id 'fd465c23-2f61-4ff5-954c-6c2a2418186c'

-- =========================================================
-- PASO 1: Ejecutar RPC de generación de BOM
-- =========================================================
SELECT public.generate_bom_for_manufacturing_order(:'mo_id'::uuid);

-- =========================================================
-- PASO 2: Validar ManufacturingOrderLines creados
-- =========================================================
SELECT 
    'ManufacturingOrderLines' AS table_name,
    COUNT(*) AS count_total,
    COUNT(CASE WHEN deleted = false THEN 1 END) AS count_active
FROM public."ManufacturingOrderLines"
WHERE manufacturing_order_id = :'mo_id'::uuid;

-- Mostrar detalles de las líneas creadas
SELECT 
    mol.id,
    mol.sales_order_line_id,
    mol.status,
    mol.deleted,
    mol.created_at
FROM public."ManufacturingOrderLines" mol
WHERE mol.manufacturing_order_id = :'mo_id'::uuid
    AND mol.deleted = false
ORDER BY mol.created_at DESC;

-- =========================================================
-- PASO 3: Validar BomInstances creados
-- =========================================================
SELECT 
    'BomInstances' AS table_name,
    COUNT(*) AS count_total,
    COUNT(CASE WHEN deleted = false THEN 1 END) AS count_active
FROM public."BomInstances"
WHERE manufacturing_order_id = :'mo_id'::uuid;

-- Mostrar detalles de los BomInstances
SELECT 
    bi.id,
    bi.manufacturing_order_id,
    bi.sales_order_line_id,
    bi.bom_template_id,
    bi.status,
    bi.labor_cost,
    bi.total_cost_with_labor,
    bi.total_msrp_sale_out_with_labor,
    bi.deleted,
    bi.created_at,
    bi.generated_at
FROM public."BomInstances" bi
WHERE bi.manufacturing_order_id = :'mo_id'::uuid
    AND bi.deleted = false
ORDER BY bi.created_at DESC;

-- =========================================================
-- PASO 4: Validar BomInstanceLines creados
-- =========================================================
SELECT 
    'BomInstanceLines' AS table_name,
    COUNT(*) AS count_total,
    COUNT(CASE WHEN bil.deleted = false AND bi.deleted = false THEN 1 END) AS count_active
FROM public."BomInstanceLines" bil
JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.manufacturing_order_id = :'mo_id'::uuid;

-- Mostrar detalles de las líneas (primeras 20)
SELECT 
    bil.id,
    bil.bom_instance_id,
    bil.resolved_sku,
    bil.part_role,
    bil.category_code,
    bil.qty,
    bil.uom,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.deleted
FROM public."BomInstanceLines" bil
JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.manufacturing_order_id = :'mo_id'::uuid
    AND bi.deleted = false
    AND bil.deleted = false
ORDER BY bil.created_at DESC
LIMIT 20;

-- =========================================================
-- PASO 5: Resumen completo
-- =========================================================
SELECT 
    'RESUMEN' AS section,
    (SELECT COUNT(*) FROM public."ManufacturingOrderLines" WHERE manufacturing_order_id = :'mo_id'::uuid AND deleted = false) AS mo_lines,
    (SELECT COUNT(*) FROM public."BomInstances" WHERE manufacturing_order_id = :'mo_id'::uuid AND deleted = false) AS bom_instances,
    (SELECT COUNT(*) 
     FROM public."BomInstanceLines" bil
     JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
     WHERE bi.manufacturing_order_id = :'mo_id'::uuid
       AND bi.deleted = false
       AND bil.deleted = false) AS bom_lines;

