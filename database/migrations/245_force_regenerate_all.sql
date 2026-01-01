-- ====================================================
-- Migration 245: Force Regenerate All QuoteLineComponents
-- ====================================================
-- Force regeneration of all QuoteLineComponents with detailed logging
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Delete ALL existing configured components
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
                AND organization_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ Deleted % existing configured QuoteLineComponents', v_deleted_count;
END $$;

-- ====================================================
-- STEP 2: Regenerate for each QuoteLine with detailed logging
-- ====================================================

DO $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_result jsonb;
    v_success_count integer := 0;
    v_error_count integer := 0;
    v_total_count integer := 0;
    v_motor_created_count integer := 0;
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
        FROM "QuoteLines" ql
        WHERE ql.deleted = false
            AND ql.product_type_id IS NOT NULL
            AND ql.organization_id IS NOT NULL
            AND ql.created_at > NOW() - INTERVAL '30 days'
        ORDER BY ql.created_at DESC
    LOOP
        v_total_count := v_total_count + 1;
        
        BEGIN
            RAISE NOTICE '🔄 Processing QuoteLine % (%/%): drive_type=%, tube_type=%, os_variant=%', 
                v_quote_line_record.id, 
                v_total_count,
                (SELECT COUNT(*) FROM "QuoteLines" WHERE deleted = false AND product_type_id IS NOT NULL AND created_at > NOW() - INTERVAL '30 days'),
                v_quote_line_record.drive_type,
                v_quote_line_record.tube_type,
                v_quote_line_record.operating_system_variant;
            
            -- Call generate_configured_bom_for_quote_line
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
            
            IF (v_bom_result->>'success')::boolean = true THEN
                v_success_count := v_success_count + 1;
                DECLARE
                    v_component_count integer;
                    v_motor_count integer;
                BEGIN
                    SELECT COUNT(*) INTO v_component_count
                    FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_quote_line_record.id
                        AND deleted = false
                        AND source = 'configured_component';
                    
                    SELECT COUNT(*) INTO v_motor_count
                    FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_quote_line_record.id
                        AND deleted = false
                        AND source = 'configured_component'
                        AND component_role = 'motor';
                    
                    IF v_motor_count > 0 AND v_quote_line_record.drive_type = 'motor' THEN
                        v_motor_created_count := v_motor_created_count + 1;
                    END IF;
                    
                    RAISE NOTICE '  ✅ Success: % components created (motor: %)', 
                        v_component_count, 
                        v_motor_count;
                    
                    -- Show missing roles if any
                    IF v_bom_result->'missing_roles' IS NOT NULL AND jsonb_array_length(v_bom_result->'missing_roles') > 0 THEN
                        RAISE WARNING '  ⚠️ Missing roles: %', v_bom_result->'missing_roles';
                    END IF;
                    
                    -- Show resolution errors if any
                    IF v_bom_result->'resolution_errors' IS NOT NULL AND jsonb_array_length(v_bom_result->'resolution_errors') > 0 THEN
                        RAISE WARNING '  ⚠️ Resolution errors: %', v_bom_result->'resolution_errors';
                    END IF;
                END;
            ELSE
                v_error_count := v_error_count + 1;
                RAISE WARNING '  ❌ Failed: %', v_bom_result->>'message';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING '  ❌ Exception for QuoteLine %: % (SQLSTATE: %)', 
                    v_quote_line_record.id, 
                    SQLERRM, 
                    SQLSTATE;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Regeneration Summary:';
    RAISE NOTICE '  Total QuoteLines processed: %', v_total_count;
    RAISE NOTICE '  Successful: %', v_success_count;
    RAISE NOTICE '  Errors: %', v_error_count;
    RAISE NOTICE '  Motor components created for motor drive_types: %', v_motor_created_count;
END $$;

-- ====================================================
-- STEP 3: Verify final results
-- ====================================================

DO $$
DECLARE
    v_total_quote_lines integer;
    v_with_components integer;
    v_total_components integer;
    v_motor_components integer;
    v_tube_components integer;
    v_bracket_components integer;
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
    
    SELECT COUNT(*) INTO v_total_components
    FROM "QuoteLineComponents"
    WHERE deleted = false
        AND source = 'configured_component'
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    SELECT COUNT(*) INTO v_motor_components
    FROM "QuoteLineComponents"
    WHERE deleted = false
        AND source = 'configured_component'
        AND component_role = 'motor'
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    SELECT COUNT(*) INTO v_tube_components
    FROM "QuoteLineComponents"
    WHERE deleted = false
        AND source = 'configured_component'
        AND component_role = 'tube'
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    SELECT COUNT(*) INTO v_bracket_components
    FROM "QuoteLineComponents"
    WHERE deleted = false
        AND source = 'configured_component'
        AND component_role = 'bracket'
        AND quote_line_id IN (
            SELECT id FROM "QuoteLines"
            WHERE deleted = false
                AND product_type_id IS NOT NULL
                AND created_at > NOW() - INTERVAL '30 days'
        );
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Final Verification:';
    RAISE NOTICE '  Total QuoteLines: %', v_total_quote_lines;
    RAISE NOTICE '  QuoteLines with components: %', v_with_components;
    RAISE NOTICE '  Total components: %', v_total_components;
    RAISE NOTICE '  Motor components: %', v_motor_components;
    RAISE NOTICE '  Tube components: %', v_tube_components;
    RAISE NOTICE '  Bracket components: %', v_bracket_components;
    RAISE NOTICE '  Average components per QuoteLine: %', 
        CASE WHEN v_with_components > 0 THEN ROUND(v_total_components::numeric / v_with_components, 2) ELSE 0 END;
END $$;

COMMIT;

