-- ====================================================
-- Script: Regenerate BOM from QuoteLines (Simplified)
-- ====================================================
-- This script regenerates BOM components for all approved quotes
-- It calls generate_configured_bom_for_quote_line for each QuoteLine
-- ====================================================

DO $$
DECLARE
    v_quote_line_record record;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_total_quote_lines integer;
BEGIN
    RAISE NOTICE '🔄 Starting BOM regeneration from QuoteLines...';
    
    -- Count total quote lines to process
    SELECT COUNT(*) INTO v_total_quote_lines
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    WHERE q.status = 'approved'
    AND q.deleted = false
    AND ql.deleted = false
    AND ql.product_type_id IS NOT NULL;
    
    RAISE NOTICE '📊 Found % QuoteLines to process', v_total_quote_lines;
    
    -- Process each quote line
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            COALESCE(ql.drive_type, 'manual') as drive_type,
            COALESCE(ql.bottom_rail_type, 'standard') as bottom_rail_type,
            COALESCE(ql.cassette, false) as cassette,
            ql.cassette_type,
            COALESCE(ql.side_channel, false) as side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            q.quote_no
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND ql.deleted = false
        AND ql.product_type_id IS NOT NULL
        ORDER BY q.created_at DESC, ql.id
    LOOP
        BEGIN
            -- Check required fields
            IF v_quote_line_record.drive_type IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % (Quote: %) has no drive_type, skipping', 
                    v_quote_line_record.quote_line_id, v_quote_line_record.quote_no;
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
            
            -- Regenerate BOM for this quote line
            PERFORM public.generate_configured_bom_for_quote_line(
                v_quote_line_record.quote_line_id,
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
                v_quote_line_record.qty
            );
            
            v_updated_count := v_updated_count + 1;
            
            IF v_updated_count % 10 = 0 THEN
                RAISE NOTICE '   ✅ Processed % QuoteLines...', v_updated_count;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ❌ Error regenerating BOM for QuoteLine % (Quote: %): %', 
                    v_quote_line_record.quote_line_id, 
                    v_quote_line_record.quote_no,
                    SQLERRM;
                v_error_count := v_error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM regeneration completed!';
    RAISE NOTICE '   - Successfully processed: % QuoteLines', v_updated_count;
    RAISE NOTICE '   - Errors: % QuoteLines', v_error_count;
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. The QuoteLineComponents have been regenerated';
    RAISE NOTICE '   2. To update BomInstanceLines, you need to re-approve the quotes';
    RAISE NOTICE '   3. OR manually trigger the operational docs creation';
    RAISE NOTICE '';
    RAISE NOTICE '   To re-approve quotes, you can:';
    RAISE NOTICE '   - Set quote status to ''draft'', then back to ''approved''';
    RAISE NOTICE '   - This will trigger the on_quote_approved_create_operational_docs function';
    
END $$;

-- After regenerating QuoteLineComponents, update category_code in existing BomInstanceLines
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    RAISE NOTICE '🔄 Updating category_code in existing BomInstanceLines...';
    
    UPDATE "BomInstanceLines" bil
    SET 
        category_code = public.derive_category_code_from_role(bil.part_role),
        updated_at = NOW()
    WHERE 
        bil.deleted = false
        AND bil.category_code IS DISTINCT FROM public.derive_category_code_from_role(bil.part_role);
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % BomInstanceLines with new category_code', v_updated_count;
END $$;








