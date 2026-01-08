-- ====================================================
-- Migration 400: Fix computed_qty based on measure_basis
-- ====================================================
-- Recalculates computed_qty for existing QuoteLines based on:
-- - measure_basis = 'area' (FABRIC): computed_qty = width_m × height_m
-- - measure_basis = 'linear' (tube, cassette, etc.): computed_qty = width_m
-- Also updates measure_basis_snapshot based on ItemCategory code
-- ====================================================

SET search_path = public;

DO $$
DECLARE
    v_quote_line RECORD;
    v_category_code text;
    v_measure_basis text;
    v_computed_qty numeric(12,4);
    v_updated_count integer := 0;
    v_skipped_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Fixing computed_qty and measure_basis_snapshot for existing QuoteLines...';
    
    -- Iterate through all QuoteLines that need fixing
    FOR v_quote_line IN
        SELECT 
            ql.id,
            ql.catalog_item_id,
            ql.width_m,
            ql.height_m,
            ql.qty,
            ql.computed_qty,
            ql.measure_basis_snapshot,
            ci.item_category_id
        FROM "QuoteLines" ql
        INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
        WHERE ql.deleted = false
        AND ci.deleted = false
        AND ql.catalog_item_id IS NOT NULL
    LOOP
        -- Get category code
        v_category_code := NULL;
        IF v_quote_line.item_category_id IS NOT NULL THEN
            SELECT code INTO v_category_code
            FROM "ItemCategories"
            WHERE id = v_quote_line.item_category_id
            AND deleted = false;
        END IF;
        
        -- Determine measure_basis based on category code
        -- Valid enum values: 'unit', 'linear_m', 'area', 'fabric'
        IF v_category_code IS NOT NULL AND UPPER(v_category_code) LIKE '%FABRIC%' THEN
            v_measure_basis := 'area';
            -- For area: computed_qty = width_m × height_m
            IF v_quote_line.width_m IS NOT NULL AND v_quote_line.height_m IS NOT NULL THEN
                v_computed_qty := v_quote_line.width_m * v_quote_line.height_m;
            ELSE
                v_computed_qty := COALESCE(v_quote_line.qty, 1);
            END IF;
        ELSE
            v_measure_basis := 'linear_m';
            -- For linear: computed_qty = width_m (or height_m if width is not available)
            IF v_quote_line.width_m IS NOT NULL THEN
                v_computed_qty := v_quote_line.width_m;
            ELSIF v_quote_line.height_m IS NOT NULL THEN
                v_computed_qty := v_quote_line.height_m;
            ELSE
                v_computed_qty := COALESCE(v_quote_line.qty, 1);
            END IF;
        END IF;
        
        -- Update QuoteLine if computed_qty or measure_basis_snapshot needs correction
        -- Note: measure_basis_snapshot is text column (not enum)
        IF v_quote_line.computed_qty IS DISTINCT FROM v_computed_qty 
           OR (COALESCE(v_quote_line.measure_basis_snapshot::text, '') IS DISTINCT FROM v_measure_basis) THEN
            UPDATE "QuoteLines"
            SET 
                computed_qty = v_computed_qty,
                measure_basis_snapshot = v_measure_basis,
                updated_at = now()
            WHERE id = v_quote_line.id;
            
            v_updated_count := v_updated_count + 1;
            
            RAISE NOTICE '  ✅ Updated QuoteLine %: measure_basis=%, computed_qty=% (was %), category=%', 
                v_quote_line.id, 
                v_measure_basis,
                v_computed_qty,
                v_quote_line.computed_qty,
                COALESCE(v_category_code, 'unknown');
        ELSE
            v_skipped_count := v_skipped_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '  ✅ Updated: % QuoteLines', v_updated_count;
    RAISE NOTICE '  ⏭️  Skipped: % QuoteLines (already correct)', v_skipped_count;
END $$;

-- Verification query
-- Note: measure_basis_snapshot is text column
SELECT 
    'Verification: QuoteLines with corrected computed_qty' as check_name,
    COUNT(*) FILTER (WHERE measure_basis_snapshot = 'area' AND computed_qty = width_m * height_m) as area_correct,
    COUNT(*) FILTER (WHERE measure_basis_snapshot = 'linear_m' AND computed_qty = width_m) as linear_correct,
    COUNT(*) FILTER (WHERE measure_basis_snapshot IS NULL OR computed_qty IS NULL) as missing_data,
    COUNT(*) as total_lines
FROM "QuoteLines"
WHERE deleted = false
AND catalog_item_id IS NOT NULL;

