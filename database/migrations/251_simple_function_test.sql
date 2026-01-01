-- ====================================================
-- Migration 251: Simple Function Test
-- ====================================================
-- Simple test to call the function and see what happens
-- ====================================================

-- ====================================================
-- Test: Call function for the QuoteLine shown
-- ====================================================

DO $$
DECLARE
    v_result jsonb;
    v_quote_line_id uuid := 'b634562f-c1a7-4a3a-9b1e-01428f79eda4'::uuid;
BEGIN
    -- Delete existing components first
    UPDATE "QuoteLineComponents"
    SET deleted = true, updated_at = now()
    WHERE quote_line_id = v_quote_line_id
        AND source = 'configured_component'
        AND deleted = false;
    
    RAISE NOTICE '✅ Deleted existing components';
    
    -- Call the function
    SELECT public.generate_configured_bom_for_quote_line(
        v_quote_line_id,
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid,  -- organization_id
        'motor',                                        -- drive_type
        'standard',                                     -- bottom_rail_type
        false,                                          -- cassette
        NULL,                                           -- cassette_type
        false,                                          -- side_channel
        NULL,                                           -- side_channel_type
        'white',                                        -- hardware_color
        1.000,                                          -- width_m
        1.000,                                          -- height_m
        1,                                              -- qty
        'RTU-42',                                       -- tube_type
        'standard_m'                                    -- operating_system_variant
    ) INTO v_result;
    
    RAISE NOTICE 'Function result: %', v_result;
    RAISE NOTICE 'Success: %', v_result->>'success';
    RAISE NOTICE 'Components: %', jsonb_array_length(v_result->'components');
    RAISE NOTICE 'Required roles: %', v_result->'required_roles';
    RAISE NOTICE 'Missing roles: %', v_result->'missing_roles';
    
END $$;

-- ====================================================
-- Check what components were created
-- ====================================================

SELECT 
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLineComponents" qlc
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = 'b634562f-c1a7-4a3a-9b1e-01428f79eda4'::uuid
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
ORDER BY qlc.component_role;



