-- ====================================================
-- Test Resolver con Parámetros Correctos
-- ====================================================

-- Test 1: Resolver tube para standard_m + RTU-42
SELECT 
    'Test 1: tube (RTU-42, standard_m, white)' as test_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id (Roller Shade)
        'tube',                                         -- component_role
        'standard_m',                                    -- operating_system_variant
        'RTU-42',                                       -- tube_type
        NULL,                                           -- bottom_rail_type
        NULL,                                           -- side_channel_type
        'white',                                        -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

-- Test 2: Resolver tube para standard_l + RTU-65
SELECT 
    'Test 2: tube (RTU-65, standard_l, white)' as test_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        'tube',                                         -- component_role
        'standard_l',                                    -- operating_system_variant
        'RTU-65',                                       -- tube_type
        NULL,                                           -- bottom_rail_type
        NULL,                                           -- side_channel_type
        'white',                                        -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

-- Test 3: Resolver bracket
SELECT 
    'Test 3: bracket (RTU-42, standard_m, white)' as test_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        'bracket',                                      -- component_role
        'standard_m',                                    -- operating_system_variant
        'RTU-42',                                       -- tube_type
        NULL,                                           -- bottom_rail_type
        NULL,                                           -- side_channel_type
        'white',                                        -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

-- Test 4: Resolver motor_adapter
SELECT 
    'Test 4: motor_adapter' as test_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        'motor_adapter',                                -- component_role
        'standard_m',                                    -- operating_system_variant
        'RTU-42',                                       -- tube_type
        NULL,                                           -- bottom_rail_type
        NULL,                                           -- side_channel_type
        'white',                                        -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

-- Test 5: Resolver bottom_rail_profile
SELECT 
    'Test 5: bottom_rail_profile' as test_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        'bottom_rail_profile',                          -- component_role
        NULL,                                           -- operating_system_variant
        NULL,                                           -- tube_type
        'standard',                                     -- bottom_rail_type
        NULL,                                           -- side_channel_type
        NULL,                                           -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

-- Test 6: Ver SKUs resueltos
SELECT 
    'Test 6: Ver SKUs resueltos' as test_name,
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


