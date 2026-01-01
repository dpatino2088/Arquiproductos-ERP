-- ========================================
-- MASTER SCRIPT: Solución Integral BOM
-- ========================================
-- Este script ejecuta el diagnóstico completo y proporciona guía para las correcciones
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number

-- ========================================
-- PARTE 1: DIAGNÓSTICO COMPLETO
-- ========================================

DO $$
DECLARE
  v_sale_order_id uuid;
  v_quote_line_id uuid;
  v_bom_template_id uuid;
  v_organization_id uuid;
  v_product_type_id uuid;
  v_has_invalid_config boolean := false;
  v_has_incomplete_template boolean := false;
  v_has_unresolved_components boolean := false;
  v_has_blocked_components boolean := false;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DIAGNÓSTICO COMPLETO DEL BOM';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Get Sale Order ID
  SELECT id, organization_id INTO v_sale_order_id, v_organization_id
  FROM "SaleOrders"
  WHERE sale_order_no = 'SO-000003' -- CHANGE THIS
    AND deleted = false
  LIMIT 1;

  IF v_sale_order_id IS NULL THEN
    RAISE EXCEPTION 'Sale Order % not found', :sale_order_no_param;
  END IF;

  -- Get QuoteLine ID
  SELECT ql.id, ql.product_type_id INTO v_quote_line_id, v_product_type_id
  FROM "SaleOrderLines" sol
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
  WHERE sol.sale_order_id = v_sale_order_id
    AND sol.deleted = false
    AND ql.deleted = false
  LIMIT 1;

  IF v_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'No QuoteLine found for Sale Order %', :sale_order_no_param;
  END IF;

  -- Get BOMTemplate ID
  SELECT id INTO v_bom_template_id
  FROM "BOMTemplates"
  WHERE product_type_id = v_product_type_id
    AND organization_id = v_organization_id
    AND deleted = false
    AND active = true
  LIMIT 1;

  IF v_bom_template_id IS NULL THEN
    RAISE WARNING '❌ PROBLEMA: No BOMTemplate found for ProductType ID: %', v_product_type_id;
    v_has_incomplete_template := true;
  END IF;

  RAISE NOTICE '✅ IDs obtenidos:';
  RAISE NOTICE '   Sale Order ID: %', v_sale_order_id;
  RAISE NOTICE '   Quote Line ID: %', v_quote_line_id;
  RAISE NOTICE '   BOM Template ID: %', v_bom_template_id;
  RAISE NOTICE '   Organization ID: %', v_organization_id;
  RAISE NOTICE '   Product Type ID: %', v_product_type_id;
  RAISE NOTICE '';

  -- Check 1: QuoteLine Configuration
  RAISE NOTICE 'CHECK 1: Verificando configuración de QuoteLine...';
  SELECT 
    CASE 
      WHEN drive_type IS NULL OR bottom_rail_type IS NULL OR cassette IS NULL 
           OR side_channel IS NULL OR hardware_color IS NULL 
      THEN true
      ELSE false
    END INTO v_has_invalid_config
  FROM "QuoteLines"
  WHERE id = v_quote_line_id
    AND deleted = false;

  IF v_has_invalid_config THEN
    RAISE WARNING '❌ PROBLEMA: QuoteLine tiene campos de configuración NULL';
    RAISE NOTICE '   → Solución: Ejecutar FIX_MISSING_BOTTOM_RAIL_TYPE.sql';
  ELSE
    RAISE NOTICE '✅ OK: QuoteLine tiene toda la configuración';
  END IF;
  RAISE NOTICE '';

  -- Check 2: BOMTemplate Components
  IF v_bom_template_id IS NOT NULL THEN
    RAISE NOTICE 'CHECK 2: Verificando BOMTemplate y componentes...';
    SELECT 
      CASE 
        WHEN COUNT(*) = 0 THEN true
        WHEN COUNT(*) = 1 AND COUNT(CASE WHEN component_role = 'fabric' THEN 1 END) = 1 THEN true
        ELSE false
      END INTO v_has_incomplete_template
    FROM "BOMComponents"
    WHERE bom_template_id = v_bom_template_id
      AND deleted = false;

    IF v_has_incomplete_template THEN
      RAISE WARNING '❌ PROBLEMA: BOMTemplate incompleto (solo tiene fabric o está vacío)';
      RAISE NOTICE '   → Solución: Ejecutar FIX_BOM_TEMPLATE_COMPONENTS.sql';
      RAISE NOTICE '   → BOM Template ID: %', v_bom_template_id;
    ELSE
      RAISE NOTICE '✅ OK: BOMTemplate tiene múltiples componentes';
    END IF;
    RAISE NOTICE '';

    -- Check 3: BOMComponents Resolution
    RAISE NOTICE 'CHECK 3: Verificando resolución de BOMComponents...';
    SELECT 
      CASE 
        WHEN COUNT(CASE WHEN component_item_id IS NULL AND (auto_select = false OR sku_resolution_rule IS NULL) THEN 1 END) > 0 
        THEN true
        ELSE false
      END INTO v_has_unresolved_components
    FROM "BOMComponents"
    WHERE bom_template_id = v_bom_template_id
      AND deleted = false;

    IF v_has_unresolved_components THEN
      RAISE WARNING '❌ PROBLEMA: Algunos BOMComponents no pueden resolverse (falta component_item_id o auto_select)';
      RAISE NOTICE '   → Solución: Ejecutar FIX_BOM_COMPONENTS_RESOLUTION.sql';
      RAISE NOTICE '   → BOM Template ID: %', v_bom_template_id;
    ELSE
      RAISE NOTICE '✅ OK: Todos los BOMComponents pueden resolverse';
    END IF;
    RAISE NOTICE '';
  END IF;

  -- Summary
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RESUMEN DEL DIAGNÓSTICO';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  IF v_has_invalid_config THEN
    RAISE NOTICE '❌ Configuración incompleta en QuoteLine';
  ELSE
    RAISE NOTICE '✅ Configuración completa en QuoteLine';
  END IF;

  IF v_has_incomplete_template THEN
    RAISE NOTICE '❌ BOMTemplate incompleto';
  ELSE
    RAISE NOTICE '✅ BOMTemplate completo';
  END IF;

  IF v_has_unresolved_components THEN
    RAISE NOTICE '❌ BOMComponents sin resolución';
  ELSE
    RAISE NOTICE '✅ BOMComponents con resolución';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PRÓXIMOS PASOS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '1. Ejecutar DIAGNOSE_BOM_COMPLETE.sql para diagnóstico detallado';
  RAISE NOTICE '2. Basado en los resultados, ejecutar el script de corrección correspondiente:';
  
  IF v_has_invalid_config THEN
    RAISE NOTICE '   → FIX_MISSING_BOTTOM_RAIL_TYPE.sql';
  END IF;
  
  IF v_has_incomplete_template THEN
    RAISE NOTICE '   → FIX_BOM_TEMPLATE_COMPONENTS.sql (BOM Template ID: %)', v_bom_template_id;
  END IF;
  
  IF v_has_unresolved_components THEN
    RAISE NOTICE '   → FIX_BOM_COMPONENTS_RESOLUTION.sql (BOM Template ID: %)', v_bom_template_id;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '3. Después de las correcciones, re-configurar el QuoteLine';
  RAISE NOTICE '4. Verificar que todos los componentes aparecen en QuoteLineComponents';
  RAISE NOTICE '5. Aprobar el Quote y verificar BomInstanceLines';
  RAISE NOTICE '';

END $$;

-- ========================================
-- PARTE 2: MOSTRAR DATOS DETALLADOS
-- ========================================

-- Mostrar configuración actual
SELECT 
  'Current QuoteLine Config' as info_type,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.cassette_type,
  ql.side_channel,
  ql.side_channel_type,
  ql.hardware_color
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
LIMIT 1;

-- Mostrar BOMTemplate y componentes
SELECT 
  'BOMTemplate Components' as info_type,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule
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
ORDER BY bc.sequence_order;

-- Mostrar QuoteLineComponents generados
SELECT 
  'QuoteLineComponents Generated' as info_type,
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
ORDER BY qlc.component_role;

