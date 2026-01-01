-- ====================================================
-- Migration 293: Diagnose why frontend can't find SalesOrderLines
-- ====================================================
-- Simulates the exact query the frontend uses
-- ====================================================

-- Get the organization_id for SO-090154
SELECT 
    'Organization Check' as step,
    so.sale_order_no,
    so.organization_id,
    so.id as sale_order_id
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false;

-- Simulate the EXACT frontend query (from OrderList.tsx line 368-373)
-- This is what the frontend is doing:
DO $$
DECLARE
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_sale_order_lines_count integer;
    rec RECORD;
BEGIN
    -- Get SalesOrder ID and organization_id
    SELECT so.id, so.organization_id 
    INTO v_sale_order_id, v_organization_id
    FROM "SalesOrders" so
    WHERE so.sale_order_no = 'SO-090154'
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ SalesOrder not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'SalesOrder ID: %', v_sale_order_id;
    RAISE NOTICE 'Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Simulate frontend query: SELECT id FROM SalesOrderLines WHERE sale_order_id = X AND organization_id = Y AND deleted = false
    SELECT COUNT(*) INTO v_sale_order_lines_count
    FROM "SalesOrderLines"
    WHERE sale_order_id = v_sale_order_id
    AND organization_id = v_organization_id
    AND deleted = false;
    
    RAISE NOTICE 'Frontend query result: % SalesOrderLines found', v_sale_order_lines_count;
    
    IF v_sale_order_lines_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  PROBLEM IDENTIFIED: Frontend query returns 0 results';
        RAISE NOTICE '';
        RAISE NOTICE 'Checking SalesOrderLines without organization_id filter:';
        
        SELECT COUNT(*) INTO v_sale_order_lines_count
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND deleted = false;
        
        RAISE NOTICE 'SalesOrderLines without org filter: %', v_sale_order_lines_count;
        
        -- Show the actual organization_id values
        RAISE NOTICE '';
        RAISE NOTICE 'SalesOrderLines details:';
        FOR rec IN
            SELECT id, sale_order_id, organization_id, line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND deleted = false
        LOOP
            RAISE NOTICE '  SOL ID: %, Org ID: %, Line: %', rec.id, rec.organization_id, rec.line_number;
        END LOOP;
    ELSE
        RAISE NOTICE '✅ Frontend query should work correctly';
    END IF;
END $$;

-- Also check RLS policies
SELECT 
    'RLS Check' as step,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'SalesOrderLines'
ORDER BY policyname;

