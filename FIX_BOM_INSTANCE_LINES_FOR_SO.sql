-- ====================================================
-- Script: Fix BomInstanceLines for Specific Sale Order
-- ====================================================
-- This script regenerates BomInstanceLines from QuoteLineComponents
-- for a specific Sale Order (SO-000008) or all Sale Orders
-- ====================================================

DO $$
DECLARE
    v_sale_order_no text := 'SO-000008'; -- Change this or set to NULL for all
    v_quote_record record;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_component_record record;
    v_category_code text;
    v_created_count integer := 0;
    v_updated_count integer := 0;
    v_deleted_count integer := 0;
BEGIN
    RAISE NOTICE '🔄 Regenerating BomInstanceLines from QuoteLineComponents...';
    
    IF v_sale_order_no IS NOT NULL THEN
        RAISE NOTICE '📋 Processing Sale Order: %', v_sale_order_no;
    ELSE
        RAISE NOTICE '📋 Processing ALL approved Sale Orders';
    END IF;
    
    -- Process each approved quote
    FOR v_quote_record IN
        SELECT DISTINCT q.id, q.quote_no, q.organization_id, q.created_at
        FROM "Quotes" q
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND so.deleted = false
        AND (v_sale_order_no IS NULL OR so.sale_order_no = v_sale_order_no)
        ORDER BY q.created_at DESC
    LOOP
        -- Find SaleOrder
        SELECT id INTO v_sale_order_id
        FROM "SaleOrders"
        WHERE quote_id = v_quote_record.id
        AND deleted = false
        AND (v_sale_order_no IS NULL OR sale_order_no = v_sale_order_no)
        LIMIT 1;
        
        IF v_sale_order_id IS NULL THEN
            RAISE NOTICE '   ⚠️  No SaleOrder found for Quote %, skipping', v_quote_record.quote_no;
            CONTINUE;
        END IF;
        
        RAISE NOTICE '   📦 Processing Quote: % (SaleOrder: %)', v_quote_record.quote_no, v_sale_order_id;
        
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
                qlc.source,
                ci.sku,
                ci.item_name
            FROM "QuoteLines" ql
            INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id AND sol.sale_order_id = v_sale_order_id
            INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
            LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE ql.quote_id = v_quote_record.id
            AND ql.deleted = false
            AND sol.deleted = false
            -- Include both configured_component and accessory
            AND (qlc.source = 'configured_component' OR qlc.component_role = 'accessory')
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
                
                RAISE NOTICE '      ✅ Created BomInstance for SaleOrderLine %', v_component_record.sale_order_line_id;
            END IF;
            
            -- Derive category_code
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Delete existing BomInstanceLine for this component (if exists)
            DELETE FROM "BomInstanceLines"
            WHERE bom_instance_id = v_bom_instance_id
            AND resolved_part_id = v_component_record.catalog_item_id
            AND COALESCE(part_role, '') = COALESCE(v_component_record.component_role, '')
            AND deleted = false;
            
            GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
            IF v_deleted_count > 0 THEN
                v_updated_count := v_updated_count + 1;
            END IF;
            
            -- Insert new BomInstanceLine
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
            );
            
            v_created_count := v_created_count + 1;
            
            -- Log each component
            RAISE NOTICE '      ✅ Added: % (% - %)', 
                v_component_record.component_role,
                v_component_record.sku,
                v_category_code;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BomInstanceLines regeneration completed!';
    RAISE NOTICE '   - Created: % new lines', v_created_count;
    RAISE NOTICE '   - Updated: % existing lines', v_updated_count;
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Refresh the Manufacturing Order page';
    RAISE NOTICE '   2. Check the Materials tab - all components should be visible';
    
END $$;

-- Show summary by category for the Sale Order
SELECT 
    'Summary for SO-000008' as check_type,
    bil.category_code,
    bil.part_role,
    COUNT(*) as count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000008'
AND bil.deleted = false
GROUP BY bil.category_code, bil.part_role
ORDER BY bil.category_code, count DESC;

