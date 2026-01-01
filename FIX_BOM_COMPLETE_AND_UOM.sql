-- ====================================================
-- Script: Fix BOM Complete + UOM Correction
-- ====================================================
-- This script:
-- 1. Regenerates BOM components for all approved QuoteLines
-- 2. Fixes UOM for fabrics (ea -> m2 or m based on fabric_pricing_mode)
-- 3. Updates category_code in BomInstanceLines
-- ====================================================

-- Step 1: Regenerate QuoteLineComponents for all approved QuoteLines
DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_total_quote_lines integer;
BEGIN
    RAISE NOTICE '🔄 Step 1: Regenerating QuoteLineComponents from QuoteLines...';
    
    -- Count total quote lines to process
    SELECT COUNT(*) INTO v_total_quote_lines
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    WHERE q.status = 'approved'
    AND q.deleted = false
    AND ql.deleted = false
    AND ql.product_type_id IS NOT NULL;
    
    RAISE NOTICE '📊 Found % QuoteLines to process', v_total_quote_lines;
    
    -- Process each quote line
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
            q.quote_no
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND ql.deleted = false
        AND ql.product_type_id IS NOT NULL
        ORDER BY q.created_at DESC, ql.id
    LOOP
        BEGIN
            -- Check required fields
            IF v_quote_line_record.drive_type IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % (Quote: %) has no drive_type, skipping', 
                    v_quote_line_record.quote_line_id, v_quote_line_record.quote_no;
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
            
            -- Regenerate BOM for this quote line
            PERFORM public.generate_configured_bom_for_quote_line(
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
            
            v_updated_count := v_updated_count + 1;
            
            IF v_updated_count % 10 = 0 THEN
                RAISE NOTICE '   ✅ Processed % QuoteLines...', v_updated_count;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ❌ Error regenerating BOM for QuoteLine % (Quote: %): %', 
                    v_quote_line_record.quote_line_id, 
                    v_quote_line_record.quote_no,
                    SQLERRM;
                v_error_count := v_error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Step 1 completed: Processed % QuoteLines (Errors: %)', v_updated_count, v_error_count;
END $$;

-- Step 2: Fix UOM for fabrics in QuoteLineComponents
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Step 2: Fixing UOM for fabrics in QuoteLineComponents...';
    
    -- Update QuoteLineComponents: Set UOM based on fabric_pricing_mode for fabrics
    UPDATE "QuoteLineComponents" qlc
    SET 
        uom = CASE 
                WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
                WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
                ELSE 'm2' -- Default to m2 if pricing mode is also null/unknown
              END,
        updated_at = NOW()
    FROM "CatalogItems" ci
    WHERE 
        qlc.catalog_item_id = ci.id
        AND qlc.component_role = 'fabric'
        AND qlc.deleted = false
        AND ci.is_fabric = true
        AND (qlc.uom IS NULL OR qlc.uom = 'ea' OR qlc.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % QuoteLineComponents with corrected fabric UOM', v_updated_count;
END $$;

-- Step 3: Fix UOM for fabrics in BomInstanceLines
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Step 3: Fixing UOM for fabrics in BomInstanceLines...';
    
    -- Update BomInstanceLines: Set UOM based on fabric_pricing_mode for fabrics
    UPDATE "BomInstanceLines" bil
    SET 
        uom = CASE 
                WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
                WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
                ELSE 'm2' -- Default to m2 if pricing mode is also null/unknown
              END,
        updated_at = NOW()
    FROM "CatalogItems" ci
    WHERE 
        bil.resolved_part_id = ci.id
        AND bil.category_code = 'fabric'
        AND bil.deleted = false
        AND ci.is_fabric = true
        AND (bil.uom IS NULL OR bil.uom = 'ea' OR bil.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % BomInstanceLines with corrected fabric UOM', v_updated_count;
END $$;

-- Step 4: Update category_code in BomInstanceLines
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Step 4: Updating category_code in BomInstanceLines...';
    
    UPDATE "BomInstanceLines" bil
    SET 
        category_code = public.derive_category_code_from_role(bil.part_role),
        updated_at = NOW()
    WHERE 
        bil.deleted = false
        AND bil.category_code IS DISTINCT FROM public.derive_category_code_from_role(bil.part_role);
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % BomInstanceLines with new category_code', v_updated_count;
END $$;

-- Step 5: Regenerate BomInstanceLines from QuoteLineComponents for approved quotes
-- This step manually copies QuoteLineComponents to BomInstanceLines
DO $$
DECLARE
    v_quote_record record;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_component_record record;
    v_category_code text;
    v_created_count integer := 0;
    v_updated_count integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Step 5: Regenerating BomInstanceLines from QuoteLineComponents...';
    
    -- Process each approved quote
    FOR v_quote_record IN
        SELECT id, quote_no, organization_id
        FROM "Quotes"
        WHERE status = 'approved'
        AND deleted = false
        ORDER BY created_at DESC
    LOOP
        -- Find or create SaleOrder
        SELECT id INTO v_sale_order_id
        FROM "SaleOrders"
        WHERE quote_id = v_quote_record.id
        AND deleted = false
        LIMIT 1;
        
        IF v_sale_order_id IS NULL THEN
            RAISE NOTICE '   ⚠️  No SaleOrder found for Quote %, skipping', v_quote_record.quote_no;
            CONTINUE;
        END IF;
        
        -- Process each QuoteLine
        FOR v_component_record IN
            SELECT 
                ql.id as quote_line_id,
                sol.id as sale_order_line_id,
                qlc.catalog_item_id,
                qlc.qty,
                qlc.uom,
                qlc.unit_cost_exw,
                qlc.component_role,
                ci.sku,
                ci.item_name
            FROM "QuoteLines" ql
            INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id AND sol.sale_order_id = v_sale_order_id
            INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
            LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE ql.quote_id = v_quote_record.id
            AND ql.deleted = false
            AND sol.deleted = false
        LOOP
            -- Find or create BomInstance
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_component_record.sale_order_line_id
            AND deleted = false
            LIMIT 1;
            
            IF v_bom_instance_id IS NULL THEN
                -- Create BomInstance
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    created_at,
                    updated_at,
                    deleted
                )
                VALUES (
                    v_quote_record.organization_id,
                    v_component_record.sale_order_line_id,
                    NOW(),
                    NOW(),
                    false
                )
                RETURNING id INTO v_bom_instance_id;
            END IF;
            
            -- Derive category_code
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Insert or update BomInstanceLine
            INSERT INTO "BomInstanceLines" (
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                total_cost_exw,
                description,
                category_code,
                created_at,
                updated_at,
                deleted
            )
            VALUES (
                v_bom_instance_id,
                v_component_record.catalog_item_id,
                v_component_record.sku,
                v_component_record.component_role,
                v_component_record.qty,
                v_component_record.uom,
                v_component_record.unit_cost_exw,
                COALESCE(v_component_record.qty, 0) * COALESCE(v_component_record.unit_cost_exw, 0),
                v_component_record.item_name,
                v_category_code,
                NOW(),
                NOW(),
                false
            )
            ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
            WHERE deleted = false
            DO UPDATE SET
                qty = EXCLUDED.qty,
                uom = EXCLUDED.uom,
                unit_cost_exw = EXCLUDED.unit_cost_exw,
                total_cost_exw = EXCLUDED.total_cost_exw,
                category_code = EXCLUDED.category_code,
                updated_at = NOW();
            
            v_created_count := v_created_count + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Step 5 completed: Created/Updated % BomInstanceLines', v_created_count;
END $$;

-- Step 6: Final summary
DO $$
DECLARE
    rec record;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📊 Final Summary by Category:';
    
    FOR rec IN
        SELECT 
            category_code,
            COUNT(*) as count
        FROM "BomInstanceLines"
        WHERE deleted = false
        GROUP BY category_code
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   - %: % lines', rec.category_code, rec.count;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ BOM regeneration and UOM fix completed!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Refresh the Manufacturing Order page in the application';
    RAISE NOTICE '   2. Check the Materials tab - you should see all components';
    RAISE NOTICE '   3. Verify that fabrics have correct UOM (m2 or m, not ea)';
END $$;








