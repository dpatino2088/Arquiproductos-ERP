-- ====================================================
-- Migration 296: Fix SalesOrderLines for SO-090154
-- ====================================================
-- Ensures SalesOrderLines exist and have correct organization_id
-- ====================================================

DO $$
DECLARE
    v_sale_order_no text := 'SO-090154';
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_quote_id uuid;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
    v_created_count integer := 0;
    v_existing_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Fixing SalesOrderLines for %...', v_sale_order_no;
    RAISE NOTICE '';
    
    -- Get SalesOrder details
    SELECT so.id, so.organization_id, so.quote_id
    INTO v_sale_order_id, v_organization_id, v_quote_id
    FROM "SalesOrders" so
    WHERE so.sale_order_no = v_sale_order_no
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder % not found', v_sale_order_no;
    END IF;
    
    RAISE NOTICE '✅ SalesOrder: %', v_sale_order_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '   Quote ID: %', v_quote_id;
    RAISE NOTICE '';
    
    -- Check existing SalesOrderLines
    SELECT COUNT(*) INTO v_existing_count
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_sale_order_id
    AND deleted = false;
    
    RAISE NOTICE 'Existing SalesOrderLines: %', v_existing_count;
    
    IF v_existing_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Checking organization_id match:';
        FOR v_quote_line_record IN
            SELECT sol.id, sol.organization_id, sol.line_number
            FROM "SalesOrderLines" sol
            WHERE sol.sale_order_id = v_sale_order_id
            AND sol.deleted = false
        LOOP
            IF v_quote_line_record.organization_id != v_organization_id THEN
                RAISE NOTICE '  ⚠️  SOL % has wrong org_id: % (expected: %)', 
                    v_quote_line_record.id, 
                    v_quote_line_record.organization_id, 
                    v_organization_id;
                -- Fix it
                UPDATE "SalesOrderLines"
                SET organization_id = v_organization_id,
                    updated_at = now()
                WHERE id = v_quote_line_record.id;
                RAISE NOTICE '     ✅ Fixed organization_id';
            ELSE
                RAISE NOTICE '  ✅ SOL % has correct org_id', v_quote_line_record.id;
            END IF;
        END LOOP;
    END IF;
    
    -- Create SalesOrderLines if they don't exist
    IF v_existing_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Creating SalesOrderLines from QuoteLines...';
        
        FOR v_quote_line_record IN
            SELECT ql.*
            FROM "QuoteLines" ql
            WHERE ql.quote_id = v_quote_id
            AND ql.deleted = false
            ORDER BY ql.created_at ASC
        LOOP
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SaleOrderLine
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sale_order_id,
                    quote_line_id,
                    line_number,
                    catalog_item_id,
                    qty,
                    width_m,
                    height_m,
                    area,
                    position,
                    collection_name,
                    variant_name,
                    product_type,
                    product_type_id,
                    drive_type,
                    bottom_rail_type,
                    cassette,
                    cassette_type,
                    side_channel,
                    side_channel_type,
                    hardware_color,
                    tube_type,
                    operating_system_variant,
                    top_rail_type,
                    unit_price_snapshot,
                    unit_cost_snapshot,
                    line_total,
                    measure_basis_snapshot,
                    margin_percentage,
                    organization_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_sale_order_id,
                    v_quote_line_record.id,
                    v_line_number,
                    v_quote_line_record.catalog_item_id,
                    v_quote_line_record.qty,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.area,
                    v_quote_line_record.position,
                    v_quote_line_record.collection_name,
                    v_quote_line_record.variant_name,
                    v_quote_line_record.product_type,
                    v_quote_line_record.product_type_id,
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_validated_side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant,
                    v_quote_line_record.top_rail_type,
                    v_quote_line_record.unit_price_snapshot,
                    v_quote_line_record.unit_cost_snapshot,
                    v_quote_line_record.line_total,
                    v_quote_line_record.measure_basis_snapshot,
                    v_quote_line_record.margin_percentage,
                    v_organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                RAISE NOTICE '  ✅ Created SalesOrderLine % (line_number: %)', 
                    v_sale_order_line_id, v_line_number;
                v_created_count := v_created_count + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error creating SalesOrderLine: %', SQLERRM;
            END;
        END LOOP;
        
        RAISE NOTICE '';
        RAISE NOTICE '✅ Created % SalesOrderLine(s)', v_created_count;
    END IF;
    
END $$;

-- Verify final state
SELECT 
    'FINAL VERIFICATION' as step,
    so.sale_order_no,
    so.organization_id as so_org_id,
    COUNT(DISTINCT sol.id) as sol_count,
    COUNT(DISTINCT sol.id) FILTER (WHERE sol.organization_id = so.organization_id) as sol_with_matching_org,
    COUNT(DISTINCT bi.id) as bom_count
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false
GROUP BY so.sale_order_no, so.organization_id;


