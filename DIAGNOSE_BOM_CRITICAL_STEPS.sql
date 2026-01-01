-- ========================================
-- DIAGNÓSTICO CRÍTICO: BOM Solo Telas
-- ========================================
-- Este script muestra SOLO los 3 steps más críticos para identificar el problema
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- ========================================
-- CRITICAL STEP 1: ¿Tiene el BOMTemplate componentes además de fabric?
-- ========================================
-- Si este step muestra solo 'fabric', el problema es que el BOMTemplate está incompleto
SELECT 
  'CRITICAL 1: BOMTemplate Components' as check_name,
  bc.component_role,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ PROBLEM: No components found'
    WHEN COUNT(*) = 1 AND bc.component_role = 'fabric' THEN '❌ PROBLEM: Only fabric component (BOMTemplate incomplete)'
    WHEN COUNT(*) > 1 THEN '✅ OK: Multiple component types'
    ELSE '⚠️ WARNING: Check manually'
  END as status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bc.component_role
ORDER BY 
  CASE bc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- ========================================
-- CRITICAL STEP 2: ¿Pueden resolverse los BOMComponents?
-- ========================================
-- Si este step muestra "MISSING", los componentes no tienen component_item_id ni auto_select
SELECT 
  'CRITICAL 2: BOMComponents Resolution' as check_name,
  bc.component_role,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule,
  CASE 
    WHEN bc.component_item_id IS NOT NULL THEN '✅ HAS: Direct item_id'
    WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NOT NULL THEN '✅ HAS: Auto-select'
    WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN '❌ MISSING: Cannot resolve'
    ELSE '⚠️ UNKNOWN'
  END as resolution_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE bc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- ========================================
-- CRITICAL STEP 3: ¿Qué se generó en QuoteLineComponents?
-- ========================================
-- Si este step muestra solo 'fabric', el problema está en la generación
SELECT 
  'CRITICAL 3: QuoteLineComponents Generated' as check_name,
  qlc.component_role,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component' 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE qlc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- ========================================
-- INTERPRETACIÓN RÁPIDA
-- ========================================
-- 
-- Si CRITICAL 1 muestra "Only fabric component":
--   → PROBLEMA: BOMTemplate incompleto
--   → SOLUCIÓN: Ejecutar FIX_BOM_TEMPLATE_COMPONENTS.sql
--
-- Si CRITICAL 2 muestra "MISSING: Cannot resolve":
--   → PROBLEMA: BOMComponents no pueden resolverse
--   → SOLUCIÓN: Ejecutar FIX_BOM_COMPONENTS_RESOLUTION.sql
--
-- Si CRITICAL 3 muestra solo 'fabric':
--   → PROBLEMA: La función solo generó fabric
--   → CAUSA: Revisar CRITICAL 1 y CRITICAL 2 (probablemente uno de esos es el problema)
--
-- ========================================








