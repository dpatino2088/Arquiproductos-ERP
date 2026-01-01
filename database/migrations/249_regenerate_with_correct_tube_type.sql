-- ====================================================
-- Migration 249: Regenerate QuoteLineComponents with Correct Tube Type
-- ====================================================
-- Regenerates QuoteLineComponents after fixing tube_type logic
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Delete existing configured components
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
-- STEP 2: Regenerate for each QuoteLine
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
            -- ⭐ FIXED: Use operating_system_variant as primary source for tube_type
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
                
                -- Check if motor components were created
                DECLARE
                    v_motor_count integer;
                BEGIN
                    SELECT COUNT(*) INTO v_motor_count
                    FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_quote_line_record.id
                        AND deleted = false
                        AND source = 'configured_component'
                        AND component_role = 'motor';
                    
                    IF v_motor_count > 0 AND v_quote_line_record.drive_type = 'motor' THEN
                        v_motor_created_count := v_motor_created_count + 1;
                    END IF;
                END;
            ELSE
                v_error_count := v_error_count + 1;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Regeneration Summary:';
    RAISE NOTICE '  Total QuoteLines processed: %', v_total_count;
    RAISE NOTICE '  Successful: %', v_success_count;
    RAISE NOTICE '  Errors: %', v_error_count;
    RAISE NOTICE '  Motor components created: %', v_motor_created_count;
END $$;

-- ====================================================
-- STEP 3: Final verification
-- ====================================================

SELECT 
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') as with_motor_drive,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') as motor_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor_adapter') as motor_adapter_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'tube') as tube_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'bracket') as bracket_components,
    CASE 
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') = 0 
        THEN '❌ CRITICAL: Motor components missing'
        WHEN COUNT(DISTINCT ql.id) FILTER (WHERE ql.drive_type = 'motor') > 0 
            AND COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'motor') > 0 
        THEN '✅ OK: Motor components created'
        ELSE 'ℹ️ INFO: No motor drive types'
    END as status
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';

COMMIT;



