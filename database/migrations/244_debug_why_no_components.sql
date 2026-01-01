-- ====================================================
-- Migration 244: Debug Why Components Are Not Created
-- ====================================================
-- Investigate why QuoteLineComponents are not being created
-- ====================================================

-- ====================================================
-- DEBUG 1: Check QuoteLineComponents status
-- ====================================================

SELECT 
    qlc.source,
    qlc.deleted,
    COUNT(*) as count,
    COUNT(*) FILTER (WHERE qlc.component_role = 'motor') as motor_count,
    COUNT(*) FILTER (WHERE qlc.component_role = 'tube') as tube_count,
    COUNT(*) FILTER (WHERE qlc.component_role = 'bracket') as bracket_count
FROM "QuoteLineComponents" qlc
WHERE qlc.quote_line_id IN (
    SELECT id FROM "QuoteLines" 
    WHERE deleted = false 
    AND created_at > NOW() - INTERVAL '30 days'
)
GROUP BY qlc.source, qlc.deleted
ORDER BY qlc.source, qlc.deleted;

-- ====================================================
-- DEBUG 2: Check if QuoteLines have product_type_id
-- ====================================================

SELECT 
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE product_type_id IS NOT NULL) as with_product_type_id,
    COUNT(*) FILTER (WHERE product_type_id IS NULL) as without_product_type_id,
    COUNT(*) FILTER (WHERE organization_id IS NOT NULL) as with_organization_id,
    COUNT(*) FILTER (WHERE organization_id IS NULL) as without_organization_id
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- DEBUG 3: Check QuoteLines that should have components
-- ====================================================

SELECT 
    ql.id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.tube_type,
    ql.operating_system_variant,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as configured_components,
    COUNT(qlc.id) FILTER (WHERE qlc.deleted = false) as total_components
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days'
    AND ql.drive_type = 'motor'
GROUP BY ql.id, ql.product_type_id, ql.organization_id, ql.drive_type, ql.tube_type, ql.operating_system_variant
ORDER BY ql.created_at DESC
LIMIT 5;

-- ====================================================
-- DEBUG 4: Test generate_configured_bom_for_quote_line manually
-- ====================================================
-- Get a QuoteLine ID to test
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
    ql.qty
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
-- DEBUG 5: Check BOMTemplate exists
-- ====================================================

SELECT 
    bt.id,
    bt.name,
    bt.product_type_id,
    bt.organization_id,
    bt.active,
    COUNT(bc.id) as component_count
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.deleted = false
    AND bt.product_type_id IN (
        SELECT DISTINCT product_type_id 
        FROM "QuoteLines" 
        WHERE deleted = false 
        AND created_at > NOW() - INTERVAL '30 days'
        AND product_type_id IS NOT NULL
    )
GROUP BY bt.id, bt.name, bt.product_type_id, bt.organization_id, bt.active
ORDER BY bt.created_at DESC;

-- ====================================================
-- DEBUG 6: Force regenerate one QuoteLine
-- ====================================================
-- This will manually call the function for one QuoteLine
-- ====================================================

DO $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_result jsonb;
    v_quote_line_id uuid;
BEGIN
    -- Get a QuoteLine with motor drive_type
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
    
    -- Delete existing components first
    UPDATE "QuoteLineComponents"
    SET deleted = true, updated_at = now()
    WHERE quote_line_id = v_quote_line_id
        AND source = 'configured_component'
        AND deleted = false;
    
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
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error calling generate_configured_bom_for_quote_line: %', SQLERRM;
            RAISE WARNING '  SQLSTATE: %', SQLSTATE;
    END;
    
    -- Check what was created
    RAISE NOTICE '';
    RAISE NOTICE '📊 Components created for QuoteLine %:', v_quote_line_id;
    
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
    END;
    
END $$;

-- ====================================================
-- DEBUG 7: Show components created by the test
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

