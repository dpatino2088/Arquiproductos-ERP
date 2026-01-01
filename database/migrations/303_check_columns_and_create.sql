-- ====================================================
-- Migration 303: Check SalesOrderLines columns and create lines
-- ====================================================

-- Step 1: Check what columns exist in SalesOrderLines
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SalesOrderLines'
ORDER BY ordinal_position;

-- Step 2: Verify SalesOrder exists
SELECT 
    'SalesOrder Check' as step,
    so.id as sale_order_id,
    so.sale_order_no,
    so.organization_id,
    so.quote_id
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false;

-- Step 3: Verify QuoteLines exist
SELECT 
    'QuoteLines Check' as step,
    COUNT(*) as quote_lines_count
FROM "QuoteLines" ql
WHERE ql.quote_id = (
    SELECT quote_id FROM "SalesOrders" 
    WHERE sale_order_no = 'SO-090154' 
    AND deleted = false
    LIMIT 1
)
AND ql.deleted = false;

-- Step 4: Create SalesOrderLines (minimal columns to avoid errors)
DO $$
DECLARE
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_quote_id uuid;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
    v_created_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Creating SalesOrderLines for SO-090154...';
    RAISE NOTICE '';
    
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
    
    RAISE NOTICE '✅ SalesOrder ID: %', v_sale_order_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '   Quote ID: %', v_quote_id;
    RAISE NOTICE '';
    
    -- Process each QuoteLine
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
        
        -- Validate side_channel_type
        IF v_quote_line_record.side_channel_type IS NULL THEN
            v_validated_side_channel_type := NULL;
        ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
            v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
        ELSE
            v_validated_side_channel_type := NULL;
        END IF;
        
        -- Create SalesOrderLine with minimal required columns
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
                product_type,
                product_type_id,
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
                v_quote_line_record.product_type,
                v_quote_line_record.product_type_id,
                v_organization_id,
                false,
                now(),
                now()
            ) RETURNING id INTO v_sale_order_line_id;
            
            RAISE NOTICE '  ✅ Created SalesOrderLine % (line_number: %)', v_sale_order_line_id, v_line_number;
            v_created_count := v_created_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creating SalesOrderLine: %', SQLERRM;
                RAISE WARNING '     SQLSTATE: %', SQLSTATE;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Completed: Created % SalesOrderLine(s)', v_created_count;
    
END $$;

-- Step 5: Final verification
SELECT 
    'Final Check' as step,
    COUNT(DISTINCT so.id) as sales_orders,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false;


