-- ====================================================
-- Migration 273: Seed BomRoleSkuMapping and Verification Queries
-- ====================================================
-- Seeds mapping data and provides verification queries
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Get Roller Shade product_type_id
-- ====================================================

DO $$
DECLARE
    v_roller_shade_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
    v_catalog_item_id uuid;
BEGIN
    -- Find Roller Shade product type
    SELECT id INTO v_roller_shade_product_type_id
    FROM "ProductTypes"
    WHERE code = 'ROLLER' OR name ILIKE '%roller%shade%'
    AND deleted = false
    LIMIT 1;
    
    IF v_roller_shade_product_type_id IS NULL THEN
        RAISE EXCEPTION 'Roller Shade product type not found';
    END IF;
    
    RAISE NOTICE '✅ Found Roller Shade product_type_id: %', v_roller_shade_product_type_id;
    
    -- ====================================================
    -- STEP 2: Seed tube mappings
    -- ====================================================
    
    -- RTU-42 tube
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%RTU-42%' OR ci.item_name ILIKE '%RTU-42%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            tube_type,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'tube',
            'RTU-42',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded tube RTU-42 mapping';
    END IF;
    
    -- RTU-65 tube
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%RTU-65%' OR ci.item_name ILIKE '%RTU-65%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            tube_type,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'tube',
            'RTU-65',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded tube RTU-65 mapping';
    END IF;
    
    -- RTU-80 tube
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%RTU-80%' OR ci.item_name ILIKE '%RTU-80%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            tube_type,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'tube',
            'RTU-80',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded tube RTU-80 mapping';
    END IF;
    
    -- ====================================================
    -- STEP 3: Seed bracket mappings (with hardware_color)
    -- ====================================================
    
    -- Bracket for RTU-42, white
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%BRACKET%42%' OR ci.item_name ILIKE '%BRACKET%42%')
        AND (ci.sku ILIKE '%WHITE%' OR ci.sku ILIKE '%W%' OR ci.item_name ILIKE '%WHITE%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            tube_type,
            hardware_color,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'bracket',
            'RTU-42',
            'white',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded bracket RTU-42 white mapping';
    END IF;
    
    -- Generic bracket (wildcard for tube_type and color)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%BRACKET%' OR ci.item_name ILIKE '%BRACKET%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'bracket',
            v_catalog_item_id,
            100  -- Lower priority than specific mappings
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded generic bracket mapping (fallback)';
    END IF;
    
    -- ====================================================
    -- STEP 4: Seed operating_system_drive mappings
    -- ====================================================
    
    -- Drive for standard_m
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%DRIVE%' OR ci.item_name ILIKE '%DRIVE%' OR ci.item_name ILIKE '%BELT%')
        AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%TOOL%' OR ci.item_name ILIKE '%TOOL%')
    ORDER BY 
        CASE WHEN ci.item_name ILIKE '%DRIVE%PLUG%' THEN 0 ELSE 1 END,
        ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            operating_system_variant,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'operating_system_drive',
            'standard_m',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded operating_system_drive standard_m mapping';
    END IF;
    
    -- ====================================================
    -- STEP 5: Seed motor mappings
    -- ====================================================
    
    -- Motor for standard_m
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%MOTOR%' OR ci.item_name ILIKE '%MOTOR%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            operating_system_variant,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'motor',
            'standard_m',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded motor standard_m mapping';
    END IF;
    
    -- ====================================================
    -- STEP 6: Seed motor_adapter mappings
    -- ====================================================
    
    -- Motor adapter (Bracket adapter motor - RC3162-BK)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' OR ci.sku ILIKE '%RC3162%')
    ORDER BY 
        CASE WHEN ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' THEN 0 ELSE 1 END,
        ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'motor_adapter',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded motor_adapter mapping';
    END IF;
    
    -- ====================================================
    -- STEP 7: Seed fabric mappings (exclude DRF/Dual Shade)
    -- ====================================================
    
    -- Fabric for Roller Shade (exclude DRF-prefixed)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%FABRIC%' OR ci.item_name ILIKE '%FABRIC%')
        AND NOT (ci.sku ILIKE 'DRF%' OR ci.item_name ILIKE '%DUAL%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'fabric',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded fabric mapping (Roller Shade only)';
    END IF;
    
    -- ====================================================
    -- STEP 8: Seed bottom_rail_profile mappings
    -- ====================================================
    
    -- Bottom rail profile
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%BOTTOM%RAIL%' OR ci.item_name ILIKE '%BOTTOM%RAIL%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'bottom_rail_profile',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded bottom_rail_profile mapping';
    END IF;
    
    -- ====================================================
    -- STEP 9: Seed bottom_rail_end_cap mappings
    -- ====================================================
    
    -- Bottom rail end cap
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND (ci.sku ILIKE '%END%CAP%' OR ci.item_name ILIKE '%END%CAP%' OR ci.sku ILIKE '%CAP%' OR ci.item_name ILIKE '%CAP%')
        AND (ci.sku ILIKE '%BOTTOM%RAIL%' OR ci.item_name ILIKE '%BOTTOM%RAIL%' OR ci.sku ILIKE '%RAIL%' OR ci.item_name ILIKE '%RAIL%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    IF v_catalog_item_id IS NOT NULL THEN
        INSERT INTO "BomRoleSkuMapping" (
            organization_id,
            product_type_id,
            component_role,
            catalog_item_id,
            priority
        )
        VALUES (
            v_organization_id,
            v_roller_shade_product_type_id,
            'bottom_rail_end_cap',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✅ Seeded bottom_rail_end_cap mapping';
    END IF;
    
    RAISE NOTICE '✅ Completed seeding BomRoleSkuMapping';
    
END $$;

-- ====================================================
-- STEP 10: Seed MotorTubeCompatibility
-- ====================================================

DO $$
DECLARE
    v_roller_shade_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
BEGIN
    -- Find Roller Shade product type
    SELECT id INTO v_roller_shade_product_type_id
    FROM "ProductTypes"
    WHERE code = 'ROLLER' OR name ILIKE '%roller%shade%'
    AND deleted = false
    LIMIT 1;
    
    IF v_roller_shade_product_type_id IS NULL THEN
        RAISE EXCEPTION 'Roller Shade product type not found';
    END IF;
    
    -- Insert compatibility rules
    -- IMPORTANT: 
    -- - standard_m DEFAULT tube_type = RTU-42 (required compatibility)
    -- - standard_l DEFAULT tube_type = RTU-65 (required compatibility)
    -- - RTU-80 is NOT the default for standard_l, it's only optional if capacity allows
    -- - standard_l may also use RTU-42/RTU-50 if capacity supports (do not block smaller tubes)
    -- NOTE: motor_family is a legacy column, we map standard_m -> 'CM-09', standard_l -> 'CM-10'
    INSERT INTO "MotorTubeCompatibility" (
        organization_id,
        product_type_id,
        operating_system_variant,
        tube_type,
        motor_family,  -- Legacy column required by existing schema
        max_width_mm,
        max_drop_mm,
        max_area_m2
    )
    VALUES
        -- Standard M with RTU-42 (DEFAULT - required)
        (v_organization_id, v_roller_shade_product_type_id, 'standard_m', 'RTU-42', 'CM-09', 3000, 3000, 9.0),
        -- Standard M with RTU-50 (optional, if capacity allows)
        (v_organization_id, v_roller_shade_product_type_id, 'standard_m', 'RTU-50', 'CM-09', 3500, 3500, 12.0),
        -- Standard L with RTU-42 (optional, smaller tube allowed if capacity supports)
        (v_organization_id, v_roller_shade_product_type_id, 'standard_l', 'RTU-42', 'CM-10', 3000, 3000, 9.0),
        -- Standard L with RTU-50 (optional, smaller tube allowed if capacity supports)
        (v_organization_id, v_roller_shade_product_type_id, 'standard_l', 'RTU-50', 'CM-10', 3500, 3500, 12.0),
        -- Standard L with RTU-65 (DEFAULT - required)
        (v_organization_id, v_roller_shade_product_type_id, 'standard_l', 'RTU-65', 'CM-10', 4000, 4000, 16.0),
        -- Standard L with RTU-80 (OPTIONAL - only if capacity allows, NOT the default)
        (v_organization_id, v_roller_shade_product_type_id, 'standard_l', 'RTU-80', 'CM-10', 5000, 5000, 25.0)
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE '✅ Seeded MotorTubeCompatibility rules';
END $$;

COMMIT;

-- ====================================================
-- VERIFICATION QUERIES
-- ====================================================

-- Verification 1: Show all mappings created
SELECT 
    'Verification 1: BomRoleSkuMapping entries' as check_name,
    m.component_role,
    m.operating_system_variant,
    m.tube_type,
    m.hardware_color,
    ci.sku,
    ci.item_name,
    m.priority
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
ORDER BY m.component_role, m.priority, m.operating_system_variant, m.tube_type;

-- Verification 2: Show compatibility rules
SELECT 
    'Verification 2: MotorTubeCompatibility rules' as check_name,
    pt.name as product_type_name,
    mtc.operating_system_variant,
    mtc.tube_type,
    mtc.max_width_mm,
    mtc.max_drop_mm,
    mtc.max_area_m2
FROM "MotorTubeCompatibility" mtc
JOIN "ProductTypes" pt ON pt.id = mtc.product_type_id
WHERE mtc.deleted = false
    AND mtc.active = true
ORDER BY pt.name, mtc.operating_system_variant, mtc.tube_type;

-- Verification 3: Test resolver for specific configurations
SELECT 
    'Verification 3: Resolver test - tube RTU-42' as check_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        'tube',                                          -- role
        'standard_m',                                    -- operating_system_variant
        'RTU-42',                                        -- tube_type
        NULL,                                            -- bottom_rail_type
        NULL,                                            -- side_channel_type
        'white',                                         -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

-- Verification 4: Test resolver for motor_adapter
SELECT 
    'Verification 4: Resolver test - motor_adapter' as check_name,
    public.resolve_bom_role_to_catalog_item_id(
        '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid,  -- product_type_id
        'motor_adapter',                                 -- role
        'standard_m',                                    -- operating_system_variant
        'RTU-42',                                        -- tube_type
        NULL,                                            -- bottom_rail_type
        NULL,                                            -- side_channel_type
        'white',                                         -- hardware_color
        '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid   -- organization_id
    ) as resolved_catalog_item_id;

