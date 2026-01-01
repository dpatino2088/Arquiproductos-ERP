-- ====================================================
-- Migration 289: Diagnose and Fix SalesOrderLines for SO-090154
-- ====================================================
-- Checks if SalesOrderLines exist and creates them if missing
-- ====================================================

-- First, diagnose the situation
SELECT 
    'DIAGNOSIS' as step,
    q.quote_no,
    q.id as quote_id,
    so.sale_order_no,
    so.id as sale_order_id,
    so.status,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as quote_lines_count,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as sales_order_lines_count
FROM "Quotes" q
JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND q.deleted = false;

-- Now create SalesOrderLines if they don't exist
DO $$
DECLARE
    v_sale_order_no text := 'SO-090154';
    v_sale_order_id uuid;
    v_quote_id uuid;
    v_organization_id uuid;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
    v_created_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Creating SalesOrderLines for %...', v_sale_order_no;
    RAISE NOTICE '';
    
    -- Get SalesOrder, Quote IDs, and Organization ID
    SELECT so.id, so.quote_id, so.organization_id 
    INTO v_sale_order_id, v_quote_id, v_organization_id
    FROM "SalesOrders" so
    WHERE so.sale_order_no = v_sale_order_no
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder % not found', v_sale_order_no;
    END IF;
    
    RAISE NOTICE '✅ Found SalesOrder: % (Quote: %, Org: %)', v_sale_order_id, v_quote_id, v_organization_id;
    
    -- Check if SalesOrderLines already exist
    IF EXISTS (
        SELECT 1 FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND deleted = false
    ) THEN
        RAISE NOTICE '⚠️  SalesOrderLines already exist. Skipping creation.';
        RETURN;
    END IF;
    
    -- Create SalesOrderLines for each QuoteLine
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

-- Verify results
SELECT 
    'VERIFICATION' as step,
    q.quote_no,
    so.sale_order_no,
    so.status,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as sales_order_lines_count,
    (SELECT COUNT(*) FROM "BomInstances" bi 
     WHERE bi.sale_order_line_id IN (
         SELECT id FROM "SalesOrderLines" 
         WHERE sale_order_id = so.id AND deleted = false
     ) AND bi.deleted = false) as bom_count
FROM "Quotes" q
JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND q.deleted = false;

