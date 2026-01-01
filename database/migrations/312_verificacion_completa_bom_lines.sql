-- ====================================================
-- Migration 312: Verificación Completa de BomInstanceLines
-- Script consolidado para diagnóstico completo
-- ====================================================

-- ============================================
-- PARTE 1: Verificación de Estructura de Datos
-- ============================================
SELECT 
    '=== PARTE 1: ESTRUCTURA DE DATOS ===' as section;

SELECT 
    'ManufacturingOrder' as entity,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '❌' END as status
FROM "ManufacturingOrders" mo
WHERE mo.manufacturing_order_no = 'MO-000002'
AND mo.deleted = false

UNION ALL

SELECT 
    'SalesOrder',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '❌' END
FROM "SalesOrders" so
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND so.deleted = false

UNION ALL

SELECT 
    'SalesOrderLines',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '❌' END
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND sol.deleted = false

UNION ALL

SELECT 
    'BomInstances',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '❌' END
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false

UNION ALL

SELECT 
    'BomInstanceLines',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '❌ PROBLEMA' ELSE '✅' END
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bil.deleted = false

UNION ALL

SELECT 
    'QuoteLineComponents (configured)',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '❌' END
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND qlc.deleted = false
AND qlc.source = 'configured_component';

-- ============================================
-- PARTE 2: Verificación de Coincidencia de IDs
-- ============================================
SELECT 
    '=== PARTE 2: COINCIDENCIA DE IDs ===' as section;

SELECT 
    bi.id::text as bom_instance_id,
    bi.quote_line_id::text,
    bi.sale_order_line_id::text,
    sol.quote_line_id::text as sol_quote_line_id,
    CASE 
        WHEN bi.quote_line_id = sol.quote_line_id THEN '✅ Match'
        ELSE '❌ Mismatch'
    END as id_match_status
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false;

-- ============================================
-- PARTE 3: Verificación de QuoteLineComponents
-- ============================================
SELECT 
    '=== PARTE 3: QUOTE LINE COMPONENTS ===' as section;

SELECT 
    bi.id::text as bom_instance_id,
    bi.quote_line_id::text,
    COUNT(*) as total_qlc,
    COUNT(*) FILTER (WHERE qlc.source = 'configured_component') as qlc_configured,
    COUNT(*) FILTER (WHERE qlc.source != 'configured_component') as qlc_other_source,
    STRING_AGG(DISTINCT qlc.source, ', ') as all_sources
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id AND qlc.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false
GROUP BY bi.id, bi.quote_line_id;

-- ============================================
-- PARTE 4: Verificación de Valores NULL
-- ============================================
SELECT 
    '=== PARTE 4: VALIDACIÓN DE DATOS ===' as section;

SELECT 
    qlc.id::text as qlc_id,
    qlc.quote_line_id::text,
    qlc.catalog_item_id::text,
    qlc.component_role,
    qlc.source,
    qlc.qty,
    qlc.uom,
    ci.sku,
    CASE 
        WHEN qlc.catalog_item_id IS NULL THEN '❌ NULL catalog_item_id'
        WHEN qlc.component_role IS NULL THEN '❌ NULL component_role'
        WHEN qlc.qty IS NULL THEN '❌ NULL qty'
        WHEN qlc.uom IS NULL THEN '❌ NULL uom'
        ELSE '✅ OK'
    END as validation_status
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
AND bi.deleted = false
AND sol.deleted = false
ORDER BY bi.id, qlc.component_role;

-- ============================================
-- PARTE 5: Verificación de BomInstanceLines Existentes
-- ============================================
SELECT 
    '=== PARTE 5: BOM INSTANCE LINES EXISTENTES ===' as section;

SELECT 
    bi.id::text as bom_instance_id,
    COUNT(bil.id) as existing_bil_count,
    CASE 
        WHEN COUNT(bil.id) = 0 THEN '❌ No hay líneas'
        ELSE '⚠️ Ya existen líneas'
    END as status
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false
GROUP BY bi.id;

-- ============================================
-- PARTE 6: Verificación de Conflictos Potenciales
-- ============================================
SELECT 
    '=== PARTE 6: CONFLICTOS POTENCIALES ===' as section;

SELECT 
    bi.id::text as bom_instance_id,
    qlc.catalog_item_id::text,
    qlc.component_role as part_role,
    CASE qlc.uom
        WHEN 'm' THEN 'mts'
        WHEN 'm2' THEN 'm2'
        WHEN 'ea' THEN 'ea'
        WHEN 'pcs' THEN 'ea'
        ELSE COALESCE(qlc.uom, 'ea')
    END as mapped_uom,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM "BomInstanceLines" bil
            WHERE bil.bom_instance_id = bi.id
            AND bil.resolved_part_id = qlc.catalog_item_id
            AND bil.part_role = qlc.component_role
            AND bil.uom = CASE qlc.uom
                WHEN 'm' THEN 'mts'
                WHEN 'm2' THEN 'm2'
                WHEN 'ea' THEN 'ea'
                WHEN 'pcs' THEN 'ea'
                ELSE COALESCE(qlc.uom, 'ea')
            END
            AND bil.deleted = false
        ) THEN '⚠️ CONFLICT - Ya existe'
        ELSE '✅ Ready to insert'
    END as conflict_status
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY bi.id, qlc.component_role;

-- ============================================
-- PARTE 7: Verificación de Constraints
-- ============================================
SELECT 
    '=== PARTE 7: CONSTRAINTS DE LA TABLA ===' as section;

SELECT 
    conname as constraint_name,
    CASE contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'c' THEN 'CHECK'
        ELSE contype::text
    END as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = '"BomInstanceLines"'::regclass
ORDER BY contype, conname;

-- ============================================
-- PARTE 8: Resumen Final
-- ============================================
SELECT 
    '=== RESUMEN FINAL ===' as section;

SELECT 
    (SELECT COUNT(*) FROM "BomInstances" bi
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND bi.deleted = false) as bom_instances_count,
    
    (SELECT COUNT(*) FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND bil.deleted = false) as bom_lines_count,
    
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
     JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002'
     AND qlc.deleted = false
     AND qlc.source = 'configured_component') as qlc_configured_count,
    
    CASE 
        WHEN (SELECT COUNT(*) FROM "BomInstanceLines" bil
              JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
              JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
              JOIN "SalesOrders" so ON so.id = sol.sale_order_id
              JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
              WHERE mo.manufacturing_order_no = 'MO-000002' 
              AND bil.deleted = false) = 0
        AND (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
             JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
             JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
             JOIN "SalesOrders" so ON so.id = sol.sale_order_id
             JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
             WHERE mo.manufacturing_order_no = 'MO-000002'
             AND qlc.deleted = false
             AND qlc.source = 'configured_component') > 0
        THEN '❌ PROBLEMA CONFIRMADO: Hay QuoteLineComponents pero NO hay BomInstanceLines'
        ELSE '✅ Estado normal'
    END as diagnosis;


