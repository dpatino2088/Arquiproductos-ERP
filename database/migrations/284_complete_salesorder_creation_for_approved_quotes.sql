-- ====================================================
-- Migration 284: Complete SalesOrder Creation for Approved Quotes
-- ====================================================
-- This script creates SalesOrders, SalesOrderLines, and BOMs
-- for approved quotes that don't have them
-- ====================================================

-- First, ensure trigger exists and is enabled
DO $$
BEGIN
    -- Drop and recreate trigger to ensure it's active
    DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";
    
    CREATE TRIGGER trg_on_quote_approved_create_operational_docs
        AFTER UPDATE OF status ON "Quotes"
        FOR EACH ROW
        WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
        EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();
    
    RAISE NOTICE '✅ Trigger recreated and enabled';
END $$;

-- Now, for approved quotes without SalesOrders, we'll simulate the trigger
-- by temporarily changing status and then changing it back
DO $$
DECLARE
    v_quote_id uuid;
    v_quote_no text;
    v_old_status text;
    v_created_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Creating SalesOrders for approved quotes without one...';
    RAISE NOTICE '';
    
    -- Find approved quotes without SalesOrders
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
            RAISE NOTICE 'Processing Quote: % (%)', v_quote_no, v_quote_id;
            
            -- Get current status
            SELECT status INTO v_old_status
            FROM "Quotes"
            WHERE id = v_quote_id;
            
            -- Temporarily change status to 'draft' to allow trigger to fire
            UPDATE "Quotes"
            SET status = 'draft'
            WHERE id = v_quote_id;
            
            -- Now change back to 'approved' to trigger the function
            UPDATE "Quotes"
            SET status = 'approved'
            WHERE id = v_quote_id;
            
            RAISE NOTICE '  ✅ Triggered SalesOrder creation for Quote %', v_quote_no;
            v_created_count := v_created_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error processing Quote %: %', v_quote_no, SQLERRM;
                -- Restore original status on error
                BEGIN
                    IF v_old_status IS NOT NULL THEN
                        UPDATE "Quotes"
                        SET status = v_old_status
                        WHERE id = v_quote_id;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL; -- Ignore restore errors
                END;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Completed. Processed % quote(s)', v_created_count;
    
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
    (SELECT COUNT(*) FROM "BomInstances" bi WHERE bi.sale_order_line_id IN (SELECT id FROM "SalesOrderLines" WHERE sale_order_id = so.id AND deleted = false) AND bi.deleted = false) as bom_count
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC
LIMIT 10;

