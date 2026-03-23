-- =========================================================
-- Script de Validación: Migración 442 - BOM Generation
-- =========================================================
-- USO: Reemplazar :mo_id con el UUID real del ManufacturingOrder
-- Ejemplo: \set mo_id 'fd465c23-2f61-4ff5-954c-6c2a2418186c'
-- =========================================================

\set mo_id 'fd465c23-2f61-4ff5-954c-6c2a2418186c'

-- =========================================================
-- PASO 1: Verificar que la función existe y está correcta
-- =========================================================
SELECT 
    proname AS function_name,
    pg_get_function_arguments(oid) AS arguments,
    pg_get_functiondef(oid) LIKE '%manufacturing_order_id%' AS has_mo_id_param
FROM pg_proc
WHERE proname = 'generate_bom_for_manufacturing_order';

-- =========================================================
-- PASO 2: Verificar estado ANTES de generar BOM
-- =========================================================
SELECT 
    'BEFORE' AS status,
    (SELECT COUNT(*) FROM "ManufacturingOrderLines" WHERE manufacturing_order_id = :'mo_id'::uuid AND deleted = false) AS mo_lines,
    (SELECT COUNT(*) FROM "BomInstances" WHERE manufacturing_order_id = :'mo_id'::uuid AND deleted = false) AS bom_instances,
    (SELECT COUNT(*) 
     FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     WHERE bi.manufacturing_order_id = :'mo_id'::uuid
       AND bi.deleted = false
       AND bil.deleted = false) AS bom_lines;

-- =========================================================
-- PASO 3: Ejecutar RPC de generación de BOM
-- =========================================================
SELECT public.generate_bom_for_manufacturing_order(:'mo_id'::uuid) AS result;

-- =========================================================
-- PASO 4: Verificar estado DESPUÉS de generar BOM
-- =========================================================
SELECT 
    'AFTER' AS status,
    (SELECT COUNT(*) FROM "ManufacturingOrderLines" WHERE manufacturing_order_id = :'mo_id'::uuid AND deleted = false) AS mo_lines,
    (SELECT COUNT(*) FROM "BomInstances" WHERE manufacturing_order_id = :'mo_id'::uuid AND deleted = false) AS bom_instances,
    (SELECT COUNT(*) 
     FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     WHERE bi.manufacturing_order_id = :'mo_id'::uuid
       AND bi.deleted = false
       AND bil.deleted = false) AS bom_lines;

-- =========================================================
-- PASO 5: Verificar que manufacturing_order_id está lleno
-- =========================================================
SELECT 
    id,
    manufacturing_order_id,
    sales_order_line_id,
    bom_template_id,
    status,
    deleted,
    created_at
FROM "BomInstances"
WHERE manufacturing_order_id = :'mo_id'::uuid
    AND deleted = false
ORDER BY created_at DESC;

-- =========================================================
-- PASO 6: Verificar BomInstanceLines creados
-- =========================================================
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
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.manufacturing_order_id = :'mo_id'::uuid
    AND bi.deleted = false
    AND bil.deleted = false
ORDER BY bil.created_at DESC
LIMIT 20;

