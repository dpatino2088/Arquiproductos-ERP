-- ====================================================
-- Test the trigger function manually
-- ====================================================
-- This will help us see if there are any errors
-- ====================================================

-- 1. Get the most recent approved quote
SELECT 
    id,
    quote_no,
    status,
    organization_id,
    customer_id,
    updated_at
FROM "Quotes"
WHERE status = 'approved'
AND deleted = false
ORDER BY updated_at DESC
LIMIT 1;

-- 2. Check if SalesOrder exists for that quote
SELECT 
    q.id as quote_id,
    q.quote_no,
    q.status,
    so.id as sale_order_id,
    so.sale_order_no,
    so.deleted
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 1;

-- 3. Try to manually call the function (replace quote_id with actual ID from query 1)
-- First, let's see what happens when we simulate the trigger
-- This creates a NEW record to test with
DO $$
DECLARE
    v_quote_id uuid;
    v_old_record RECORD;
    v_new_record RECORD;
BEGIN
    -- Get the most recent approved quote
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE status = 'approved'
    AND deleted = false
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_quote_id IS NULL THEN
        RAISE NOTICE 'No approved quote found';
        RETURN;
    END IF;
    
    -- Get the quote record
    SELECT * INTO v_new_record FROM "Quotes" WHERE id = v_quote_id;
    v_old_record := v_new_record;
    v_old_record.status := 'draft'; -- Simulate old status
    
    RAISE NOTICE 'Testing trigger function for quote %', v_quote_id;
    
    -- Call the function directly (this simulates what the trigger does)
    -- Note: This won't work directly because it's a trigger function
    -- But we can check the logs
    
END $$;

-- 4. Better approach: Check if there are any errors in the function by looking at what it should create
-- Check if QuoteLineComponents exist (needed for BOM generation)
SELECT 
    q.id as quote_id,
    q.quote_no,
    COUNT(ql.id) as quote_lines_count,
    COUNT(qlc.id) as quote_line_components_count
FROM "Quotes" q
LEFT JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
GROUP BY q.id, q.quote_no
ORDER BY q.updated_at DESC
LIMIT 5;



