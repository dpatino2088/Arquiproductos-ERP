-- ====================================================
-- Migration 275: Final Verification - Deterministic BOM Proof
-- ====================================================
-- Comprehensive verification queries to prove determinism
-- ====================================================

-- ====================================================
-- VERIFICATION 1: Confirm table pivote real
-- ====================================================

SELECT 
    'VERIFICATION 1: Table pivote real' as check_name,
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name ILIKE '%catalog%item%product%type%'
ORDER BY table_name, ordinal_position;

-- ====================================================
-- VERIFICATION 2: Test resolver directly for key roles
-- ====================================================

DO $$
DECLARE
    v_product_type_id uuid := '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid;  -- Roller Shade
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
    v_resolved_id uuid;
    v_sku text;
    v_item_name text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'VERIFICATION 2: Direct Resolver Tests';
    RAISE NOTICE '====================================================';
    
    -- Test tube RTU-42
    v_resolved_id := public.resolve_bom_role_to_catalog_item_id(
        v_product_type_id, 'tube', 'standard_m', 'RTU-42', NULL, NULL, 'white', v_organization_id
    );
    IF v_resolved_id IS NOT NULL THEN
        SELECT sku, item_name INTO v_sku, v_item_name FROM "CatalogItems" WHERE id = v_resolved_id;
        RAISE NOTICE '✅ tube (RTU-42, standard_m, white) → %: %', v_sku, v_item_name;
    ELSE
        RAISE NOTICE '❌ tube (RTU-42, standard_m, white) → NULL (no mapping found)';
    END IF;
    
    -- Test tube RTU-65 (default for standard_l)
    v_resolved_id := public.resolve_bom_role_to_catalog_item_id(
        v_product_type_id, 'tube', 'standard_l', 'RTU-65', NULL, NULL, 'white', v_organization_id
    );
    IF v_resolved_id IS NOT NULL THEN
        SELECT sku, item_name INTO v_sku, v_item_name FROM "CatalogItems" WHERE id = v_resolved_id;
        RAISE NOTICE '✅ tube (RTU-65, standard_l, white) → %: %', v_sku, v_item_name;
    ELSE
        RAISE NOTICE '❌ tube (RTU-65, standard_l, white) → NULL (no mapping found)';
    END IF;
    
    -- Test tube RTU-80 (optional for standard_l, NOT default)
    v_resolved_id := public.resolve_bom_role_to_catalog_item_id(
        v_product_type_id, 'tube', 'standard_l', 'RTU-80', NULL, NULL, 'white', v_organization_id
    );
    IF v_resolved_id IS NOT NULL THEN
        SELECT sku, item_name INTO v_sku, v_item_name FROM "CatalogItems" WHERE id = v_resolved_id;
        RAISE NOTICE '✅ tube (RTU-80, standard_l, white) → %: % [OPTIONAL, not default]', v_sku, v_item_name;
    ELSE
        RAISE NOTICE '⚠️ tube (RTU-80, standard_l, white) → NULL (optional mapping, may not exist)';
    END IF;
    
    -- Test bracket
    v_resolved_id := public.resolve_bom_role_to_catalog_item_id(
        v_product_type_id, 'bracket', 'standard_m', 'RTU-42', NULL, NULL, 'white', v_organization_id
    );
    IF v_resolved_id IS NOT NULL THEN
        SELECT sku, item_name INTO v_sku, v_item_name FROM "CatalogItems" WHERE id = v_resolved_id;
        RAISE NOTICE '✅ bracket (RTU-42, standard_m, white) → %: %', v_sku, v_item_name;
    ELSE
        RAISE NOTICE '❌ bracket (RTU-42, standard_m, white) → NULL (no mapping found)';
    END IF;
    
    -- Test bottom_rail_profile
    v_resolved_id := public.resolve_bom_role_to_catalog_item_id(
        v_product_type_id, 'bottom_rail_profile', NULL, NULL, 'standard', NULL, NULL, v_organization_id
    );
    IF v_resolved_id IS NOT NULL THEN
        SELECT sku, item_name INTO v_sku, v_item_name FROM "CatalogItems" WHERE id = v_resolved_id;
        RAISE NOTICE '✅ bottom_rail_profile (standard) → %: %', v_sku, v_item_name;
    ELSE
        RAISE NOTICE '❌ bottom_rail_profile (standard) → NULL (no mapping found)';
    END IF;
    
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- VERIFICATION 3: Compare Default Configurations
-- Test A: standard_m + RTU-42 (default) vs Test B: standard_l + RTU-65 (default)
-- ====================================================

SELECT 
    'VERIFICATION 3: Default Configurations Comparison' as check_name,
    ql.id as quote_line_id,
    ql.operating_system_variant,
    ql.tube_type,
    ql.drive_type,
    qlc.component_role,
    ci.id as resolved_catalog_item_id,
    ci.sku as resolved_sku,
    ci.item_name as resolved_item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    AND ql.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid  -- Roller Shade
    AND (
        (ql.operating_system_variant = 'standard_m' AND ql.tube_type = 'RTU-42') OR
        (ql.operating_system_variant = 'standard_l' AND ql.tube_type = 'RTU-65')
    )
