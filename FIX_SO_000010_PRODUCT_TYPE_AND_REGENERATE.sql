-- ====================================================
-- Script: Fix SO-000010 ProductType and Regenerate BOM
-- ====================================================
-- This script fixes the missing product_type_id for SO-000010
-- and regenerates the complete BOM
-- ====================================================

-- Step 1: Check current state
SELECT 
    'Step 1: Current State' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.catalog_item_id,
    ci.item_name as catalog_item_name,
    ci.sku
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;

-- Step 2: Find ProductType from CatalogItem
SELECT 
    'Step 2: Find ProductType from CatalogItem' as check_type,
    ql.id as quote_line_id,
    ql.catalog_item_id,
    ci.item_name,
    cipt.product_type_id,
    pt.name as product_type_name
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
LEFT JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
AND ql.product_type_id IS NULL;

-- Step 3: Update QuoteLines with product_type_id
DO $$
DECLARE
    v_updated_count integer := 0;
    v_quote_line_record RECORD;
BEGIN
    -- Update each QuoteLine that has NULL product_type_id
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.catalog_item_id,
            cipt.product_type_id
        FROM "QuoteLines" ql
        INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
        INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
        INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
        INNER JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE so.sale_order_no = 'SO-000010'
        AND ql.deleted = false
        AND ql.product_type_id IS NULL
        LIMIT 1  -- Only update first match per QuoteLine
    LOOP
        UPDATE "QuoteLines"
        SET 
            product_type_id = v_quote_line_record.product_type_id,
            updated_at = NOW()
        WHERE id = v_quote_line_record.quote_line_id;
        
        v_updated_count := v_updated_count + 1;
        
        RAISE NOTICE '✅ Updated QuoteLine % with product_type_id %', 
            v_quote_line_record.quote_line_id, 
            v_quote_line_record.product_type_id;
    END LOOP;
    
    IF v_updated_count = 0 THEN
        RAISE NOTICE '⚠️  No QuoteLines found to update for SO-000010';
    ELSE
        RAISE NOTICE '✅ Updated % QuoteLine(s) with product_type_id', v_updated_count;
    END IF;
END $$;

-- Step 4: Verify product_type_id was updated
SELECT 
    'Step 4: Verify Update' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.catalog_item_id,
    ci.item_name as catalog_item_name
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;

-- Step 5: Check active BOMTemplate for the ProductType
SELECT 
    'Step 5: Active BOMTemplate' as check_type,
    ql.product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    bt.active,
    COUNT(bc.id) as component_count
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
GROUP BY ql.product_type_id, pt.name, bt.id, bt.name, bt.active;

-- Step 6: Delete existing QuoteLineComponents (except fabric)
DO $$
DECLARE
    v_deleted_count integer;
BEGIN
    DELETE FROM "QuoteLineComponents"
    WHERE quote_line_id IN (
        SELECT ql.id
        FROM "QuoteLines" ql
        INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
        INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
        WHERE so.sale_order_no = 'SO-000010'
        AND ql.deleted = false
    )
    AND source = 'configured_component'
    AND component_role NOT LIKE '%fabric%';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Deleted % existing non-fabric components', v_deleted_count;
END $$;

-- Step 7: Regenerate BOM using generate_configured_bom_for_quote_line
DO $$
DECLARE
    v_quote_line_record RECORD;
    v_result jsonb;
BEGIN
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
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
        FROM "QuoteLines" ql
        INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
        INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
        WHERE so.sale_order_no = 'SO-000010'
        AND ql.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        -- Call the BOM generation function
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
        
        RAISE NOTICE '✅ Regenerated BOM for QuoteLine %: %', 
            v_quote_line_record.quote_line_id,
            v_result->>'message';
    END LOOP;
END $$;

-- Step 8: Verify generated components
SELECT 
    'Step 8: Generated Components' as check_type,
    COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom,
    qlc.component_role
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY category_code, ci.sku;

-- Step 9: Copy to BomInstanceLines (if needed)
DO $$
DECLARE
    v_sale_order_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_record RECORD;
    v_copied_count integer := 0;
BEGIN
    -- Get sale_order_id
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE sale_order_no = 'SO-000010'
    AND deleted = false
    LIMIT 1;
    
    IF v_sale_order_id IS NULL THEN
        RAISE NOTICE '⚠️  Sale Order SO-000010 not found';
        RETURN;
    END IF;
    
    -- For each QuoteLine, find or create BomInstance
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            sol.id as sale_order_line_id
        FROM "QuoteLines" ql
        INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
        WHERE sol.sale_order_id = v_sale_order_id
        AND ql.deleted = false
    LOOP
        -- Find or create BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NULL THEN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                status,
                created_at,
                updated_at
            )
            SELECT 
                ql.organization_id,
                v_quote_line_record.sale_order_line_id,
                v_quote_line_record.quote_line_id,
                'locked',
                NOW(),
                NOW()
            FROM "QuoteLines" ql
            WHERE ql.id = v_quote_line_record.quote_line_id
            RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '✅ Created BomInstance % for QuoteLine %', 
                v_bom_instance_id, 
                v_quote_line_record.quote_line_id;
        END IF;
        
        -- Delete existing BomInstanceLines
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id;
        
        -- Copy QuoteLineComponents to BomInstanceLines
        INSERT INTO "BomInstanceLines" (
            organization_id,
            bom_instance_id,
            resolved_part_id,
            qty,
            uom,
            unit_cost_exw,
            total_cost_exw,
            category_code,
            description,
            resolved_sku,
            part_role,
            created_at,
            updated_at,
            deleted
        )
        SELECT 
            qlc.organization_id,
            v_bom_instance_id,
            qlc.catalog_item_id,
            qlc.qty,
            qlc.uom,
            qlc.unit_cost_exw,
            COALESCE(qlc.qty, 0) * COALESCE(qlc.unit_cost_exw, 0) as total_cost_exw,
            COALESCE(public.derive_category_code_from_role(qlc.component_role), 'accessory'),
            ci.item_name,
            ci.sku,
            qlc.component_role,
            NOW(),
            NOW(),
            false
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        GET DIAGNOSTICS v_copied_count = ROW_COUNT;
        
        RAISE NOTICE '✅ Copied % components to BomInstanceLines for QuoteLine %', 
            v_copied_count,
            v_quote_line_record.quote_line_id;
    END LOOP;
END $$;

-- Step 10: Final verification - Check SaleOrderMaterialList
SELECT 
    'Step 10: Final Verification - SaleOrderMaterialList' as check_type,
    category_code,
    sku,
    item_name,
    total_qty,
    uom,
    avg_unit_cost_exw,
    total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000010' AND deleted = false)
ORDER BY category_code, sku;

