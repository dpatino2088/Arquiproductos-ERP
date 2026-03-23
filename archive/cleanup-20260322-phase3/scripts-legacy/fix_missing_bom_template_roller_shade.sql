-- =========================================================
-- Solución: Crear/activar BOMTemplate para roller-shade
-- =========================================================
-- PROBLEMA: "No active BOMTemplate found for product_type: roller-shade"
-- Este script ayuda a crear o activar un BOMTemplate para resolver el problema
-- =========================================================

-- Reemplaza este UUID con el de tu ManufacturingOrder
-- 'fd465c23-2f61-4ff5-954c-6c2a2418186c'

-- =========================================================
-- PASO 1: Verificar si existe ProductType "roller-shade"
-- =========================================================
SELECT 
    pt.id,
    pt.code,
    pt.name,
    pt.deleted
FROM "ProductTypes" pt
WHERE pt.code = 'roller-shade';

-- =========================================================
-- PASO 2: Verificar si existe BOMTemplate (activo o inactivo) para roller-shade
-- =========================================================
SELECT 
    bt.id AS bom_template_id,
    bt.name AS template_name,
    bt.active,
    bt.deleted,
    pt.code AS product_type_code,
    COUNT(bc.id) AS components_count
FROM "BOMTemplates" bt
JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE pt.code = 'roller-shade'
GROUP BY bt.id, bt.name, bt.active, bt.deleted, pt.code
ORDER BY bt.active DESC, bt.created_at DESC;

-- =========================================================
-- PASO 3A: Si existe un BOMTemplate INACTIVO, activarlo
-- =========================================================
-- Descomenta y ejecuta solo si encontraste un template inactivo:
/*
UPDATE "BOMTemplates" bt
SET 
    active = true,
    updated_at = now()
FROM "ProductTypes" pt
WHERE bt.product_type_id = pt.id
  AND pt.code = 'roller-shade'
  AND bt.active = false
  AND bt.deleted = false
RETURNING bt.id, bt.name, bt.active;
*/

-- =========================================================
-- PASO 3B: Si NO existe BOMTemplate, crear uno básico
-- =========================================================
-- IMPORTANTE: Esto crea un template VACÍO (sin componentes)
-- Necesitarás agregar componentes después desde la UI
-- Descomenta y ejecuta solo si NO existe ningún template:
/*
INSERT INTO "BOMTemplates" (
    product_type_id,
    name,
    active,
    deleted,
    organization_id,
    created_at,
    updated_at
)
SELECT 
    pt.id AS product_type_id,
    'Roller Shade - Default Template' AS name,
    true AS active,
    false AS deleted,
    mo.organization_id,
    now() AS created_at,
    now() AS updated_at
FROM "ProductTypes" pt
CROSS JOIN "ManufacturingOrders" mo
WHERE pt.code = 'roller-shade'
  AND mo.id = 'fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid
  AND NOT EXISTS (
    SELECT 1 FROM "BOMTemplates" bt2
    JOIN "ProductTypes" pt2 ON pt2.id = bt2.product_type_id
    WHERE pt2.code = 'roller-shade'
    AND bt2.deleted = false
  )
LIMIT 1
RETURNING id, name, active;
*/

-- =========================================================
-- PASO 4: Después de crear/activar el template, 
-- ejecutar generate_bom_for_manufacturing_order de nuevo
-- =========================================================
-- SELECT public.generate_bom_for_manufacturing_order('fd465c23-2f61-4ff5-954c-6c2a2418186c'::uuid);

-- =========================================================
-- NOTA IMPORTANTE:
-- =========================================================
-- Un BOMTemplate sin componentes (BOMComponents) NO generará BomInstanceLines.
-- Necesitas:
-- 1. Crear el BOMTemplate (PASO 3B si no existe)
-- 2. Agregar BOMComponents al template (desde la UI de BOM Templates)
-- 3. Ejecutar generate_bom_for_manufacturing_order de nuevo

