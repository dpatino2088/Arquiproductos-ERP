-- ====================================================
-- Migration 240: Manual Test of BOM Generation
-- ====================================================
-- Test generate_configured_bom_for_quote_line with a specific QuoteLine
-- ====================================================

-- ====================================================
-- STEP 1: Get QuoteLine details for testing
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    ql.bottom_rail_type,
    ql.cassette,
    ql.cassette_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty,
    -- Check if backfill is needed
    CASE 
        WHEN ql.tube_type IS NULL AND ql.width_m IS NOT NULL THEN '⚠️ Needs tube_type backfill'
        WHEN ql.operating_system_variant IS NULL AND ql.drive_type IS NOT NULL THEN '⚠️ Needs os_variant backfill'
        ELSE '✅ Ready'
    END as status
FROM "QuoteLines" ql
WHERE ql.deleted = false
    AND ql.drive_type = 'motor'
    AND ql.product_type_id IS NOT NULL
    AND ql.organization_id IS NOT NULL
    AND ql.created_at > NOW() - INTERVAL '30 days'
ORDER BY ql.created_at DESC
LIMIT 1;

-- ====================================================
-- STEP 2: First, ensure backfill is applied
-- ====================================================
-- Update tube_type and operating_system_variant if NULL
-- ====================================================

DO $$
DECLARE
    v_quote_line_id uuid;
    v_updated_count integer;
BEGIN
    -- Get a QuoteLine with motor drive_type
    SELECT id INTO v_quote_line_id
    FROM "QuoteLines"
    WHERE deleted = false
        AND drive_type = 'motor'
        AND product_type_id IS NOT NULL
        AND organization_id IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days'
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_quote_line_id IS NOT NULL THEN
        -- Backfill tube_type if NULL
        UPDATE "QuoteLines"
        SET tube_type = CASE
            WHEN width_m IS NOT NULL AND width_m < 0.042 THEN 'RTU-42'
            WHEN width_m IS NOT NULL AND width_m < 0.065 THEN 'RTU-65'
            WHEN width_m IS NOT NULL THEN 'RTU-80'
            ELSE NULL
        END,
        operating_system_variant = COALESCE(operating_system_variant, 'standard_m'),
        updated_at = now()
        WHERE id = v_quote_line_id
            AND (tube_type IS NULL OR operating_system_variant IS NULL);
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        IF v_updated_count > 0 THEN
            RAISE NOTICE '✅ Backfilled configuration fields for QuoteLine %', v_quote_line_id;
        ELSE
            RAISE NOTICE 'ℹ️ QuoteLine % already has configuration fields', v_quote_line_id;
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 3: Test BOM generation for the QuoteLine
-- ====================================================
-- This will show the result of generate_configured_bom_for_quote_line
-- ====================================================

DO $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_result jsonb;
    v_quote_line_id uuid;
BEGIN
    -- Get QuoteLine with all fields
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
            -- PRIMARY: Infer from operating_system_variant
            CASE
                WHEN ql.operating_system_variant ILIKE '%standard_m%' OR ql.operating_system_variant ILIKE '%m%' THEN 'RTU-42'
                WHEN ql.operating_system_variant ILIKE '%standard_l%' OR ql.operating_system_variant ILIKE '%l%' THEN 'RTU-65'
                ELSE NULL
            END,
            -- FALLBACK: Infer from width_m
            CASE
                WHEN ql.width_m IS NOT NULL AND ql.width_m < 0.042 THEN 'RTU-42'
                WHEN ql.width_m IS NOT NULL AND ql.width_m < 0.065 THEN 'RTU-65'
                WHEN ql.width_m IS NOT NULL THEN 'RTU-80'
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
        RAISE NOTICE '❌ No QuoteLine found for testing';
        RETURN;
    END IF;
    
    v_quote_line_id := v_quote_line_record.id;
    
    RAISE NOTICE '🧪 Testing BOM generation for QuoteLine: %', v_quote_line_id;
    RAISE NOTICE '  Configuration: drive_type=%, tube_type=%, operating_system_variant=%', 
        v_quote_line_record.drive_type, 
        v_quote_line_record.tube_type, 
        v_quote_line_record.operating_system_variant;
    
    -- Call the function
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
        
        RAISE NOTICE '✅ Function executed successfully';
        RAISE NOTICE '  Success: %', v_bom_result->>'success';
        RAISE NOTICE '  Components created: %', jsonb_array_length(v_bom_result->'components');
        RAISE NOTICE '  Required roles: %', v_bom_result->'required_roles';
        RAISE NOTICE '  Missing roles: %', v_bom_result->'missing_roles';
        RAISE NOTICE '  Resolution errors: %', v_bom_result->'resolution_errors';
        
        -- Check if motor components were created
        IF v_bom_result->'components' IS NOT NULL THEN
            DECLARE
                v_component jsonb;
                v_has_motor boolean := false;
                v_has_motor_adapter boolean := false;
            BEGIN
                FOR v_component IN SELECT * FROM jsonb_array_elements(v_bom_result->'components')
                LOOP
                    IF v_component->>'component_role' = 'motor' THEN
                        v_has_motor := true;
                        RAISE NOTICE '  ✅ Motor component created: SKU=%', v_component->>'sku';
                    END IF;
                    IF v_component->>'component_role' = 'motor_adapter' THEN
                        v_has_motor_adapter := true;
                        RAISE NOTICE '  ✅ Motor adapter component created: SKU=%', v_component->>'sku';
                    END IF;
                END LOOP;
                
                IF NOT v_has_motor THEN
                    RAISE WARNING '⚠️ Motor component was NOT created';
                END IF;
                IF NOT v_has_motor_adapter THEN
                    RAISE WARNING '⚠️ Motor adapter component was NOT created';
                END IF;
            END;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error calling generate_configured_bom_for_quote_line: %', SQLERRM;
            RAISE WARNING '  SQLSTATE: %', SQLSTATE;
    END;
    
    -- Check what components were actually created in the database
    RAISE NOTICE '';
    RAISE NOTICE '📊 Components in database for QuoteLine %:', v_quote_line_id;
    
    DECLARE
        v_component_count integer;
        v_motor_count integer;
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
        
        RAISE NOTICE '  Total configured components: %', v_component_count;
        RAISE NOTICE '  Motor components: %', v_motor_count;
        
        IF v_motor_count = 0 AND v_quote_line_record.drive_type = 'motor' THEN
            RAISE WARNING '❌ CRITICAL: Motor components missing despite drive_type=motor';
        END IF;
    END;
    
END $$;

-- ====================================================
-- STEP 4: Show all components created for the test QuoteLine
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

