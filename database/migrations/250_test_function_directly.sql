-- ====================================================
-- Migration 250: Test Function Directly
-- ====================================================
-- Test generate_configured_bom_for_quote_line directly for one QuoteLine
-- ====================================================

-- ====================================================
-- STEP 1: Get a QuoteLine to test
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    ql.width_m,
    ql.height_m
FROM "QuoteLines" ql
WHERE ql.deleted = false
    AND ql.drive_type = 'motor'
    AND ql.product_type_id IS NOT NULL
    AND ql.organization_id IS NOT NULL
    AND ql.tube_type IS NOT NULL
    AND ql.operating_system_variant IS NOT NULL
    AND ql.created_at > NOW() - INTERVAL '30 days'
ORDER BY ql.created_at DESC
LIMIT 1;

-- ====================================================
-- STEP 2: Delete existing components for this QuoteLine
-- ====================================================

DO $$
DECLARE
    v_quote_line_id uuid;
    v_deleted_count integer;
BEGIN
    -- Get a QuoteLine ID
    SELECT id INTO v_quote_line_id
    FROM "QuoteLines"
    WHERE deleted = false
        AND drive_type = 'motor'
        AND product_type_id IS NOT NULL
        AND organization_id IS NOT NULL
        AND tube_type IS NOT NULL
        AND operating_system_variant IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days'
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_quote_line_id IS NULL THEN
        RAISE NOTICE '❌ No QuoteLine found for testing';
        RETURN;
    END IF;
    
    -- Delete existing components
    UPDATE "QuoteLineComponents"
    SET deleted = true, updated_at = now()
    WHERE quote_line_id = v_quote_line_id
        AND source = 'configured_component'
        AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Deleted % existing components for QuoteLine %', v_deleted_count, v_quote_line_id;
END $$;

-- ====================================================
-- STEP 3: Call the function and show result
-- ====================================================
-- Replace <QUOTE_LINE_ID> with the ID from STEP 1
-- ====================================================

-- First, get the QuoteLine details
DO $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_result jsonb;
    v_quote_line_id uuid;
BEGIN
    -- Get QuoteLine
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
        COALESCE(
            ql.tube_type,
            CASE
                WHEN ql.operating_system_variant ILIKE '%standard_m%' OR ql.operating_system_variant ILIKE '%m%' THEN 'RTU-42'
                WHEN ql.operating_system_variant ILIKE '%standard_l%' OR ql.operating_system_variant ILIKE '%l%' THEN 'RTU-65'
                ELSE NULL
            END
        ) as tube_type,
        COALESCE(ql.operating_system_variant, 'standard_m') as operating_system_variant
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    WHERE ql.deleted = false
        AND ql.drive_type = 'motor'
        AND ql.product_type_id IS NOT NULL
        AND ql.organization_id IS NOT NULL
        AND ql.created_at > NOW() - INTERVAL '30 days'
    ORDER BY ql.created_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ No QuoteLine found';
        RETURN;
    END IF;
    
    v_quote_line_id := v_quote_line_record.id;
    
    RAISE NOTICE '🧪 Testing BOM generation for QuoteLine: %', v_quote_line_id;
    RAISE NOTICE '  Config: drive_type=%, tube_type=%, os_variant=%', 
        v_quote_line_record.drive_type,
        v_quote_line_record.tube_type,
        v_quote_line_record.operating_system_variant;
    
    -- Call function
    BEGIN
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
            v_quote_line_record.tube_type,
            v_quote_line_record.operating_system_variant
        );
        
        RAISE NOTICE '✅ Function returned:';
        RAISE NOTICE '  Success: %', v_bom_result->>'success';
        RAISE NOTICE '  Components count: %', jsonb_array_length(v_bom_result->'components');
        RAISE NOTICE '  Required roles: %', v_bom_result->'required_roles';
        RAISE NOTICE '  Missing roles: %', v_bom_result->'missing_roles';
        RAISE NOTICE '  Resolution errors: %', v_bom_result->'resolution_errors';
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
    END;
    
    -- Check what was actually created
    DECLARE
        v_component_count integer;
        v_motor_count integer;
        v_tube_count integer;
        v_bracket_count integer;
    BEGIN
        SELECT COUNT(*) INTO v_component_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_id
            AND deleted = false
            AND source = 'configured_component';
        
        SELECT COUNT(*) INTO v_motor_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_id
            AND deleted = false
            AND source = 'configured_component'
            AND component_role = 'motor';
        
        SELECT COUNT(*) INTO v_tube_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_id
            AND deleted = false
            AND source = 'configured_component'
            AND component_role = 'tube';
        
        SELECT COUNT(*) INTO v_bracket_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_id
            AND deleted = false
            AND source = 'configured_component'
            AND component_role = 'bracket';
        
        RAISE NOTICE '';
        RAISE NOTICE '📊 Components in database:';
        RAISE NOTICE '  Total: %', v_component_count;
        RAISE NOTICE '  Motor: %', v_motor_count;
        RAISE NOTICE '  Tube: %', v_tube_count;
        RAISE NOTICE '  Bracket: %', v_bracket_count;
    END;
    
END $$;

-- ====================================================
-- STEP 4: Show components created
-- ====================================================

SELECT 
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom,
    qlc.created_at
FROM "QuoteLineComponents" qlc
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = (
    SELECT id FROM "QuoteLines"
    WHERE deleted = false
        AND drive_type = 'motor'
        AND product_type_id IS NOT NULL
        AND organization_id IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days'
    ORDER BY created_at DESC
    LIMIT 1
)
AND qlc.deleted = false
AND qlc.source = 'configured_component'
ORDER BY qlc.component_role;



