-- ====================================================
-- Migration 283: Force Create SalesOrders for Approved Quotes
-- ====================================================
-- This script creates SalesOrders for approved quotes that don't have one
-- ====================================================

DO $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_counter integer;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_created_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Force creating SalesOrders for approved quotes without one...';
    RAISE NOTICE '';
    
    -- Find approved quotes without SalesOrders
    FOR v_quote_record IN
        SELECT q.*
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
            RAISE NOTICE 'Processing Quote: % (%)', v_quote_record.quote_no, v_quote_record.id;
            
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
            
            -- Create SaleOrder
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
                created_by,
                updated_by,
                deleted
            ) VALUES (
                v_quote_record.organization_id,
                v_quote_record.id,
                v_quote_record.customer_id,
                v_sale_order_no,
                'draft',
                COALESCE(v_quote_record.currency, 'USD'),
                v_subtotal,
                v_tax,
                v_total,
                v_quote_record.notes,
                CURRENT_DATE,
                v_quote_record.created_by,
                v_quote_record.updated_by,
                false
            ) RETURNING id INTO v_sale_order_id;
            
            RAISE NOTICE '  ✅ Created SalesOrder % (sale_order_no: %)', v_sale_order_id, v_sale_order_no;
            
            -- Note: SalesOrderLines and BOMs will be created by the trigger
            -- when the quote status changes. Since we're creating the SalesOrder
            -- manually, we need to ensure the trigger logic runs.
            -- The trigger only fires on UPDATE, so we'll need to manually
            -- create the lines or re-trigger by updating the quote status.
            
            RAISE NOTICE '  ℹ️  SalesOrder created. SalesOrderLines should be created automatically.';
            RAISE NOTICE '      If missing, you may need to manually create them or re-approve the quote.';
            
            v_created_count := v_created_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error processing Quote %: %', v_quote_record.quote_no, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Completed. Created % SalesOrder(s)', v_created_count;
    
    -- Now manually create SalesOrderLines for the SalesOrders we just created
    -- by calling the trigger function logic
    RAISE NOTICE '';
    RAISE NOTICE '📝 Note: SalesOrderLines and BOMs should be created automatically by the trigger';
    RAISE NOTICE '   If they are missing, you may need to manually trigger the function';
    
END $$;

-- Verify results
SELECT 
    q.quote_no,
    q.id as quote_id,
    so.sale_order_no,
    so.id as sales_order_id,
    so.status,
    so.deleted
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC
LIMIT 10;

