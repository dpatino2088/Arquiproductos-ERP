-- ====================================================
-- Script: Complete BOM Fix for SO-000008
-- ====================================================
-- This script:
-- 1. Verifies product_type_id is set
-- 2. Checks if BOMTemplate exists
-- 3. Regenerates BOM components
-- 4. Shows final summary
-- ====================================================

-- Step 1: Verify product_type_id is set
SELECT 
    'Step 1: ProductType Verification' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ MISSING product_type_id'
        WHEN pt.id IS NULL THEN '⚠️ ProductType NOT FOUND'
        ELSE '✅ ProductType OK'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id 
    AND pt.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false;

-- Step 2: Check BOMTemplate existence
SELECT 
    'Step 2: BOMTemplate Check' as check_type,
    ql.id as quote_line_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ QuoteLine has NO product_type_id'
        WHEN bt.id IS NULL THEN '❌ NO BOMTemplate found'
        WHEN bt.active = false THEN '⚠️ BOMTemplate INACTIVE'
        WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate has NO components'
        WHEN COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') = COUNT(bc.id) THEN '⚠️ BOMTemplate ONLY has fabric'
        ELSE '✅ BOMTemplate OK'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id 
    AND pt.deleted = false
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id, pt.name, bt.id, bt.name, bt.active, ql.product_type_id;

-- Step 3: Show BOMComponents in Template (if exists)
SELECT 
    'Step 3: BOMComponents in Template' as check_type,
    bc.component_role,
    bc.block_type,
    bc.block_condition,
    bc.component_item_id,
    bc.auto_select,
    bc.applies_color,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY bc.sequence_order, bc.component_role;

-- Step 4: REGENERATE BOM (Execute this DO block)
DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_result jsonb;
BEGIN
    RAISE NOTICE '🔄 Step 4: Regenerating BOM for SO-000008...';
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
            pt.name as product_type_name
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
        WHERE so.sale_order_no = 'SO-000008'
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        BEGIN
            RAISE NOTICE '  Processing QuoteLine % (ProductType: %)', 
                v_quote_line_record.quote_line_id, 
                COALESCE(v_quote_line_record.product_type_name, 'Unknown');
            
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

-- Step 5: Final Summary - Generated Components
SELECT 
    'Step 5: Final Summary' as check_type,
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








