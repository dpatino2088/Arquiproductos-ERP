-- ====================================================
-- Test Script: Verify Quote Approved Trigger (Migration 212)
-- ====================================================
-- This script helps test the trigger that creates SalesOrders when Quotes are approved
-- ====================================================

-- STEP 1: Find Quotes that can be approved
-- ====================================================
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.organization_id,
    q.customer_id,
    (SELECT COUNT(*) FROM "QuoteLines" ql WHERE ql.quote_id = q.id AND ql.deleted = false) as line_count,
    q.created_at,
    -- Check if SalesOrder already exists
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM "SalesOrders" so 
            WHERE so.quote_id = q.id 
            AND so.deleted = false
        ) THEN '✅ SalesOrder exists'
        ELSE '❌ No SalesOrder'
    END as sales_order_status
FROM "Quotes" q
WHERE q.deleted = false
AND q.status != 'approved'  -- Quotes that are not yet approved
ORDER BY q.created_at DESC
LIMIT 10;

-- ====================================================
-- STEP 2: Select a Quote ID to test (replace <quote_id> below)
-- ====================================================
-- Copy one of the quote IDs from above and use it in the next steps

-- ====================================================
-- STEP 3: Check Quote details before approval
-- ====================================================
-- Replace <quote_id> with actual quote ID
/*
DO $$
DECLARE
    v_quote_id uuid := '<quote_id>';  -- Replace with actual quote ID
    v_quote_record RECORD;
    v_line_count integer;
BEGIN
    -- Get quote details
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Quote % not found', v_quote_id;
        RETURN;
    END IF;
    
    -- Count quote lines
    SELECT COUNT(*) INTO v_line_count
    FROM "QuoteLines"
    WHERE quote_id = v_quote_id
    AND deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Quote Details:';
    RAISE NOTICE '   ID: %', v_quote_id;
    RAISE NOTICE '   Quote No: %', v_quote_record.quote_no;
    RAISE NOTICE '   Status: %', v_quote_record.status;
    RAISE NOTICE '   Organization ID: %', v_quote_record.organization_id;
    RAISE NOTICE '   Customer ID: %', v_quote_record.customer_id;
    RAISE NOTICE '   Line Count: %', v_line_count;
    RAISE NOTICE '   Totals: %', v_quote_record.totals;
    RAISE NOTICE '';
    
    -- Check if SalesOrder already exists
    IF EXISTS (
        SELECT 1 FROM "SalesOrders" so 
        WHERE so.quote_id = v_quote_id 
        AND so.deleted = false
    ) THEN
        RAISE NOTICE '⚠️  SalesOrder already exists for this Quote';
    ELSE
        RAISE NOTICE '✅ No SalesOrder exists yet - ready to test trigger';
    END IF;
END $$;
*/

-- ====================================================
-- STEP 4: Approve the Quote (this will trigger SalesOrder creation)
-- ====================================================
-- Replace <quote_id> with actual quote ID
-- Uncomment the line below when ready to test
/*
UPDATE "Quotes"
SET status = 'approved',
    updated_at = NOW()
WHERE id = '<quote_id>'  -- Replace with actual quote ID
AND deleted = false
AND status != 'approved';  -- Only update if not already approved
*/

-- ====================================================
-- STEP 5: Verify SalesOrder was created
-- ====================================================
-- Replace <quote_id> with actual quote ID
/*
SELECT 
    so.id as sales_order_id,
    so.sale_order_no,
    so.status,
    so.order_progress_status,
    so.quote_id,
    so.customer_id,
    so.subtotal,
    so.tax,
    so.total,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND so.deleted = false;
*/

-- ====================================================
-- STEP 6: Verify SalesOrderLines were created
-- ====================================================
-- Replace <quote_id> with actual quote ID
/*
SELECT 
    sol.id,
    sol.line_number,
    sol.sku,
    sol.item_name,
    sol.qty,
    sol.unit_price,
    sol.line_total,
    sol.width_m,
    sol.height_m,
    sol.area,
    sol.product_type,
    sol.drive_type,
    sol.hardware_color
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND sol.deleted = false
ORDER BY sol.line_number;
*/

-- ====================================================
-- STEP 7: Verify BomInstances were created
-- ====================================================
-- Replace <quote_id> with actual quote ID
/*
SELECT 
    bi.id as bom_instance_id,
    bi.status,
    bi.sale_order_line_id,
    bi.quote_line_id,
    sol.line_number,
    sol.sku,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil WHERE bil.bom_instance_id = bi.id AND bil.deleted = false) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND bi.deleted = false
ORDER BY sol.line_number;
*/

-- ====================================================
-- STEP 8: Verify BomInstanceLines were created
-- ====================================================
-- Replace <quote_id> with actual quote ID
/*
SELECT 
    bil.id,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.description,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.category_code,
    ci.sku as resolved_sku,
    sol.line_number as sale_order_line_number
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND bil.deleted = false
ORDER BY sol.line_number, bil.part_role;
*/

-- ====================================================
-- STEP 9: Summary Report
-- ====================================================
-- Replace <quote_id> with actual quote ID
/*
SELECT 
    'Quote' as entity_type,
    q.quote_no as document_number,
    q.status as status,
    q.created_at
FROM "Quotes" q
WHERE q.id = '<quote_id>'  -- Replace with actual quote ID

UNION ALL

SELECT 
    'SalesOrder' as entity_type,
    so.sale_order_no as document_number,
    so.status as status,
    so.created_at
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND so.deleted = false

ORDER BY created_at;
*/

-- ====================================================
-- STEP 10: Check trigger logs (if available)
-- ====================================================
-- The trigger uses RAISE NOTICE, so check the PostgreSQL logs
-- or Supabase logs for messages like:
-- "🔔 Trigger fired: Quote <id> status changed to approved"
-- "✅ Created SaleOrder <number> for Quote <id>"
-- "✅ Applied engineering rules to BomInstance <id>"




