-- ====================================================
-- Force create SalesOrder for an approved quote
-- ====================================================
-- Use this if the trigger is not working
-- Replace 'QT-000001' with your actual quote_no
-- ====================================================

-- Get quote info
SELECT 
    id,
    quote_no,
    status,
    organization_id,
    customer_id,
    totals
FROM "Quotes"
WHERE quote_no = 'QT-000001'  -- ⚠️ CHANGE THIS to your quote number
AND deleted = false;

-- Manually create SalesOrder (replace values with actual from query above)
-- Uncomment and fill in the values:
/*
DO $$
DECLARE
    v_quote_id uuid := 'YOUR-QUOTE-ID-HERE'::uuid;  -- From query above
    v_org_id uuid := 'YOUR-ORG-ID-HERE'::uuid;     -- From query above
    v_customer_id uuid := 'YOUR-CUSTOMER-ID-HERE'::uuid;  -- From query above
    v_next_counter integer;
    v_sale_order_no text;
    v_sale_order_id uuid;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_quote_record RECORD;
BEGIN
    -- Get quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_id;
    
    -- Generate sale order number
    v_next_counter := public.get_next_counter_value(v_org_id, 'sale_order');
    v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
    
    -- Extract totals
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    
    -- Create SalesOrder
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
        v_org_id,
        v_quote_id,
        v_customer_id,
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
    
    RAISE NOTICE '✅ Created SalesOrder % (sale_order_no: %)', v_sale_order_id, v_sale_order_no;
END $$;
*/