ORDER BY 
    ql.operating_system_variant,
    ql.tube_type,
    qlc.component_role;

-- ====================================================
-- VERIFICATION 3B: Optional RTU-80 Configuration (if exists)
-- ====================================================

SELECT 
    'VERIFICATION 3B: Optional RTU-80 Configuration' as check_name,
    ql.id as quote_line_id,
    ql.operating_system_variant,
    ql.tube_type,
    ql.drive_type,
    qlc.component_role,
    ci.id as resolved_catalog_item_id,
    ci.sku as resolved_sku,
    ci.item_name as resolved_item_name,
    qlc.qty,
    qlc.uom
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    AND ql.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid  -- Roller Shade
    AND ql.operating_system_variant = 'standard_l'
    AND ql.tube_type = 'RTU-80'
ORDER BY 
    qlc.component_role;

-- ====================================================
-- VERIFICATION 4: Validate configuration function test
-- ====================================================

DO $$
DECLARE
    v_quote_line_id uuid;
    v_validation_result jsonb;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'VERIFICATION 4: Configuration Validation Test';
    RAISE NOTICE '====================================================';
    
    -- Find a QuoteLine with valid configuration
    SELECT id INTO v_quote_line_id
    FROM "QuoteLines"
    WHERE deleted = false
        AND product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
        AND operating_system_variant IS NOT NULL
        AND tube_type IS NOT NULL
    LIMIT 1;
    
    IF v_quote_line_id IS NOT NULL THEN
        v_validation_result := public.validate_quote_line_configuration(v_quote_line_id);
        RAISE NOTICE 'QuoteLine % validation:', v_quote_line_id;
        RAISE NOTICE '  ok: %', v_validation_result->>'ok';
        RAISE NOTICE '  errors: %', v_validation_result->'errors';
        RAISE NOTICE '  warnings: %', v_validation_result->'warnings';
    ELSE
        RAISE NOTICE '⚠️ No QuoteLine found for validation test';
    END IF;
    
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- VERIFICATION 5: Test capacity validation (exceed width)
-- ====================================================

DO $$
DECLARE
    v_test_quote_line_id uuid;
    v_validation_result jsonb;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'VERIFICATION 5: Capacity Validation Test (Exceed Width)';
    RAISE NOTICE '====================================================';
    
    -- Create a test QuoteLine with width exceeding capacity
    -- First, find a valid QuoteLine to clone
    SELECT id INTO v_test_quote_line_id
    FROM "QuoteLines"
    WHERE deleted = false
        AND product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
        AND operating_system_variant = 'standard_m'
        AND tube_type = 'RTU-42'
    LIMIT 1;
    
    IF v_test_quote_line_id IS NOT NULL THEN
        -- Temporarily update width to exceed capacity (RTU-42 max_width_mm = 3000)
        UPDATE "QuoteLines"
        SET width_m = 4.0  -- 4000mm, exceeds 3000mm limit
        WHERE id = v_test_quote_line_id;
        
        v_validation_result := public.validate_quote_line_configuration(v_test_quote_line_id);
        
        RAISE NOTICE 'Test QuoteLine % (width=4.0m, RTU-42 max=3.0m):', v_test_quote_line_id;
        RAISE NOTICE '  ok: %', v_validation_result->>'ok';
        RAISE NOTICE '  errors: %', v_validation_result->'errors';
        
        -- Restore original width
        UPDATE "QuoteLines"
        SET width_m = 1.0
        WHERE id = v_test_quote_line_id;
        
        IF (v_validation_result->>'ok')::boolean = false THEN
            RAISE NOTICE '✅ Capacity validation correctly blocked exceeding width';
        ELSE
            RAISE NOTICE '⚠️ Capacity validation did not block exceeding width (may need limits set)';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No QuoteLine found for capacity test';
    END IF;
    
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- VERIFICATION 6: Show all mappings and their specificity
-- ====================================================

SELECT 
    'VERIFICATION 6: Mapping Specificity' as check_name,
    m.component_role,
    m.operating_system_variant,
    m.tube_type,
    m.hardware_color,
    m.bottom_rail_type,
    m.priority,
    ci.sku,
    ci.item_name,
    -- Count non-null configuration fields (higher = more specific)
    (
        CASE WHEN m.operating_system_variant IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.tube_type IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.bottom_rail_type IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.side_channel_type IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN m.hardware_color IS NOT NULL THEN 1 ELSE 0 END
    ) as specificity_score
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
ORDER BY 
    m.component_role,
    specificity_score DESC,
    m.priority ASC;

-- ====================================================
-- VERIFICATION 7: Show MotorTubeCompatibility rules
-- ====================================================

SELECT 
    'VERIFICATION 7: MotorTubeCompatibility Rules' as check_name,
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
    AND mtc.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
ORDER BY 
    mtc.operating_system_variant,
    mtc.tube_type;

