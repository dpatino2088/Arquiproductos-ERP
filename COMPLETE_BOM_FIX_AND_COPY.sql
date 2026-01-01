-- ====================================================
-- Script: Complete BOM Fix and Copy
-- ====================================================
-- This script:
-- 1. Regenerates BOM from QuoteLineComponents (with corrected block_conditions)
-- 2. Copies all components to BomInstanceLines
-- 3. Verifies the results
-- ====================================================

-- Step 1: Check current QuoteLineComponents
SELECT 
    'Step 1: Current QuoteLineComponents' as check_type,
    public.derive_category_code_from_role(qlc.component_role) as category_code,
    qlc.component_role,
    COUNT(*) as count,
    SUM(qlc.qty) as total_qty
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY public.derive_category_code_from_role(qlc.component_role), qlc.component_role
ORDER BY category_code, qlc.component_role;

-- Step 2: Regenerate BOM for SO-000008
DO $$
DECLARE
    v_quote_line_record record;
    v_result jsonb;
    v_success_count integer := 0;
    v_error_count integer := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REGENERATING BOM FOR SO-000008';
    RAISE NOTICE '========================================';
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
            ql.qty
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE so.sale_order_no IN ('SO-000008', '50-000008')
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        BEGIN
            RAISE NOTICE 'Processing QuoteLine: %', v_quote_line_record.quote_line_id;
            RAISE NOTICE '  Config: drive_type=%, bottom_rail_type=%, side_channel=%, hardware_color=%', 
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.hardware_color;
            
            -- Delete existing configured components
            DELETE FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line_record.quote_line_id
            AND source = 'configured_component'
            AND organization_id = v_quote_line_record.organization_id;
            
            -- Regenerate BOM
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
                v_success_count := v_success_count + 1;
                RAISE NOTICE '  ✅ Generated % components', v_result->>'count';
            ELSE
                v_error_count := v_error_count + 1;
                RAISE WARNING '  ❌ Error: %', COALESCE(v_result->>'error', v_result->>'message', 'Unknown error');
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING '  ❌ Exception: %', SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ Regeneration completed!';
    RAISE NOTICE '   ✅ Successfully regenerated: % QuoteLine(s)', v_success_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '   ❌ Errors: % QuoteLine(s)', v_error_count;
    END IF;
END $$;

-- Step 3: Verify regenerated QuoteLineComponents
SELECT 
    'Step 3: Regenerated QuoteLineComponents' as check_type,
    public.derive_category_code_from_role(qlc.component_role) as category_code,
    qlc.component_role,
    COUNT(*) as count,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY public.derive_category_code_from_role(qlc.component_role), qlc.component_role
ORDER BY category_code, qlc.component_role;

-- Step 4: Add organization_id column to BomInstanceLines if needed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'organization_id'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN organization_id uuid;
        
        RAISE NOTICE '✅ Added organization_id column to BomInstanceLines';
        
        -- Update existing rows
        UPDATE "BomInstanceLines" bil
        SET organization_id = bi.organization_id
        FROM "BomInstances" bi
        WHERE bil.bom_instance_id = bi.id
        AND bil.organization_id IS NULL;
        
        RAISE NOTICE '✅ Updated existing BomInstanceLines with organization_id';
    END IF;
END $$;

-- Step 5: Copy QuoteLineComponents to BomInstanceLines
DO $$
DECLARE
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_component_count integer := 0;
    v_updated_count integer;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'COPYING QUOTELINECOMPONENTS TO BOMINSTANCELINES';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Get Sale Order ID
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE sale_order_no IN ('SO-000008', '50-000008')
    AND deleted = false
    LIMIT 1;
    
    IF v_sale_order_id IS NULL THEN
        RAISE EXCEPTION 'Sale Order SO-000008 or 50-000008 not found';
    END IF;
    
    RAISE NOTICE '✅ Found Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '';
    
    -- Process each SaleOrderLine
    FOR v_sale_order_line_id, v_quote_line_id, v_bom_instance_id IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            bi.id as bom_instance_id
        FROM "SaleOrderLines" sol
        INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
        LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
        WHERE sol.sale_order_id = v_sale_order_id
        AND sol.deleted = false
    LOOP
        RAISE NOTICE 'Processing SaleOrderLine: %', v_sale_order_line_id;
        
        -- Create BomInstance if it doesn't exist
        IF v_bom_instance_id IS NULL THEN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                created_at,
                updated_at,
                deleted
            )
            SELECT 
                ql.organization_id,
                v_sale_order_line_id,
                v_quote_line_id,
                NOW(),
                NOW(),
                false
            FROM "QuoteLines" ql
            WHERE ql.id = v_quote_line_id
            RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  ✅ Created BomInstance: %', v_bom_instance_id;
        END IF;
        
        -- Delete existing BomInstanceLines
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        RAISE NOTICE '  ✅ Deleted % existing BomInstanceLines', v_updated_count;
        
        -- Copy QuoteLineComponents to BomInstanceLines
        INSERT INTO "BomInstanceLines" (
            organization_id,
            bom_instance_id,
            resolved_part_id,
            resolved_sku,
            part_role,
            qty,
            uom,
            unit_cost_exw,
            total_cost_exw,
            category_code,
            description,
            created_at,
            updated_at,
            deleted
        )
        SELECT 
            qlc.organization_id,
            v_bom_instance_id,
            qlc.catalog_item_id,
            ci.sku as resolved_sku,
            qlc.component_role as part_role,
            qlc.qty,
            qlc.uom,
            qlc.unit_cost_exw,
            qlc.qty * COALESCE(qlc.unit_cost_exw, 0) as total_cost_exw,
            public.derive_category_code_from_role(qlc.component_role) as category_code,
            ci.item_name as description,
            NOW(),
            NOW(),
            false
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        GET DIAGNOSTICS v_component_count = ROW_COUNT;
        RAISE NOTICE '  ✅ Copied % components to BomInstanceLines', v_component_count;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'COPY COMPLETED';
    RAISE NOTICE '========================================';
END $$;

-- Step 6: Final verification
SELECT 
    'Step 6: Final Verification - BomInstanceLines' as check_type,
    bil.category_code,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY bil.category_code;

-- Step 7: Check SaleOrderMaterialList view
SELECT 
    'Step 7: SaleOrderMaterialList View' as check_type,
    category_code,
    COUNT(*) as count,
    SUM(total_qty) as total_qty,
    STRING_AGG(DISTINCT sku, ', ' ORDER BY sku) FILTER (WHERE sku IS NOT NULL) as sample_skus
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no IN ('SO-000008', '50-000008') AND deleted = false LIMIT 1)
GROUP BY category_code
ORDER BY category_code;








