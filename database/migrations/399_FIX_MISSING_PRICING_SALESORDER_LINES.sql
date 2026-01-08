-- ====================================================
-- Migration 399: Fix missing pricing in SalesOrderLines
-- ====================================================
-- Corrección manual para las SalesOrderLines que no tienen pricing
-- pero sus QuoteLines sí lo tienen
-- ====================================================

SET search_path = public;

DO $$
DECLARE
    v_sol RECORD;
    v_ql RECORD;
    v_updated_count integer := 0;
    v_skipped_count integer := 0;
    v_error_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Fixing missing pricing in SalesOrderLines...';
    
    -- Iterar sobre SalesOrderLines sin pricing
    FOR v_sol IN
        SELECT sol.id, sol.quote_line_id
        FROM "SalesOrderLines" sol
        WHERE sol.deleted = false
        AND sol.quote_line_id IS NOT NULL
        AND (
            sol.list_unit_price_snapshot IS NULL 
            OR sol.list_unit_price_snapshot = 0
            OR sol.unit_price_snapshot IS NULL 
            OR sol.unit_price_snapshot = 0
        )
    LOOP
        -- Obtener pricing de QuoteLine (incluyendo deleted, porque es histórico)
        SELECT 
            unit_price_snapshot,
            list_unit_price_snapshot,
            unit_cost_snapshot,
            total_unit_cost_snapshot,
            line_total,
            computed_qty,
            discount_pct_used,
            customer_type_snapshot,
            price_basis,
            margin_pct_used,
            measure_basis_snapshot::text as measure_basis_snapshot,
            deleted
        INTO v_ql
        FROM "QuoteLines"
        WHERE id = v_sol.quote_line_id;
        -- NOTE: No filtramos por deleted = false porque necesitamos el pricing histórico
        -- incluso si la QuoteLine fue eliminada después
        
        IF NOT FOUND THEN
            RAISE NOTICE '  ⚠️  QuoteLine % not found for SalesOrderLine %', 
                v_sol.quote_line_id, v_sol.id;
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;
        
        -- Advertir si QuoteLine está deleted, pero continuar
        IF v_ql.deleted = true THEN
            RAISE NOTICE '  ⚠️  QuoteLine % is deleted, but copying historical pricing to SalesOrderLine %', 
                v_sol.quote_line_id, v_sol.id;
        END IF;
        
        -- Verificar si QuoteLine tiene pricing
        IF (v_ql.list_unit_price_snapshot IS NULL OR v_ql.list_unit_price_snapshot = 0)
           AND (v_ql.unit_price_snapshot IS NULL OR v_ql.unit_price_snapshot = 0) THEN
            RAISE NOTICE '  ⚠️  QuoteLine % has no pricing for SalesOrderLine %', 
                v_sol.quote_line_id, v_sol.id;
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;
        
        -- Actualizar SalesOrderLine con pricing de QuoteLine
        BEGIN
            UPDATE "SalesOrderLines"
            SET 
                unit_price_snapshot = COALESCE(v_ql.unit_price_snapshot, unit_price_snapshot),
                list_unit_price_snapshot = COALESCE(v_ql.list_unit_price_snapshot, list_unit_price_snapshot),
                unit_cost_snapshot = COALESCE(v_ql.unit_cost_snapshot, unit_cost_snapshot),
                total_unit_cost_snapshot = COALESCE(v_ql.total_unit_cost_snapshot, total_unit_cost_snapshot),
                line_total = COALESCE(v_ql.line_total, line_total),
                computed_qty = COALESCE(v_ql.computed_qty, computed_qty),
                discount_pct_used = COALESCE(v_ql.discount_pct_used, discount_pct_used),
                customer_type_snapshot = COALESCE(v_ql.customer_type_snapshot, customer_type_snapshot),
                price_basis = COALESCE(v_ql.price_basis, price_basis),
                margin_pct_used = COALESCE(v_ql.margin_pct_used, margin_pct_used),
                measure_basis_snapshot = COALESCE(v_ql.measure_basis_snapshot, measure_basis_snapshot),
                updated_at = now()
            WHERE id = v_sol.id;
            
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '  ✅ Updated SalesOrderLine % with pricing from QuoteLine % (MSRP: %, Net: %)', 
                v_sol.id, 
                v_sol.quote_line_id,
                v_ql.list_unit_price_snapshot,
                v_ql.unit_price_snapshot;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING '  ❌ Error updating SalesOrderLine %: %', v_sol.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '  ✅ Updated: % SalesOrderLines', v_updated_count;
    RAISE NOTICE '  ⚠️  Skipped: % SalesOrderLines (no QuoteLine or no pricing)', v_skipped_count;
    RAISE NOTICE '  ❌ Errors: % SalesOrderLines', v_error_count;
END $$;

-- Verificación post-fix
SELECT 
    'Verification: SalesOrderLines with pricing' as check_name,
    COUNT(*) FILTER (WHERE list_unit_price_snapshot IS NOT NULL AND list_unit_price_snapshot > 0 
                     AND unit_price_snapshot IS NOT NULL AND unit_price_snapshot > 0) as with_pricing,
    COUNT(*) FILTER (WHERE list_unit_price_snapshot IS NULL OR list_unit_price_snapshot = 0 
                     OR unit_price_snapshot IS NULL OR unit_price_snapshot = 0) as without_pricing,
    COUNT(*) as total_lines,
    CASE 
        WHEN COUNT(*) FILTER (WHERE list_unit_price_snapshot IS NULL OR list_unit_price_snapshot = 0 
                              OR unit_price_snapshot IS NULL OR unit_price_snapshot = 0) = 0 
        THEN '✅ All SalesOrderLines have pricing'
        ELSE '⚠️ Some SalesOrderLines are missing pricing'
    END as status
FROM "SalesOrderLines"
WHERE deleted = false
AND quote_line_id IS NOT NULL;

