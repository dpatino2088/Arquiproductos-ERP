-- ====================================================
-- Migration 287: Simple SalesOrder Creation for QT-000003
-- ====================================================
-- Very simple, step-by-step creation to identify the issue
-- ====================================================

-- Step 1: Check the quote
SELECT 
    id,
    quote_no,
    status,
    organization_id,
    customer_id,
    currency,
    totals,
    deleted
FROM "Quotes"
WHERE quote_no = 'QT-000003'
AND deleted = false;

-- Step 2: Check if SalesOrder already exists
SELECT 
    id,
    sale_order_no,
    quote_id,
    status,
    deleted
FROM "SalesOrders"
WHERE quote_id = 'c5a81f6a-cb1d-4672-bb7e-38b850229aaa'::uuid
AND deleted = false;

-- Step 3: Get next counter value
SELECT public.get_next_counter_value(
    (SELECT organization_id FROM "Quotes" WHERE quote_no = 'QT-000003' AND deleted = false),
    'sale_order'
) as next_counter;

-- Step 4: Create SalesOrder (simple version)
DO $$
DECLARE
    v_quote_id uuid := 'c5a81f6a-cb1d-4672-bb7e-38b850229aaa'::uuid;
    v_org_id uuid;
    v_customer_id uuid;
    v_currency text;
    v_totals jsonb;
    v_next_counter integer;
    v_sale_order_no text;
    v_sale_order_id uuid;
BEGIN
    -- Get quote data
    SELECT 
        organization_id,
        customer_id,
        currency,
        totals
    INTO v_org_id, v_customer_id, v_currency, v_totals
    FROM "Quotes"
    WHERE id = v_quote_id
    AND deleted = false;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Quote not found or organization_id is NULL';
    END IF;
    
    RAISE NOTICE 'Quote found: org_id=%, customer_id=%, currency=%', v_org_id, v_customer_id, v_currency;
    
    -- Get next counter
    BEGIN
        v_next_counter := public.get_next_counter_value(v_org_id, 'sale_order');
    EXCEPTION
        WHEN OTHERS THEN
            -- Fallback
            SELECT COALESCE(MAX(CAST(SUBSTRING(sale_order_no FROM 'SO-(\d+)') AS INTEGER)), 0) + 1
            INTO v_next_counter
            FROM "SalesOrders"
            WHERE organization_id = v_org_id;
    END;
    
    v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
    RAISE NOTICE 'Next SO number: %', v_sale_order_no;
    
    -- Create SalesOrder (status must be 'Draft' with capital D per constraint)
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
        order_date,
        deleted
    ) VALUES (
        v_org_id,
        v_quote_id,
        v_customer_id,
        v_sale_order_no,
        'Draft',  -- ⚠️ Must be 'Draft' (capital D), not 'draft'
        COALESCE(v_currency, 'USD'),
        COALESCE((v_totals->>'subtotal')::numeric(12,4), 0),
        COALESCE((v_totals->>'tax')::numeric(12,4), 0),
        COALESCE((v_totals->>'total')::numeric(12,4), 0),
        CURRENT_DATE,
        false
    ) RETURNING id INTO v_sale_order_id;
    
    RAISE NOTICE '✅ SalesOrder created: % (%)', v_sale_order_no, v_sale_order_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error creating SalesOrder: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- Step 5: Verify it was created
SELECT 
    so.id,
    so.sale_order_no,
    so.quote_id,
    so.status,
    so.deleted,
    q.quote_no
FROM "SalesOrders" so
JOIN "Quotes" q ON q.id = so.quote_id
WHERE q.quote_no = 'QT-000003'
AND so.deleted = false;

