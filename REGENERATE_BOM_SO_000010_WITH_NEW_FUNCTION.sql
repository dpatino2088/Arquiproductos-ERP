-- ====================================================
-- Script: Regenerate BOM for SO-000010 with New Function
-- ====================================================
-- This script regenerates the BOM using the new clean function
-- ====================================================

-- Step 1: Delete existing configured components (except fabric)
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

-- Step 2: Regenerate BOM using new function
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
        -- Call the new BOM generation function
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
        
        RAISE NOTICE '✅ Regenerated BOM for QuoteLine %: % components', 
            v_quote_line_record.quote_line_id,
            v_result->>'components_count';
    END LOOP;
END $$;

-- Step 3: Verify generated components
SELECT 
    'Step 3: Generated Components' as check_type,
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

-- Step 4: Copy to BomInstanceLines
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
            ql.organization_id,
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
            VALUES (
                v_quote_line_record.organization_id,
                v_quote_line_record.sale_order_line_id,
                v_quote_line_record.quote_line_id,
                'locked',
                NOW(),
                NOW()
            )
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

-- Step 5: Final verification - Check SaleOrderMaterialList
SELECT 
    'Step 5: Final Verification - SaleOrderMaterialList' as check_type,
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








