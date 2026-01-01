-- ====================================================
-- Migration 297: Verify QuoteLines and create SalesOrderLines
-- ====================================================
-- Checks if QuoteLines exist and creates SalesOrderLines
-- ====================================================

-- First, verify the SalesOrder exists
SELECT 
    'SalesOrder Check' as step,
    so.id as sale_order_id,
    so.sale_order_no,
    so.organization_id,
    so.quote_id,
    so.status,
    so.deleted
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-090154'  -- Note: SO not S0
AND so.deleted = false;

-- Check QuoteLines for the Quote
SELECT 
    'QuoteLines Check' as step,
    q.id as quote_id,
    q.quote_no,
    COUNT(ql.id) as quote_lines_count
FROM "Quotes" q
LEFT JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
WHERE q.id = (
    SELECT quote_id FROM "SalesOrders" 
    WHERE sale_order_no = 'SO-090154' 
    AND deleted = false
    LIMIT 1
)
AND q.deleted = false
GROUP BY q.id, q.quote_no;

-- Show QuoteLines details
SELECT 
    'QuoteLines Details' as step,
    ql.id as quote_line_id,
    ql.catalog_item_id,
    ci.sku,
    ql.qty,
    ql.width_m,
    ql.height_m,
    ql.product_type,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant
FROM "QuoteLines" ql
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE ql.quote_id = (
    SELECT quote_id FROM "SalesOrders" 
    WHERE sale_order_no = 'SO-090154' 
    AND deleted = false
    LIMIT 1
)
AND ql.deleted = false
ORDER BY ql.created_at;

-- Now create SalesOrderLines
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
BEGIN
    RAISE NOTICE '🔧 Creating SalesOrderLines for %...', v_sale_order_no;
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
    
    -- Check if QuoteLines exist
    IF NOT EXISTS (
        SELECT 1 FROM "QuoteLines"
        WHERE quote_id = v_quote_id
        AND deleted = false
    ) THEN
        RAISE EXCEPTION 'No QuoteLines found for Quote %', v_quote_id;
    END IF;
    
    -- Create SalesOrderLines for each QuoteLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = v_quote_id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Check if SalesOrderLine already exists
        IF EXISTS (
            SELECT 1 FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND quote_line_id = v_quote_line_record.id
            AND deleted = false
        ) THEN
            RAISE NOTICE '  ⏭️  SalesOrderLine already exists for QuoteLine %', v_quote_line_record.id;
            CONTINUE;
        END IF;
        
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
            
            RAISE NOTICE '  ✅ Created SalesOrderLine % (line_number: %) for QuoteLine %', 
                v_sale_order_line_id, v_line_number, v_quote_line_record.id;
            v_created_count := v_created_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creating SalesOrderLine for QuoteLine %: %', 
                    v_quote_line_record.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Completed: Created % SalesOrderLine(s)', v_created_count;
    
END $$;

-- Final verification
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

