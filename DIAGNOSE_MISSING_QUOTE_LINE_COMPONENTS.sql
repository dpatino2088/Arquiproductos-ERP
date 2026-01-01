-- ====================================================
-- DIAGNÓSTICO: Por qué no hay QuoteLineComponents
-- ====================================================
-- Este script verifica si existen BOMTemplates y BOMComponents
-- necesarios para generar QuoteLineComponents

-- ====================================================
-- PARTE 1: Verificar QuoteLines y sus product_type_id
-- ====================================================

SELECT 
  'QuoteLines para SO-000002' as check_type,
  ql.id as quote_line_id,
  ql.product_type_id,
  ql.catalog_item_id,
  ql.qty,
  ql.width_m,
  ql.height_m,
  pt.name as product_type_name,
  ci.item_name as catalog_item_name
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
ORDER BY ql.created_at;

-- ====================================================
-- PARTE 2: Verificar si existen BOMTemplates para esos product_type_id
-- ====================================================

SELECT 
  'BOMTemplates Check' as check_type,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.name as product_type_name,
  bt.id as bom_template_id,
  bt.active as template_active,
  bt.deleted as template_deleted,
  CASE 
    WHEN bt.id IS NULL THEN '❌ NO existe BOMTemplate'
    WHEN bt.deleted = true THEN '❌ BOMTemplate está deleted'
    WHEN bt.active = false THEN '❌ BOMTemplate está inactive'
    ELSE '✅ BOMTemplate OK'
  END as template_status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
  AND bt.organization_id = q.organization_id
  AND bt.deleted = false
  AND bt.active = true
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
ORDER BY ql.created_at;

-- ====================================================
-- PARTE 3: Verificar BOMComponents en los BOMTemplates
-- ====================================================

SELECT 
  'BOMComponents Check' as check_type,
  ql.id as quote_line_id,
  bt.id as bom_template_id,
  COUNT(bc.id) as bom_components_count,
  COUNT(CASE WHEN bc.deleted = false THEN 1 END) as active_bom_components_count,
  CASE 
    WHEN bt.id IS NULL THEN '❌ No BOMTemplate'
    WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate sin BOMComponents'
    WHEN COUNT(CASE WHEN bc.deleted = false THEN 1 END) = 0 THEN '❌ Todos los BOMComponents están deleted'
    ELSE '✅ BOMComponents OK'
  END as components_status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
  AND bt.organization_id = q.organization_id
  AND bt.deleted = false
  AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id, bt.id
ORDER BY ql.created_at;

-- ====================================================
-- PARTE 4: Intentar ejecutar generate_configured_bom_for_quote_line manualmente
-- ====================================================
-- NOTA: Ejecuta esto SOLO si las partes anteriores muestran que hay BOMTemplate y BOMComponents

-- Primero, obtén los valores necesarios de la query PARTE 1
-- Luego ejecuta esto reemplazando los valores:

/*
DO $$
DECLARE
    v_quote_line_id uuid;
    v_product_type_id uuid;
    v_organization_id uuid;
    v_result jsonb;
BEGIN
    -- Obtener valores del primer QuoteLine de SO-000002
    SELECT 
        ql.id,
        ql.product_type_id,
        q.organization_id
    INTO 
        v_quote_line_id,
        v_product_type_id,
        v_organization_id
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    INNER JOIN "SaleOrders" so ON so.quote_id = q.id
    WHERE so.sale_order_no = 'SO-000002'
      AND ql.deleted = false
    ORDER BY ql.created_at
    LIMIT 1;
    
    IF v_quote_line_id IS NULL THEN
        RAISE EXCEPTION 'No QuoteLine found for SO-000002';
    END IF;
    
    RAISE NOTICE '🔧 Testing generate_configured_bom_for_quote_line for quote_line_id: %', v_quote_line_id;
    
    -- Intentar generar BOM (ajusta los parámetros según el QuoteLine)
    v_result := public.generate_configured_bom_for_quote_line(
        p_quote_line_id := v_quote_line_id,
        p_product_type_id := v_product_type_id,
        p_organization_id := v_organization_id,
        p_drive_type := 'motor', -- Ajusta según el QuoteLine
        p_bottom_rail_type := 'standard',
        p_cassette := false,
        p_cassette_type := null,
        p_side_channel := false,
        p_side_channel_type := null,
        p_hardware_color := 'white',
        p_width_m := 2.0, -- Ajusta según el QuoteLine
        p_height_m := 2.0, -- Ajusta según el QuoteLine
        p_qty := 1
    );
    
    RAISE NOTICE '✅ BOM generation result: %', v_result;
END $$;
*/

-- ====================================================
-- PARTE 5: Resumen ejecutivo
-- ====================================================

SELECT 
  'RESUMEN EJECUTIVO' as summary_type,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002' AND ql.deleted = false) as total_quote_lines,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
     AND bt.organization_id = q.organization_id
     AND bt.deleted = false
     AND bt.active = true
   WHERE so.sale_order_no = 'SO-000002' 
     AND ql.deleted = false
     AND bt.id IS NOT NULL) as quote_lines_with_bom_template,
  (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
   INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002'
     AND qlc.deleted = false
     AND qlc.source = 'configured_component') as configured_components_created;

