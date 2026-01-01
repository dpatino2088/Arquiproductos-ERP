-- ====================================================
-- Migration 346: Generate QuoteLineComponents if Missing for MO-000003
-- ====================================================
-- This script checks if QuoteLineComponents exist and generates them if missing
-- ====================================================

DO $$
DECLARE
    v_quote_line_id uuid;
    v_quote_line RECORD;
    v_qlc_count integer;
    v_result jsonb;
BEGIN
    -- Get QuoteLine for MO-000003
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
    INTO v_quote_line
    FROM "QuoteLines" ql
    INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND mo.deleted = false
    AND ql.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ QuoteLine not found for MO-000003';
        RETURN;
    END IF;
    
    v_quote_line_id := v_quote_line.id;
    
    RAISE NOTICE '📝 QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '   Product Type ID: %', v_quote_line.product_type_id;
    RAISE NOTICE '   Drive Type: %', v_quote_line.drive_type;
    RAISE NOTICE '   Tube Type: %', v_quote_line.tube_type;
    RAISE NOTICE '';
    
    -- Check if QuoteLineComponents exist
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents" qlc
    WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
    
    RAISE NOTICE '🧩 Current QuoteLineComponents count: %', v_qlc_count;
    
    IF v_qlc_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ QuoteLineComponents already exist. No need to generate.';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  No QuoteLineComponents found. Generating now...';
    RAISE NOTICE '';
    
    -- Generate QuoteLineComponents
    BEGIN
        v_result := public.generate_configured_bom_for_quote_line(
            p_quote_line_id := v_quote_line_id,
            p_product_type_id := v_quote_line.product_type_id,
            p_organization_id := v_quote_line.organization_id,
            p_drive_type := COALESCE(v_quote_line.drive_type, 'manual'),
            p_bottom_rail_type := COALESCE(v_quote_line.bottom_rail_type, 'standard'),
            p_cassette := COALESCE(v_quote_line.cassette, false),
            p_cassette_type := v_quote_line.cassette_type,
            p_side_channel := COALESCE(v_quote_line.side_channel, false),
            p_side_channel_type := v_quote_line.side_channel_type,
            p_hardware_color := COALESCE(v_quote_line.hardware_color, 'white'),
            p_width_m := v_quote_line.width_m,
            p_height_m := v_quote_line.height_m,
            p_qty := v_quote_line.qty,
            p_tube_type := v_quote_line.tube_type,
            p_operating_system_variant := v_quote_line.operating_system_variant
        );
        
        IF (v_result->>'success')::boolean THEN
            RAISE NOTICE '✅ QuoteLineComponents generated successfully!';
            RAISE NOTICE '   Components created: %', v_result->>'components_created';
        ELSE
            RAISE WARNING '❌ Error generating QuoteLineComponents: %', v_result->>'error';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Exception while generating QuoteLineComponents: %', SQLERRM;
            RAISE WARNING '   SQLSTATE: %', SQLSTATE;
    END;
    
    -- Verify after generation
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents" qlc
    WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 QuoteLineComponents after generation: %', v_qlc_count;
    
    IF v_qlc_count > 0 THEN
        RAISE NOTICE '✅ Now you can run generate_bom_for_manufacturing_order for MO-000003';
    ELSE
        RAISE WARNING '❌ Still no QuoteLineComponents after generation. Check errors above.';
    END IF;
    
END $$;


