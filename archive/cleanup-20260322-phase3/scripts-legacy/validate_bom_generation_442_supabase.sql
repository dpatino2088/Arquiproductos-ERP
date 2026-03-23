-- =========================================================
-- Script de Validación: Migración 442 - BOM Generation
-- Versión para Supabase SQL Editor (sin \set)
-- =========================================================
-- INSTRUCCIONES: 
-- 1. Reemplaza 'fd465c23-2f61-4ff5-954c-6c2a2418186c' con tu MO ID
-- 2. Ejecuta cada bloque por separado
-- =========================================================

-- Reemplaza 'fd465c23-2f61-4ff5-954c-6c2a2418186c' con el UUID de tu ManufacturingOrder

-- =========================================================
-- PASO 1: Verificar que la función existe
-- =========================================================
SELECT 
    proname AS function_name,
    pg_get_function_arguments(oid) AS arguments
FROM pg_proc
WHERE proname = 'generate_bom_for_manufacturing_order';

-- =========================================================
-- PASO 2: Verificar estado ANTES de generar BOM
-- =========================================================
SELECT 
    'BEFORE' AS status,
    (SELECT COUNT(*) FROM "ManufacturingOrderLines" WHERE manufacturing_order_id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid AND deleted = false) AS mo_lines,
    (SELECT COUNT(*) FROM "BomInstances" WHERE manufacturing_order_id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid AND deleted = false) AS bom_instances,
    (SELECT COUNT(*) 
     FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     WHERE bi.manufacturing_order_id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
       AND bi.deleted = false
       AND bil.deleted = false) AS bom_lines;

-- =========================================================
-- PASO 3: Verificar SalesOrderLines y product_type
-- =========================================================
SELECT 
    sol.id,
    sol.product_type,
    sol.collection_name,
    sol.variant_name,
    mo.id AS mo_id
FROM "SalesOrderLines" sol
JOIN "ManufacturingOrders" mo ON mo.sales_order_id = sol.sales_order_id
WHERE mo.id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
  AND sol.deleted = false;

-- =========================================================
-- PASO 4: Verificar BOM Templates disponibles para el product_type
-- =========================================================
SELECT 
    pt.code AS product_type_code,
    bt.id AS bom_template_id,
    bt.name AS template_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) AS components_count
FROM "ProductTypes" pt
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE pt.code IN (
    SELECT DISTINCT sol.product_type
    FROM "SalesOrderLines" sol
    JOIN "ManufacturingOrders" mo ON mo.sales_order_id = sol.sales_order_id
    WHERE mo.id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
      AND sol.deleted = false
      AND sol.product_type IS NOT NULL
)
GROUP BY pt.code, bt.id, bt.name, bt.active, bt.deleted
ORDER BY pt.code, bt.active DESC, bt.created_at DESC;

-- =========================================================
-- PASO 5: Ejecutar RPC de generación de BOM
-- =========================================================
SELECT public.generate_bom_for_manufacturing_order('fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid) AS result;

-- =========================================================
-- PASO 6: Verificar estado DESPUÉS de generar BOM
-- =========================================================
SELECT 
    'AFTER' AS status,
    (SELECT COUNT(*) FROM "ManufacturingOrderLines" WHERE manufacturing_order_id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid AND deleted = false) AS mo_lines,
    (SELECT COUNT(*) FROM "BomInstances" WHERE manufacturing_order_id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid AND deleted = false) AS bom_instances,
    (SELECT COUNT(*) 
     FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     WHERE bi.manufacturing_order_id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
       AND bi.deleted = false
       AND bil.deleted = false) AS bom_lines;

