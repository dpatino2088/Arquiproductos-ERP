-- ====================================================
-- Migration 401: Fix computed_qty in SalesOrderLines from QuoteLines
-- ====================================================
-- Updates computed_qty in SalesOrderLines to match the corrected computed_qty
-- from their corresponding QuoteLines
-- ====================================================

SET search_path = public;

DO $$
DECLARE
    v_sol RECORD;
    v_ql_computed_qty numeric(12,4);
    v_updated_count integer := 0;
    v_skipped_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Fixing computed_qty in SalesOrderLines from QuoteLines...';
    
    -- Iterate through SalesOrderLines that have quote_line_id
    FOR v_sol IN
        SELECT 
            sol.id,
            sol.quote_line_id,
            sol.computed_qty as sol_computed_qty
        FROM "SalesOrderLines" sol
        WHERE sol.deleted = false
        AND sol.quote_line_id IS NOT NULL
    LOOP
        -- Get computed_qty from QuoteLine
        SELECT computed_qty INTO v_ql_computed_qty
        FROM "QuoteLines"
        WHERE id = v_sol.quote_line_id
        AND deleted = false;
        
        IF NOT FOUND THEN
            RAISE NOTICE '  ⚠️  QuoteLine % not found for SalesOrderLine %', 
                v_sol.quote_line_id, v_sol.id;
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;
        
        -- Update SalesOrderLine if computed_qty differs
        IF v_sol.sol_computed_qty IS DISTINCT FROM v_ql_computed_qty THEN
            UPDATE "SalesOrderLines"
            SET 
                computed_qty = v_ql_computed_qty,
                updated_at = now()
            WHERE id = v_sol.id;
            
            v_updated_count := v_updated_count + 1;
            
            RAISE NOTICE '  ✅ Updated SalesOrderLine %: computed_qty=% (was %)', 
                v_sol.id, 
                v_ql_computed_qty,
                v_sol.sol_computed_qty;
        ELSE
            v_skipped_count := v_skipped_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '  ✅ Updated: % SalesOrderLines', v_updated_count;
    RAISE NOTICE '  ⏭️  Skipped: % SalesOrderLines (already correct)', v_skipped_count;
END $$;

-- Verification query
SELECT 
    'Verification: SalesOrderLines with corrected computed_qty' as check_name,
    COUNT(*) FILTER (WHERE sol.computed_qty = ql.computed_qty) as matching_computed_qty,
    COUNT(*) FILTER (WHERE sol.computed_qty IS DISTINCT FROM ql.computed_qty) as mismatched_computed_qty,
    COUNT(*) as total_lines
FROM "SalesOrderLines" sol
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE sol.deleted = false
AND sol.quote_line_id IS NOT NULL
AND ql.deleted = false;


