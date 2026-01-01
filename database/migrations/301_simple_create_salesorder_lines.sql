-- ====================================================
-- Migration 301: Simple create SalesOrderLines for SO-090154
-- ====================================================
-- Step-by-step verification and creation
-- ====================================================

-- Step 1: Verify SalesOrder exists
SELECT 
    'Step 1: SalesOrder' as step,
    so.id as sale_order_id,
    so.sale_order_no,
    so.organization_id,
    so.quote_id
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false;

-- Step 2: Verify QuoteLines exist
SELECT 
    'Step 2: QuoteLines' as step,
    ql.id as quote_line_id,
    ql.catalog_item_id,
    ci.sku,
    ql.qty,
    ql.width_m,
    ql.height_m,
    ql.product_type
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

-- Step 3: Create SalesOrderLines (if QuoteLines exist)
DO $$
DECLARE
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_quote_id uuid;
    v_quote_line_id uuid;
    v_line_number integer := 1;
    v_created_count integer := 0;
BEGIN
    -- Get SalesOrder details
    SELECT so.id, so.organization_id, so.quote_id
    INTO v_sale_order_id, v_organization_id, v_quote_id
    FROM "SalesOrders" so
    WHERE so.sale_order_no = 'SO-090154'
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder SO-090154 not found';
    END IF;
    
    RAISE NOTICE 'SalesOrder ID: %', v_sale_order_id;
    RAISE NOTICE 'Organization ID: %', v_organization_id;
    RAISE NOTICE 'Quote ID: %', v_quote_id;
    RAISE NOTICE '';
    
    -- Create SalesOrderLine for each QuoteLine
    FOR v_quote_line_id IN
        SELECT id
        FROM "QuoteLines"
        WHERE quote_id = v_quote_id
        AND deleted = false
        ORDER BY created_at
    LOOP
        -- Check if already exists
        IF EXISTS (
            SELECT 1 FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND quote_line_id = v_quote_line_id
            AND deleted = false
        ) THEN
            RAISE NOTICE 'SalesOrderLine already exists for QuoteLine %', v_quote_line_id;
            CONTINUE;
        END IF;
        
        -- Insert SalesOrderLine using data from QuoteLine (only columns that exist)
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
            organization_id,
            deleted,
            created_at,
            updated_at
        )
        SELECT 
            v_sale_order_id,
            ql.id,
            v_line_number,
            ql.catalog_item_id,
            ql.qty,
            ql.width_m,
            ql.height_m,
            ql.area,
            ql.position,
            ql.collection_name,
            ql.variant_name,
            ql.product_type,
            ql.product_type_id,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            CASE 
                WHEN ql.side_channel_type IS NULL THEN NULL
                WHEN LOWER(ql.side_channel_type) IN ('side_only', 'side_and_bottom') 
                    THEN LOWER(ql.side_channel_type)
                ELSE NULL
            END,
            ql.hardware_color,
            ql.tube_type,
            ql.operating_system_variant,
            ql.top_rail_type,
            v_organization_id,
            false,
            now(),
            now()
        FROM "QuoteLines" ql
        WHERE ql.id = v_quote_line_id;
        
        RAISE NOTICE 'Created SalesOrderLine for QuoteLine % (line_number: %)', v_quote_line_id, v_line_number;
        v_line_number := v_line_number + 1;
        v_created_count := v_created_count + 1;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Created % SalesOrderLine(s)', v_created_count;
    
END $$;

-- Step 4: Final verification
SELECT 
    'Step 4: Final Check' as step,
    COUNT(DISTINCT so.id) as sales_orders,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false;

