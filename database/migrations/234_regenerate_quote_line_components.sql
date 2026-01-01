-- ====================================================
-- Migration 234: Regenerate QuoteLineComponents with New Logic
-- ====================================================
-- Regenerates QuoteLineComponents for existing QuoteLines using
-- the new conditional role creation logic
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Delete existing QuoteLineComponents with source='configured_component'
-- ====================================================
-- This allows regeneration with the new logic
-- ====================================================

DO $$
DECLARE
    v_deleted_count integer;
BEGIN
    UPDATE "QuoteLineComponents"
    SET deleted = true,
        updated_at = now()
    WHERE source = 'configured_component'
        AND deleted = false
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Marked % existing configured QuoteLineComponents as deleted', v_deleted_count;
END $$;

-- ====================================================
-- STEP 2: Regenerate QuoteLineComponents for each QuoteLine
-- ====================================================
-- Uses the new generate_configured_bom_for_quote_line() function
-- ====================================================

DO $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_result jsonb;
    v_success_count integer := 0;
    v_error_count integer := 0;
BEGIN
    FOR v_quote_line_record IN
        SELECT 
            ql.id,
            ql.product_type_id,
            ql.organization_id,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            ql.tube_type,
            ql.operating_system_variant
        FROM "QuoteLines" ql
        WHERE ql.deleted = false
            AND ql.product_type_id IS NOT NULL
            AND ql.organization_id IS NOT NULL
            AND ql.created_at > NOW() - INTERVAL '30 days'
        ORDER BY ql.created_at DESC
    LOOP
        BEGIN
            -- Call generate_configured_bom_for_quote_line with all configuration fields
            v_bom_result := public.generate_configured_bom_for_quote_line(
                v_quote_line_record.id,
                v_quote_line_record.product_type_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.cassette,
                v_quote_line_record.cassette_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.qty,
                -- ⭐ Pass configuration fields for deterministic SKU resolution
                v_quote_line_record.tube_type,
                v_quote_line_record.operating_system_variant
            );
            
            IF (v_bom_result->>'success')::boolean = true THEN
                v_success_count := v_success_count + 1;
                RAISE NOTICE '✅ Regenerated BOM for QuoteLine % (components: %)', 
                    v_quote_line_record.id, 
                    jsonb_array_length(v_bom_result->'components');
            ELSE
                v_error_count := v_error_count + 1;
                RAISE WARNING '⚠️ Failed to regenerate BOM for QuoteLine %: %', 
                    v_quote_line_record.id, 
                    v_bom_result->>'message';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING '❌ Error regenerating BOM for QuoteLine %: %', 
                    v_quote_line_record.id, 
                    SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Regeneration complete: % successful, % errors', v_success_count, v_error_count;
END $$;

-- ====================================================
-- STEP 3: Verify regeneration results
-- ====================================================

DO $$
DECLARE
    v_total_quote_lines integer;
    v_with_components integer;
    v_component_count integer;
BEGIN
    SELECT COUNT(*) INTO v_total_quote_lines
    FROM "QuoteLines"
    WHERE deleted = false
        AND product_type_id IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(DISTINCT quote_line_id) INTO v_with_components
    FROM "QuoteLineComponents"
    WHERE deleted = false
        AND source = 'configured_component'
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    SELECT COUNT(*) INTO v_component_count
    FROM "QuoteLineComponents"
    WHERE deleted = false
        AND source = 'configured_component'
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    RAISE NOTICE '📊 Verification Results:';
    RAISE NOTICE '  Total QuoteLines: %', v_total_quote_lines;
    RAISE NOTICE '  QuoteLines with components: %', v_with_components;
    RAISE NOTICE '  Total components: %', v_component_count;
    RAISE NOTICE '  Average components per QuoteLine: %', 
        CASE WHEN v_with_components > 0 THEN ROUND(v_component_count::numeric / v_with_components, 2) ELSE 0 END;
END $$;

COMMIT;

