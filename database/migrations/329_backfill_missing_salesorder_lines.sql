-- ====================================================
-- Migration 329: Backfill Missing SalesOrderLines
-- ====================================================
-- Creates SalesOrderLines for SalesOrders that are missing them
-- ====================================================

DO $$
DECLARE
    v_so RECORD;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
    v_count integer := 0;
    v_so_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Backfilling missing SalesOrderLines...';
    
    FOR v_so IN
        SELECT 
            so.id, 
            so.quote_id, 
            so.organization_id,
            so.sale_order_no
        FROM "SalesOrders" so
        WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1
            FROM "SalesOrderLines" sol
            WHERE sol.sale_order_id = so.id
            AND sol.deleted = false
        )
        ORDER BY so.created_at
    LOOP
        v_so_count := v_so_count + 1;
        RAISE NOTICE '  Processing SalesOrder % (%) for Quote %', v_so.sale_order_no, v_so.id, v_so.quote_id;
        
        FOR v_quote_line_record IN
            SELECT ql.*
            FROM "QuoteLines" ql
            WHERE ql.quote_id = v_so.quote_id
            AND ql.deleted = false
            ORDER BY ql.created_at ASC
        LOOP
            -- Check if SalesOrderLine already exists (double-check)
            SELECT id INTO v_sale_order_line_id
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND quote_line_id = v_quote_line_record.id
            AND deleted = false
            LIMIT 1;
            
            IF NOT FOUND THEN
                -- Get next line number
                SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
                FROM "SalesOrderLines"
                WHERE sale_order_id = v_so.id
                AND deleted = false;
                
                -- Validate and normalize side_channel_type
                IF v_quote_line_record.side_channel_type IS NULL THEN
                    v_validated_side_channel_type := NULL;
                ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                    v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
                ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                      LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                    v_validated_side_channel_type := 'side_only';
                ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                      LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' THEN
                    v_validated_side_channel_type := 'side_and_bottom';
                ELSE
                    v_validated_side_channel_type := NULL;
                END IF;
                
                -- Create SalesOrderLine
                BEGIN
                    INSERT INTO "SalesOrderLines" (
                        sale_order_id,
                        quote_line_id,
                        line_number,
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
                    ) VALUES (
                        v_so.id,
                        v_quote_line_record.id,
                        v_line_number,
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
                        v_so.organization_id,
                        false,
                        now(),
                        now()
                    ) RETURNING id INTO v_sale_order_line_id;
                    
                    v_count := v_count + 1;
                    RAISE NOTICE '    ✅ Created SalesOrderLine % (line_number: %)', v_sale_order_line_id, v_line_number;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '    ❌ Error creating SalesOrderLine for QuoteLine %: %', 
                            v_quote_line_record.id, SQLERRM;
                END;
            ELSE
                RAISE NOTICE '    ⏭️  SalesOrderLine already exists for QuoteLine %', v_quote_line_record.id;
            END IF;
        END LOOP;
        
        RAISE NOTICE '  ✅ Completed SalesOrder %', v_so.sale_order_no;
    END LOOP;
    
    RAISE NOTICE '✅ Backfill complete:';
    RAISE NOTICE '   - Processed % SalesOrder(s)', v_so_count;
    RAISE NOTICE '   - Created % SalesOrderLine(s)', v_count;
END $$;

-- ====================================================
-- Verification Query
-- ====================================================

SELECT 
    'Final Verification: SalesOrders without SalesOrderLines' as check_name,
    COUNT(*) as so_without_lines,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All SalesOrders have SalesOrderLines'
        ELSE '❌ Some SalesOrders are still missing SalesOrderLines'
    END as status
FROM "SalesOrders" so
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
);

-- Detailed list of SalesOrders without lines (for debugging)
SELECT 
    'SalesOrders Missing Lines (Details)' as info,
    so.id,
    so.sale_order_no,
    so.quote_id,
    so.organization_id,
    so.created_at,
    q.quote_no
FROM "SalesOrders" so
LEFT JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
)
ORDER BY so.created_at;


