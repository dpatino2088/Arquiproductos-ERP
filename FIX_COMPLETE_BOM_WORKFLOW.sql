-- ====================================================
-- Script: Fix Complete BOM Workflow for SO-000008
-- ====================================================
-- This script:
-- 1. Verifies QuoteLineComponents are generated
-- 2. Regenerates BOM if needed
-- 3. Verifies BomInstanceLines are created
-- 4. Fixes any missing data
-- ====================================================

-- Step 1: Check QuoteLineComponents for SO-000008
SELECT 
    'Step 1: QuoteLineComponents' as check_type,
    ql.id as quote_line_id,
    qlc.component_role,
    qlc.source,
    qlc.uom,
    qlc.qty,
    ci.sku,
    ci.item_name,
    public.derive_category_code_from_role(qlc.component_role) as expected_category_code
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, qlc.component_role;

-- Step 2: Check BomInstanceLines for SO-000008
SELECT 
    'Step 2: BomInstanceLines' as check_type,
    bi.id as bom_instance_id,
    bi.sale_order_line_id,
    bil.part_role,
    bil.category_code,
    bil.uom,
    bil.qty,
    ci.sku,
    ci.item_name
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false
ORDER BY bil.category_code, bil.part_role;

-- Step 3: REGENERATE BOM if QuoteLineComponents are missing
DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_result jsonb;
    v_component_count integer;
BEGIN
    RAISE NOTICE '🔄 Step 3: Regenerating BOM for SO-000008...';
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
        WHERE so.sale_order_no = 'SO-000008'
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        -- Count existing components
        SELECT COUNT(*) INTO v_component_count
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        BEGIN
            RAISE NOTICE '  Processing QuoteLine % (existing components: %)', 
                v_quote_line_record.quote_line_id, 
                v_component_count;
            
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

-- Step 4: Manually copy QuoteLineComponents to BomInstanceLines for SO-000008
DO $$
DECLARE
    v_quote_line_record record;
    v_sale_order_line_record record;
    v_bom_instance_id uuid;
    v_component_record record;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer := 0;
BEGIN
    RAISE NOTICE '🔄 Step 4: Copying QuoteLineComponents to BomInstanceLines...';
    RAISE NOTICE '';
    
    -- Process each QuoteLine
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.organization_id,
            sol.id as sale_order_line_id
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
        WHERE so.sale_order_no = 'SO-000008'
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND sol.deleted = false
    LOOP
        -- Find or create BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NULL THEN
            -- Create BomInstance
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_quote_line_record.organization_id,
                v_quote_line_record.sale_order_line_id,
                v_quote_line_record.quote_line_id,
                'locked',
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  Created BomInstance % for QuoteLine %', 
                v_bom_instance_id, 
                v_quote_line_record.quote_line_id;
        END IF;
        
        -- Copy QuoteLineComponents to BomInstanceLines
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.item_name,
                ci.sku
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_component_record.catalog_item_id,
                v_canonical_uom,
                v_quote_line_record.organization_id
            );
            
            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
            END IF;
            
            -- Calculate total_cost_exw
            v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
            
            -- Derive category_code
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Insert BomInstanceLine (ON CONFLICT DO NOTHING to avoid duplicates)
            INSERT INTO "BomInstanceLines" (
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                description,
                unit_cost_exw,
                total_cost_exw,
                category_code,
                created_at,
                updated_at,
                deleted
            ) VALUES (
                v_bom_instance_id,
                v_component_record.catalog_item_id,
                v_component_record.sku,
                v_component_record.component_role,
                v_component_record.qty,
                v_canonical_uom,
                v_component_record.item_name,
                v_unit_cost_exw,
                v_total_cost_exw,
                v_category_code,
                now(),
                now(),
                false
            )
            ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
            WHERE deleted = false
            DO NOTHING;
            
            IF FOUND THEN
                v_copied_count := v_copied_count + 1;
            END IF;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Copied % components to BomInstanceLines', v_copied_count;
END $$;

-- Step 5: Final verification - Summary by category
SELECT 
    'Step 5: Final Summary by Category' as check_type,
    bil.category_code,
    COUNT(*) as line_count,
    COUNT(DISTINCT bil.resolved_part_id) as unique_parts,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
AND bi.deleted = false
AND sol.deleted = false
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY bil.category_code;

