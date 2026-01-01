-- ====================================================
-- Script: Regenerate BOM for Sale Order 50-000008
-- ====================================================
-- This script regenerates BOM components for QuoteLines
-- in Sale Order 50-000008 now that product_type_id is fixed
-- ====================================================

DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_result jsonb;
    v_sale_order_no text := 'SO-000008';
BEGIN
    RAISE NOTICE '🔄 Regenerating BOM for Sale Order: %', v_sale_order_no;
    RAISE NOTICE '';
    
    -- Process each QuoteLine
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            COALESCE(ql.drive_type, 'manual') as drive_type,
            COALESCE(ql.bottom_rail_type, 'standard') as bottom_rail_type,
            COALESCE(ql.cassette, false) as cassette,
            ql.cassette_type,
            COALESCE(ql.side_channel, false) as side_channel,
            ql.side_channel_type,
            COALESCE(ql.hardware_color, 'white') as hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            pt.name as product_type_name
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
        WHERE so.sale_order_no = v_sale_order_no
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        BEGIN
            RAISE NOTICE '  Processing QuoteLine % (ProductType: %)', 
                v_quote_line_record.quote_line_id, 
                COALESCE(v_quote_line_record.product_type_name, 'Unknown');
            
            -- Call generate_configured_bom_for_quote_line function
            SELECT public.generate_configured_bom_for_quote_line(
                v_quote_line_record.quote_line_id,
                v_quote_line_record.product_type_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.cassette,
                v_quote_line_record.cassette_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.qty
            ) INTO v_result;
            
            IF v_result->>'success' = 'true' THEN
                v_updated_count := v_updated_count + 1;
                RAISE NOTICE '    ✅ Generated % components', v_result->>'count';
            ELSE
                v_error_count := v_error_count + 1;
                RAISE WARNING '    ❌ Error: %', COALESCE(v_result->>'error', v_result->>'message', 'Unknown error');
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING '    ❌ Exception for QuoteLine %: %', 
                    v_quote_line_record.quote_line_id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ Regeneration completed!';
    RAISE NOTICE '   ✅ Successfully regenerated: % QuoteLine(s)', v_updated_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '   ❌ Errors: % QuoteLine(s)', v_error_count;
    END IF;
END $$;

-- Verification: Show generated components
SELECT 
    'Generated Components' as check_type,
    ql.id as quote_line_id,
    qlc.component_role,
    qlc.source,
    qlc.uom,
    qlc.qty,
    ci.sku,
    ci.item_name
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, qlc.component_role;

-- Summary by component role
SELECT 
    'Summary by Component Role' as check_type,
    qlc.component_role,
    COUNT(*) as count,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role
ORDER BY qlc.component_role;

