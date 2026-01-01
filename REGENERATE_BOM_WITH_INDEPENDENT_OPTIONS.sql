-- ====================================================
-- Script: Regenerate BOM with Independent Side Channel and Bottom Rail
-- ====================================================
-- After fixing block_condition to make Side Channel and Bottom Rail independent,
-- we need to regenerate the BOM for SO-000008
-- ====================================================

DO $$
DECLARE
    v_quote_line_id uuid;
    v_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    v_drive_type text;
    v_bottom_rail_type text;
    v_cassette boolean;
    v_cassette_type text;
    v_side_channel boolean;
    v_side_channel_type text;
    v_hardware_color text;
    v_width_m numeric;
    v_height_m numeric;
    v_qty numeric;
    v_result jsonb;
    v_updated_count integer;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REGENERATING BOM WITH INDEPENDENT OPTIONS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Step 1: Get QuoteLine configuration for SO-000008
    RAISE NOTICE 'Step 1: Loading QuoteLine configuration...';
    
    SELECT 
        ql.id,
        ql.product_type_id,
        ql.drive_type,
        ql.bottom_rail_type,
        ql.cassette,
        ql.cassette_type,
        ql.side_channel,
        ql.side_channel_type,
        ql.hardware_color,
        ql.width_m,
        ql.height_m,
        ql.qty
    INTO 
        v_quote_line_id,
        v_product_type_id,
        v_drive_type,
        v_bottom_rail_type,
        v_cassette,
        v_cassette_type,
        v_side_channel,
        v_side_channel_type,
        v_hardware_color,
        v_width_m,
        v_height_m,
        v_qty
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    INNER JOIN "SaleOrders" so ON so.quote_id = q.id
    WHERE so.sale_order_no = 'SO-000008'
    AND ql.deleted = false
    AND q.deleted = false
    AND so.deleted = false
    LIMIT 1;
    
    IF v_quote_line_id IS NULL THEN
        RAISE EXCEPTION 'QuoteLine not found for SO-000008';
    END IF;
    
    RAISE NOTICE '  ✅ QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '  ✅ Product Type ID: %', v_product_type_id;
    RAISE NOTICE '  ✅ Configuration:';
    RAISE NOTICE '     - drive_type: %', v_drive_type;
    RAISE NOTICE '     - bottom_rail_type: %', v_bottom_rail_type;
    RAISE NOTICE '     - cassette: %', v_cassette;
    RAISE NOTICE '     - cassette_type: %', v_cassette_type;
    RAISE NOTICE '     - side_channel: %', v_side_channel;
    RAISE NOTICE '     - side_channel_type: %', v_side_channel_type;
    RAISE NOTICE '     - hardware_color: %', v_hardware_color;
    RAISE NOTICE '     - width_m: %', v_width_m;
    RAISE NOTICE '     - height_m: %', v_height_m;
    RAISE NOTICE '     - qty: %', v_qty;
    RAISE NOTICE '';
    
    -- Step 2: Delete existing configured components
    RAISE NOTICE 'Step 2: Deleting existing configured components...';
    
    DELETE FROM "QuoteLineComponents"
    WHERE quote_line_id = v_quote_line_id
    AND source = 'configured_component'
    AND organization_id = v_organization_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Deleted % existing configured components', v_updated_count;
    RAISE NOTICE '';
    
    -- Step 3: Regenerate BOM using generate_configured_bom_for_quote_line
    RAISE NOTICE 'Step 3: Regenerating BOM with independent block_conditions...';
    
    SELECT public.generate_configured_bom_for_quote_line(
        v_quote_line_id,
        v_product_type_id,
        v_organization_id,
        v_drive_type,
        COALESCE(v_bottom_rail_type, 'standard'), -- Default to 'standard' if NULL
        COALESCE(v_cassette, false),
        v_cassette_type,
        COALESCE(v_side_channel, false),
        v_side_channel_type,
        v_hardware_color,
        v_width_m,
        v_height_m,
        v_qty
    ) INTO v_result;
    
    RAISE NOTICE '  ✅ BOM Generation Result:';
    RAISE NOTICE '     - success: %', v_result->>'success';
    RAISE NOTICE '     - count: %', v_result->>'count';
    
    IF v_result->>'success' = 'true' THEN
        RAISE NOTICE '     - Components generated: %', jsonb_array_length(v_result->'inserted_components');
    ELSE
        RAISE WARNING '     - Error: %', v_result->>'error';
        RAISE WARNING '     - Message: %', v_result->>'message';
    END IF;
    RAISE NOTICE '';
    
    -- Step 4: Verify generated components
    RAISE NOTICE 'Step 4: Verifying generated components...';
    
    -- Count components by category
    SELECT COUNT(*) INTO v_updated_count
    FROM "QuoteLineComponents"
    WHERE quote_line_id = v_quote_line_id
    AND source = 'configured_component'
    AND deleted = false;
    
    RAISE NOTICE '  ✅ Total components generated: %', v_updated_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REGENERATION COMPLETE';
    RAISE NOTICE '========================================';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error regenerating BOM: %', SQLERRM;
        RAISE WARNING 'SQLSTATE: %', SQLSTATE;
END $$;

-- Step 5: Display final summary
SELECT 
    'Final Summary: Generated Components' as check_type,
    qlc.component_role,
    public.derive_category_code_from_role(qlc.component_role) as category_code,
    COUNT(*) as count,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) as sample_skus
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.source = 'configured_component'
AND qlc.deleted = false
GROUP BY qlc.component_role
ORDER BY category_code, qlc.component_role;

