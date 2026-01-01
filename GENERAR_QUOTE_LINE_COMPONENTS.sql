-- ====================================================
-- GENERAR QuoteLineComponents usando el BOMTemplate correcto
-- ====================================================
-- Este script genera QuoteLineComponents usando el BOMTemplate
-- que tiene componentes (no el que tiene 0)

DO $$
DECLARE
    v_quote_line_record record;
    v_bom_template_id uuid;
    v_bom_result jsonb;
    v_generated_count integer := 0;
    v_failed_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Generando QuoteLineComponents para SO-000002...';
    
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
            -- Seleccionar el BOMTemplate que tiene más componentes
            SELECT bt.id INTO v_bom_template_id
            FROM "BOMTemplates" bt
            INNER JOIN (
                SELECT 
                    bom_template_id,
                    COUNT(*) as component_count
                FROM "BOMComponents"
                WHERE deleted = false
                GROUP BY bom_template_id
            ) bc_count ON bc_count.bom_template_id = bt.id
            WHERE bt.product_type_id = v_quote_line_record.product_type_id
              AND bt.organization_id = v_quote_line_record.organization_id
              AND bt.deleted = false
              AND bt.active = true
              AND bc_count.component_count > 0
            ORDER BY bc_count.component_count DESC, bt.created_at DESC
            LIMIT 1;
            
            IF v_bom_template_id IS NULL THEN
                RAISE WARNING '⚠️  No BOMTemplate with components found for QuoteLine % (product_type_id: %)', 
                    v_quote_line_record.quote_line_id, 
                    v_quote_line_record.product_type_id;
                v_failed_count := v_failed_count + 1;
                CONTINUE;
            END IF;
            
            RAISE NOTICE '   📋 Using BOMTemplate % for QuoteLine %', 
                v_bom_template_id, 
                v_quote_line_record.quote_line_id;
            
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
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Generated BOM for % QuoteLines', v_generated_count;
    IF v_failed_count > 0 THEN
        RAISE WARNING '⚠️  Failed to generate BOM for % QuoteLines', v_failed_count;
    END IF;
END $$;

-- Verificar QuoteLineComponents creados
SELECT 
  'QuoteLineComponents creados' as check_name,
  ql.id as quote_line_id,
  COUNT(qlc.id) as total_components,
  COUNT(CASE WHEN qlc.source = 'configured_component' THEN 1 END) as configured_components
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id;








