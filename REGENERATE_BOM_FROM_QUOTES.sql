-- ====================================================
-- Script: Regenerate BOM from Approved Quotes
-- ====================================================
-- This script regenerates BOMs completely from approved quotes
-- Use this if you need to rebuild BOMs from scratch
-- ====================================================

DO $$
DECLARE
    v_quote_record record;
    v_quote_line_record record;
    v_updated_count integer;
    v_total_quotes integer;
    v_total_quote_lines integer;
BEGIN
    RAISE NOTICE '🔄 Starting complete BOM regeneration from approved quotes...';
    
    -- Step 1: Count approved quotes
    SELECT COUNT(*) INTO v_total_quotes
    FROM "Quotes"
    WHERE status = 'approved'
    AND deleted = false;
    
    RAISE NOTICE '📊 Found % approved quotes to process', v_total_quotes;
    
    -- Step 2: Process each approved quote
    FOR v_quote_record IN
        SELECT id, quote_no, organization_id
        FROM "Quotes"
        WHERE status = 'approved'
        AND deleted = false
        ORDER BY created_at DESC
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '📋 Processing Quote: % (ID: %)', v_quote_record.quote_no, v_quote_record.id;
        
        -- Step 3: Get quote lines for this quote
        FOR v_quote_line_record IN
            SELECT 
                ql.id,
                ql.product_type_id,
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
                ql.organization_id
            FROM "QuoteLines" ql
            WHERE ql.quote_id = v_quote_record.id
            AND ql.deleted = false
        LOOP
            RAISE NOTICE '   📦 Processing QuoteLine: %', v_quote_line_record.id;
            
            -- Check if configuration is complete
            IF v_quote_line_record.product_type_id IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % has no product_type_id, skipping', v_quote_line_record.id;
                CONTINUE;
            END IF;
            
            IF v_quote_line_record.drive_type IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % has no drive_type, skipping', v_quote_line_record.id;
                CONTINUE;
            END IF;
            
            -- Regenerate BOM for this quote line
            BEGIN
                PERFORM public.generate_configured_bom_for_quote_line(
                    v_quote_line_record.id,
                    v_quote_line_record.product_type_id,
                    v_quote_line_record.organization_id,
                    v_quote_line_record.drive_type,
                    COALESCE(v_quote_line_record.bottom_rail_type, 'standard'),
                    COALESCE(v_quote_line_record.cassette, false),
                    v_quote_line_record.cassette_type,
                    COALESCE(v_quote_line_record.side_channel, false),
                    v_quote_line_record.side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.qty
                );
                
                RAISE NOTICE '   ✅ BOM regenerated for QuoteLine %', v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error regenerating BOM for QuoteLine %: %', v_quote_line_record.id, SQLERRM;
            END;
        END LOOP;
        
        -- Step 4: Note about operational docs
        -- SaleOrders and BomInstances are created automatically by the trigger
        -- when quotes are approved. To regenerate them, you would need to:
        -- 1. Set quote status to 'draft'
        -- 2. Set quote status back to 'approved' (triggers the function)
        -- OR manually delete and recreate SaleOrders/BomInstances
        -- For now, we're only regenerating QuoteLineComponents (BOM structure)
    END LOOP;
    
    -- Step 5: Regenerate category_code for all BomInstanceLines
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Regenerating category_code for all BomInstanceLines...';
    
    UPDATE "BomInstanceLines" bil
    SET 
        category_code = public.derive_category_code_from_role(bil.part_role),
        updated_at = NOW()
    WHERE 
        bil.deleted = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % BomInstanceLines with new category_code', v_updated_count;
    
    -- Step 6: Show summary
    RAISE NOTICE '';
    RAISE NOTICE '📊 Final Summary:';
    RAISE NOTICE '   - Quotes processed: %', v_total_quotes;
    RAISE NOTICE '   - BomInstanceLines updated: %', v_updated_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ Complete BOM regeneration finished!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Check Manufacturing Order BOM tabs';
    RAISE NOTICE '   2. Verify all components are visible and correctly categorized';
    
END $$;

