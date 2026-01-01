-- ====================================================
-- Migration 286: Manual Creation of All Missing SalesOrders
-- ====================================================
-- Direct creation of SalesOrders, SalesOrderLines, and BOMs
-- for ALL approved quotes without SalesOrders
-- ====================================================

DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text;
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_counter integer;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_quote_line_record RECORD;
    v_bom_instance_id uuid;
    v_validated_side_channel_type text;
    v_created_count integer := 0;
    v_line_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Manually creating SalesOrders for all approved quotes without one...';
    RAISE NOTICE '';
    
    -- Find all approved quotes without SalesOrders
    FOR v_quote_id, v_quote_no IN
        SELECT q.id, q.quote_no
        FROM "Quotes" q
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "SalesOrders" so
            WHERE so.quote_id = q.id
            AND so.deleted = false
        )
        ORDER BY q.created_at ASC
    LOOP
        BEGIN
            RAISE NOTICE '========================================';
            RAISE NOTICE 'Processing Quote: % (%)', v_quote_no, v_quote_id;
            
            -- Load quote record
            SELECT * INTO v_quote_record
            FROM "Quotes"
            WHERE id = v_quote_id
            AND deleted = false;
            
            IF NOT FOUND THEN
                RAISE WARNING '  ⚠️  Quote not found, skipping';
                CONTINUE;
            END IF;
            
            RAISE NOTICE '  Quote loaded: organization_id=%, customer_id=%, status=%', 
                v_quote_record.organization_id, 
                v_quote_record.customer_id,
                v_quote_record.status;
            
            -- Generate sale order number
            BEGIN
                v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
            EXCEPTION
                WHEN OTHERS THEN
                    -- Fallback: use max + 1
                    SELECT COALESCE(MAX(CAST(SUBSTRING(sale_order_no FROM 'SO-(\d+)') AS INTEGER)), 0) + 1
                    INTO v_next_counter
                    FROM "SalesOrders"
                    WHERE organization_id = v_quote_record.organization_id;
            END;
            
            v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
            
            -- Extract totals from JSONB
            v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
            v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
            v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
            
            -- Create SaleOrder (handle optional fields safely)
            BEGIN
                INSERT INTO "SalesOrders" (
                    organization_id,
                    quote_id,
                    customer_id,
                    sale_order_no,
                    status,
                    currency,
                    subtotal,
                    tax,
                    total,
                    notes,
                    order_date,
                    deleted
                ) VALUES (
                    v_quote_record.organization_id,
                    v_quote_record.id,
                    v_quote_record.customer_id,
                    v_sale_order_no,
                    'Draft',  -- ⚠️ Must be 'Draft' (capital D), not 'draft'
                    COALESCE(v_quote_record.currency, 'USD'),
                    v_subtotal,
                    v_tax,
                    v_total,
                    v_quote_record.notes,
                    CURRENT_DATE,
                    false
                ) RETURNING id INTO v_sale_order_id;
                
                RAISE NOTICE '  ✅ Created SalesOrder % (%)', v_sale_order_no, v_sale_order_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error creating SalesOrder: %', SQLERRM;
                    RAISE WARNING '     Details: organization_id=%, quote_id=%, customer_id=%', 
                        v_quote_record.organization_id, v_quote_record.id, v_quote_record.customer_id;
                    -- Continue to next quote
                    CONTINUE;
            END;
            
            -- Create SalesOrderLines for each QuoteLine
            v_line_count := 0;
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
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                v_line_count := v_line_count + 1;
                
                -- Generate QuoteLineComponents if they don't exist
                IF NOT EXISTS (
                    SELECT 1 FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_quote_line_record.id
                    AND source = 'configured_component'
                    AND deleted = false
                ) AND v_quote_line_record.product_type_id IS NOT NULL THEN
                    BEGIN
                        PERFORM public.generate_configured_bom_for_quote_line(
                            v_quote_line_record.id,
                            v_quote_line_record.product_type_id,
                            v_quote_record.organization_id,
                            v_quote_line_record.drive_type,
                            v_quote_line_record.bottom_rail_type,
                            v_quote_line_record.cassette,
                            v_quote_line_record.cassette_type,
                            v_quote_line_record.side_channel,
                            v_quote_line_record.side_channel_type,
                            v_quote_line_record.hardware_color,
                            COALESCE(v_quote_line_record.width_m, 0),
                            COALESCE(v_quote_line_record.height_m, 0),
                            v_quote_line_record.qty,
                            v_quote_line_record.tube_type,
                            v_quote_line_record.operating_system_variant
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE WARNING '    ⚠️  Error generating QuoteLineComponents: %', SQLERRM;
                    END;
                END IF;
                
                -- Create BomInstance
                BEGIN
                    INSERT INTO "BomInstances" (
                        organization_id,
                        sale_order_line_id,
                        quote_line_id,
                        bom_template_id,
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_quote_record.organization_id,
                        v_sale_order_line_id,
                        v_quote_line_record.id,
                        NULL,
                        false,
                        now(),
                        now()
                    ) RETURNING id INTO v_bom_instance_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '    ⚠️  Error creating BomInstance: %', SQLERRM;
                END;
            END LOOP;
            
            RAISE NOTICE '  ✅ Created % SalesOrderLine(s)', v_line_count;
            v_created_count := v_created_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error processing Quote %: %', v_quote_no, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Completed. Created % SalesOrder(s)', v_created_count;
    
END $$;

-- Verify results
SELECT 
    q.quote_no,
    q.id as quote_id,
    q.status as quote_status,
    so.sale_order_no,
    so.id as sales_order_id,
    so.status as so_status,
    so.deleted as so_deleted,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count,
    (SELECT COUNT(*) FROM "BomInstances" bi 
     WHERE bi.sale_order_line_id IN (
         SELECT id FROM "SalesOrderLines" 
         WHERE sale_order_id = so.id AND deleted = false
     ) AND bi.deleted = false) as bom_count
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC
LIMIT 10;

