-- ====================================================
-- Script: Regenerate BOM for Specific QuoteLines
-- ====================================================
-- This script regenerates BOM components for specific QuoteLines
-- that are missing components (only have fabric)
-- ====================================================

DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_result jsonb;
BEGIN
    RAISE NOTICE '🔄 Regenerating BOM for QuoteLines with missing components...';
    
    -- Process QuoteLines from SO-000008 that have missing components
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
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            q.quote_no,
            -- Count existing components
            (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
             WHERE qlc.quote_line_id = ql.id 
             AND qlc.deleted = false 
             AND qlc.source = 'configured_component') as existing_components
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE so.sale_order_no = 'SO-000008'
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
        -- Only process QuoteLines with missing components (less than 5 components = likely incomplete)
        AND (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
             WHERE qlc.quote_line_id = ql.id 
             AND qlc.deleted = false 
             AND qlc.source = 'configured_component') < 5
        ORDER BY ql.id
    LOOP
        BEGIN
            RAISE NOTICE '';
            RAISE NOTICE '📦 Processing QuoteLine: % (Quote: %)', v_quote_line_record.quote_line_id, v_quote_line_record.quote_no;
            RAISE NOTICE '   - Existing components: %', v_quote_line_record.existing_components;
            RAISE NOTICE '   - Configuration: drive_type=%, bottom_rail_type=%, cassette=%, side_channel=%, hardware_color=%', 
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.cassette,
                v_quote_line_record.side_channel,
                v_quote_line_record.hardware_color;
            
            -- Check required fields
            IF v_quote_line_record.drive_type IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % has no drive_type, setting to ''manual''', v_quote_line_record.quote_line_id;
                UPDATE "QuoteLines" 
                SET drive_type = 'manual', updated_at = NOW()
                WHERE id = v_quote_line_record.quote_line_id;
                v_quote_line_record.drive_type := 'manual';
            END IF;
            
            IF v_quote_line_record.bottom_rail_type IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % has no bottom_rail_type, setting to ''standard''', v_quote_line_record.quote_line_id;
                UPDATE "QuoteLines" 
                SET bottom_rail_type = 'standard', updated_at = NOW()
                WHERE id = v_quote_line_record.quote_line_id;
                v_quote_line_record.bottom_rail_type := 'standard';
            END IF;
            
            -- Regenerate BOM for this quote line
            v_result := public.generate_configured_bom_for_quote_line(
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
            );
            
            -- Check result
            IF v_result->>'success' = 'true' THEN
                RAISE NOTICE '   ✅ BOM regenerated: % components created', v_result->>'count';
                v_updated_count := v_updated_count + 1;
            ELSE
                RAISE WARNING '   ❌ BOM generation failed: %', v_result->>'message';
                v_error_count := v_error_count + 1;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ❌ Error regenerating BOM for QuoteLine %: %', 
                    v_quote_line_record.quote_line_id,
                    SQLERRM;
                v_error_count := v_error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM regeneration completed!';
    RAISE NOTICE '   - Successfully processed: % QuoteLines', v_updated_count;
    RAISE NOTICE '   - Errors: % QuoteLines', v_error_count;
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Run CHECK_QUOTELINE_COMPONENTS_FOR_SO.sql again to verify components were created';
    RAISE NOTICE '   2. Run FIX_BOM_INSTANCE_LINES_FOR_SO.sql to copy components to BomInstanceLines';
    RAISE NOTICE '   3. Refresh the Manufacturing Order page to see all components';
    
END $$;

-- Show summary of components after regeneration
SELECT 
    'After Regeneration' as check_type,
    qlc.component_role,
    COUNT(*) as count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role
ORDER BY count DESC;








