-- ====================================================
-- Script: Final BOM Regeneration for SO-000008
-- ====================================================
-- Now that BOMTemplate is correctly configured,
-- regenerate the BOM to generate all components
-- ====================================================

-- Step 1: Verify current state
SELECT 
    'Step 1: Current QuoteLineComponents' as check_type,
    ql.id as quote_line_id,
    qlc.component_role,
    qlc.source,
    qlc.uom,
    qlc.qty,
    ci.sku,
    ci.item_name,
    public.derive_category_code_from_role(qlc.component_role) as category_code
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, qlc.component_role;

-- Step 2: REGENERATE BOM
DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_result jsonb;
BEGIN
    RAISE NOTICE '🔄 Step 2: Regenerating BOM for SO-000008...';
    RAISE NOTICE '';
    
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
            pt.name as product_type_name,
            bt.name as template_name
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
        LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
            AND bt.organization_id = ql.organization_id 
            AND bt.deleted = false
            AND bt.active = true
        WHERE so.sale_order_no = 'SO-000008'
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        BEGIN
            RAISE NOTICE '  Processing QuoteLine %', v_quote_line_record.quote_line_id;
            RAISE NOTICE '    ProductType: %', COALESCE(v_quote_line_record.product_type_name, 'Unknown');
            RAISE NOTICE '    Template: %', COALESCE(v_quote_line_record.template_name, 'Unknown');
            RAISE NOTICE '    Config: drive_type=%, bottom_rail_type=%, side_channel=%, hardware_color=%', 
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.hardware_color;
            
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
                RAISE WARNING '    ❌ Exception: %', SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ Regeneration completed!';
    RAISE NOTICE '   ✅ Successfully regenerated: % QuoteLine(s)', v_updated_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '   ❌ Errors: % QuoteLine(s)', v_error_count;
    END IF;
END $$;

-- Step 3: Verify generated components
SELECT 
    'Step 3: Generated QuoteLineComponents' as check_type,
    ql.id as quote_line_id,
    qlc.component_role,
    qlc.source,
    qlc.uom,
    qlc.qty,
    ci.sku,
    ci.item_name,
    public.derive_category_code_from_role(qlc.component_role) as category_code
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

-- Step 4: Summary by component role
SELECT 
    'Step 4: Summary by Component Role' as check_type,
    qlc.component_role,
    public.derive_category_code_from_role(qlc.component_role) as category_code,
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
ORDER BY category_code, qlc.component_role;








