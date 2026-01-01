-- ====================================================
-- Migration 291: Update existing SalesOrderLines with organization_id
-- ====================================================
-- Updates SalesOrderLines that are missing organization_id
-- ====================================================

DO $$
DECLARE
    v_updated_count integer := 0;
    v_sol_record RECORD;
BEGIN
    RAISE NOTICE '🔧 Updating SalesOrderLines with missing organization_id...';
    RAISE NOTICE '';
    
    -- Update SalesOrderLines that don't have organization_id
    FOR v_sol_record IN
        SELECT sol.id, sol.sale_order_id, so.organization_id
        FROM "SalesOrderLines" sol
        JOIN "SalesOrders" so ON so.id = sol.sale_order_id
        WHERE sol.organization_id IS NULL
        AND sol.deleted = false
        AND so.deleted = false
    LOOP
        BEGIN
            UPDATE "SalesOrderLines"
            SET organization_id = v_sol_record.organization_id,
                updated_at = now()
            WHERE id = v_sol_record.id;
            
            v_updated_count := v_updated_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ⚠️  Error updating SalesOrderLine %: %', v_sol_record.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Updated % SalesOrderLine(s) with organization_id', v_updated_count;
    
END $$;

-- Verify results
SELECT 
    'VERIFICATION' as step,
    COUNT(*) as total_sales_order_lines,
    COUNT(*) FILTER (WHERE organization_id IS NOT NULL) as with_org_id,
    COUNT(*) FILTER (WHERE organization_id IS NULL) as missing_org_id
FROM "SalesOrderLines"
WHERE deleted = false;


