-- ====================================================
-- FIX: Agregar product_type_id a QuoteLines y generar BOM
-- ====================================================
-- Este script:
-- 1. Identifica QuoteLines sin product_type_id
-- 2. Intenta derivar product_type_id desde catalog_item_id
-- 3. Genera QuoteLineComponents usando generate_configured_bom_for_quote_line
-- ====================================================

-- ====================================================
-- PASO 1: Diagnosticar QuoteLines sin product_type_id
-- ====================================================

SELECT 
  'PASO 1: QuoteLines sin product_type_id' as step,
  ql.id as quote_line_id,
  ql.catalog_item_id,
  ql.product_type_id,
  ci.item_name,
  ci.sku,
  ci.family,
  ci.item_type,
  -- Intentar obtener product_type_id desde CatalogItemProductTypes
  cpt.product_type_id as suggested_product_type_id,
  pt.name as suggested_product_type_name
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
LEFT JOIN "CatalogItemProductTypes" cpt ON cpt.catalog_item_id = ci.id 
  AND cpt.organization_id = q.organization_id
  AND cpt.deleted = false
  AND cpt.is_primary = true
LEFT JOIN "ProductTypes" pt ON pt.id = cpt.product_type_id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
  AND ql.product_type_id IS NULL
ORDER BY ql.created_at;

-- ====================================================
-- PASO 2: Actualizar QuoteLines con product_type_id desde CatalogItemProductTypes
-- ====================================================

DO $$
DECLARE
    v_updated_count integer := 0;
    v_quote_line_record record;
BEGIN
    RAISE NOTICE '🔧 PASO 2: Actualizando QuoteLines con product_type_id...';
    
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.catalog_item_id,
            q.organization_id,
            cpt.product_type_id
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
        INNER JOIN "CatalogItemProductTypes" cpt ON cpt.catalog_item_id = ci.id 
          AND cpt.organization_id = q.organization_id
          AND cpt.deleted = false
          AND cpt.is_primary = true
        WHERE so.sale_order_no = 'SO-000002'
          AND ql.deleted = false
          AND ql.product_type_id IS NULL
    LOOP
        UPDATE "QuoteLines"
        SET product_type_id = v_quote_line_record.product_type_id,
            updated_at = NOW()
        WHERE id = v_quote_line_record.quote_line_id;
        
        v_updated_count := v_updated_count + 1;
        RAISE NOTICE '   ✅ Updated QuoteLine % with product_type_id %', 
            v_quote_line_record.quote_line_id, 
            v_quote_line_record.product_type_id;
    END LOOP;
    
    RAISE NOTICE '✅ Updated % QuoteLines with product_type_id', v_updated_count;
END $$;

-- ====================================================
-- PASO 3: Verificar BOMTemplates después de actualizar product_type_id
-- ====================================================

SELECT 
  'PASO 3: BOMTemplates después de actualizar' as step,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.name as product_type_name,
  q.organization_id,
  bt.id as bom_template_id,
  bt.name as bom_template_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as bom_components_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
  AND bt.organization_id = q.organization_id
  AND bt.deleted = false
  AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id, ql.product_type_id, pt.name, q.organization_id, bt.id, bt.name, bt.active, bt.deleted
ORDER BY ql.created_at;

-- ====================================================
-- PASO 4: Generar QuoteLineComponents manualmente
-- ====================================================
-- NOTA: Este paso requiere que existan BOMTemplates y BOMComponents
-- Si no existen, necesitarás crearlos primero

DO $$
DECLARE
    v_quote_line_record record;
    v_bom_result jsonb;
    v_generated_count integer := 0;
    v_failed_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 PASO 4: Generando QuoteLineComponents...';
    
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            q.organization_id,
            ql.qty,
            ql.width_m,
            ql.height_m,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            ql.side_channel_type,
            ql.hardware_color
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE so.sale_order_no = 'SO-000002'
          AND ql.deleted = false
          AND ql.product_type_id IS NOT NULL
        ORDER BY ql.created_at
    LOOP
        BEGIN
            -- Verificar que existe BOMTemplate
            IF NOT EXISTS (
                SELECT 1 FROM "BOMTemplates" bt
                WHERE bt.product_type_id = v_quote_line_record.product_type_id
                  AND bt.organization_id = v_quote_line_record.organization_id
                  AND bt.deleted = false
                  AND bt.active = true
            ) THEN
                RAISE WARNING '⚠️  No BOMTemplate found for QuoteLine % (product_type_id: %)', 
                    v_quote_line_record.quote_line_id, 
                    v_quote_line_record.product_type_id;
                v_failed_count := v_failed_count + 1;
                CONTINUE;
            END IF;
            
            -- Generar BOM
            v_bom_result := public.generate_configured_bom_for_quote_line(
                p_quote_line_id := v_quote_line_record.quote_line_id,
                p_product_type_id := v_quote_line_record.product_type_id,
                p_organization_id := v_quote_line_record.organization_id,
                p_drive_type := COALESCE(v_quote_line_record.drive_type, 'motor'),
                p_bottom_rail_type := COALESCE(v_quote_line_record.bottom_rail_type, 'standard'),
                p_cassette := COALESCE(v_quote_line_record.cassette, false),
                p_cassette_type := v_quote_line_record.cassette_type,
                p_side_channel := COALESCE(v_quote_line_record.side_channel, false),
                p_side_channel_type := v_quote_line_record.side_channel_type,
                p_hardware_color := COALESCE(v_quote_line_record.hardware_color, 'white'),
                p_width_m := COALESCE(v_quote_line_record.width_m, 0),
                p_height_m := COALESCE(v_quote_line_record.height_m, 0),
                p_qty := COALESCE(v_quote_line_record.qty, 1)
            );
            
            v_generated_count := v_generated_count + 1;
            RAISE NOTICE '   ✅ Generated BOM for QuoteLine %: % components', 
                v_quote_line_record.quote_line_id,
                v_bom_result->>'components_count';
                
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error generating BOM for QuoteLine %: %', 
                    v_quote_line_record.quote_line_id, 
                    SQLERRM;
                v_failed_count := v_failed_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Generated BOM for % QuoteLines', v_generated_count;
    IF v_failed_count > 0 THEN
        RAISE WARNING '⚠️  Failed to generate BOM for % QuoteLines', v_failed_count;
    END IF;
END $$;

-- ====================================================
-- PASO 5: Verificar QuoteLineComponents creados
-- ====================================================

SELECT 
  'PASO 5: QuoteLineComponents creados' as step,
  ql.id as quote_line_id,
  qlc.id as qlc_id,
  qlc.source,
  qlc.component_role,
  qlc.catalog_item_id,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
ORDER BY ql.created_at, qlc.id;

-- ====================================================
-- PASO 6: Resumen final
-- ====================================================

SELECT 
  'RESUMEN FINAL' as summary_type,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002' AND ql.deleted = false) as total_quote_lines,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002' 
     AND ql.deleted = false
     AND ql.product_type_id IS NOT NULL) as quote_lines_with_product_type,
  (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
   INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002'
     AND qlc.deleted = false
     AND qlc.source = 'configured_component') as configured_components_created;








