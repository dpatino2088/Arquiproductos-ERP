-- ====================================================
-- Migration 313: Fix generate_configured_bom_for_quote_line to Generate ALL Components
-- ====================================================
-- PROBLEM: Function only generates 'fabric' component, missing hardware components
-- SOLUTION: 
--   1. Implement proper idempotency (soft delete existing configured components first)
--   2. Ensure ALL required roles are created (tube, bracket, motor/manual, bottom_bar, etc.)
--   3. Add better error handling and logging
--   4. Fix UOM normalization
-- ====================================================

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS public.generate_configured_bom_for_quote_line CASCADE;

-- Recreate function with complete component generation
CREATE OR REPLACE FUNCTION public.generate_configured_bom_for_quote_line(
    p_quote_line_id uuid,
    p_product_type_id uuid,
    p_organization_id uuid,
    p_drive_type text, -- 'manual' | 'motor'
    p_bottom_rail_type text, -- 'standard' | 'wrapped'
    p_cassette boolean,
    p_cassette_type text, -- 'standard' | 'recessed' | 'surface' (NULL if cassette = false)
    p_side_channel boolean,
    p_side_channel_type text, -- 'side_only' | 'side_and_bottom' (NULL if side_channel = false)
    p_hardware_color text, -- 'white' | 'black' | 'silver' | 'bronze'
    p_width_m numeric,
    p_height_m numeric,
    p_qty numeric,
    p_tube_type text DEFAULT NULL, -- 'RTU-42' | 'RTU-50' | 'RTU-65' | 'RTU-80'
    p_operating_system_variant text DEFAULT NULL -- 'standard_m' | 'standard_l'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_template_record RECORD;
    v_area_sqm numeric;
    v_resolved_catalog_item_id uuid;
    v_component_qty numeric;
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
    v_inserted_component_id uuid;
    v_resolution_error_count integer := 0;
    v_resolution_errors text[] := ARRAY[]::text[];
    v_required_roles text[] := ARRAY[]::text[];
    v_role text;
    v_role_uom text;
    v_role_qty_per_unit numeric;
    v_missing_roles text[] := ARRAY[]::text[];
    v_validation_result jsonb;
    v_template_component_item_id uuid;
    v_soft_deleted_count integer := 0;
    v_created_count integer := 0;
    v_sku text;
    v_unit_cost_exw numeric;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    RAISE NOTICE '  Configuration:';
    RAISE NOTICE '    - product_type_id: %', p_product_type_id;
    RAISE NOTICE '    - tube_type: %', p_tube_type;
    RAISE NOTICE '    - operating_system_variant: %', p_operating_system_variant;
    RAISE NOTICE '    - drive_type: %', p_drive_type;
    RAISE NOTICE '    - side_channel: % (type: %)', p_side_channel, p_side_channel_type;
    RAISE NOTICE '    - bottom_rail_type: %', p_bottom_rail_type;
    RAISE NOTICE '    - cassette: % (type: %)', p_cassette, p_cassette_type;
    RAISE NOTICE '    - hardware_color: %', p_hardware_color;
    RAISE NOTICE '    - width_m: %, height_m: %, qty: %', p_width_m, p_height_m, p_qty;
    RAISE NOTICE '========================================';
    
    -- ====================================================
    -- STEP 1: Load QuoteLine to get dimensions and configuration
    -- ====================================================
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.width_m,
        ql.height_m,
        ql.qty,
        ql.bom_template_id,
        -- Load configuration fields from QuoteLine if not provided as parameters
        COALESCE(ql.tube_type, p_tube_type) as tube_type,
        COALESCE(ql.operating_system_variant, p_operating_system_variant) as operating_system_variant,
        COALESCE(ql.drive_type, p_drive_type) as drive_type,
        COALESCE(ql.bottom_rail_type, p_bottom_rail_type) as bottom_rail_type,
        COALESCE(ql.side_channel, p_side_channel) as side_channel,
        COALESCE(ql.side_channel_type, p_side_channel_type) as side_channel_type,
        COALESCE(ql.hardware_color, p_hardware_color) as hardware_color,
        COALESCE(ql.cassette, p_cassette) as cassette,
        COALESCE(ql.cassette_type, p_cassette_type) as cassette_type
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Use dimensions from QuoteLine or parameters
    v_quote_line_record.width_m := COALESCE(v_quote_line_record.width_m, p_width_m, 0);
    v_quote_line_record.height_m := COALESCE(v_quote_line_record.height_m, p_height_m, 0);
    v_quote_line_record.qty := COALESCE(v_quote_line_record.qty, p_qty, 1);
    
    IF v_quote_line_record.width_m <= 0 OR v_quote_line_record.height_m <= 0 THEN
        RAISE EXCEPTION 'Invalid dimensions: width_m=%, height_m=%. Both must be > 0', 
            v_quote_line_record.width_m, v_quote_line_record.height_m;
    END IF;
    
    v_area_sqm := v_quote_line_record.width_m * v_quote_line_record.height_m;
    
    RAISE NOTICE '  ✅ Loaded QuoteLine: width=%, height=%, area=%, qty=%', 
        v_quote_line_record.width_m, v_quote_line_record.height_m, v_area_sqm, v_quote_line_record.qty;
    
    -- ====================================================
    -- STEP 2: IDEMPOTENCY - Soft delete existing configured components
    -- ====================================================
    UPDATE "QuoteLineComponents"
    SET deleted = true, updated_at = now()
    WHERE quote_line_id = p_quote_line_id
    AND source = 'configured_component'
    AND deleted = false;
    
    GET DIAGNOSTICS v_soft_deleted_count = ROW_COUNT;
    RAISE NOTICE '  🗑️  Soft deleted % existing configured components (idempotency)', v_soft_deleted_count;
    
    -- ====================================================
    -- STEP 3: Validate configuration (if function exists)
    -- ====================================================
    BEGIN
        SELECT public.validate_quote_line_configuration(p_quote_line_id) INTO v_validation_result;
        
        IF (v_validation_result->>'ok')::boolean = false THEN
            RAISE WARNING 'Configuration validation failed: %', 
                array_to_string((v_validation_result->'errors')::text[], '; ');
            -- Continue anyway, but log the warning
        ELSE
            RAISE NOTICE '  ✅ Configuration validation passed';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '  ⚠️  validate_quote_line_configuration() not available or failed: %', SQLERRM;
            -- Continue anyway
    END;
    
    -- ====================================================
    -- STEP 4: Find BOMTemplate (optional, for fallback)
    -- ====================================================
    BEGIN
        SELECT bt.*
        INTO v_bom_template_record
        FROM "BOMTemplates" bt
        WHERE bt.product_type_id = p_product_type_id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        LIMIT 1;
        
        IF FOUND THEN
            RAISE NOTICE '  ✅ Found BOMTemplate: % (for fallback)', v_bom_template_record.id;
        ELSE
            RAISE NOTICE '  ⚠️  No BOMTemplate found (will rely on resolver only)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '  ⚠️  Error loading BOMTemplate: %', SQLERRM;
    END;
    
    -- ====================================================
    -- STEP 5: DEFINE REQUIRED ROLES BASED ON CONFIGURATION
    -- ====================================================
    
    -- Always required roles (core structure)
    v_required_roles := ARRAY['fabric', 'tube', 'bracket'];
    RAISE NOTICE '  📋 Core roles: fabric, tube, bracket';
    
    -- Bottom rail roles (always present for Roller Shade)
    v_required_roles := v_required_roles || ARRAY['bottom_rail_profile', 'bottom_rail_end_cap'];
    RAISE NOTICE '  📋 Added bottom rail roles: bottom_rail_profile, bottom_rail_end_cap';
    
    -- Drive mechanism roles (conditional on drive_type)
    IF v_quote_line_record.drive_type = 'motor' THEN
        -- Motorized: motor + motor_adapter + motor_crown + motor_accessory
        v_required_roles := v_required_roles || ARRAY['motor', 'motor_adapter', 'motor_crown', 'motor_accessory'];
        RAISE NOTICE '  📋 Added motorized roles: motor, motor_adapter, motor_crown, motor_accessory';
    ELSIF v_quote_line_record.drive_type = 'manual' OR v_quote_line_record.drive_type IS NULL THEN
        -- Manual: operating_system_drive + chain + chain_stop
        v_required_roles := v_required_roles || ARRAY['operating_system_drive', 'chain', 'chain_stop'];
        RAISE NOTICE '  📋 Added manual drive roles: operating_system_drive, chain, chain_stop';
    ELSE
        RAISE WARNING '  ⚠️  Unknown drive_type: %, defaulting to manual', v_quote_line_record.drive_type;
        v_required_roles := v_required_roles || ARRAY['operating_system_drive', 'chain', 'chain_stop'];
    END IF;
    
    -- Bracket covers (always present for both manual and motorized)
    v_required_roles := v_required_roles || ARRAY['bracket_cover'];
    RAISE NOTICE '  📋 Added bracket_cover role';
    
    -- Side channel roles (conditional on side_channel = true)
    IF v_quote_line_record.side_channel = true THEN
        v_required_roles := v_required_roles || ARRAY['side_channel_profile', 'side_channel_end_cap'];
        RAISE NOTICE '  📋 Added side channel roles: side_channel_profile, side_channel_end_cap';
    END IF;
    
    -- Cassette roles (conditional on cassette = true)
    IF v_quote_line_record.cassette = true THEN
        v_required_roles := v_required_roles || ARRAY['cassette'];
        RAISE NOTICE '  📋 Added cassette role';
    END IF;
    
    RAISE NOTICE '  📋 Total required roles: %', array_length(v_required_roles, 1);
    RAISE NOTICE '  📋 Roles list: %', array_to_string(v_required_roles, ', ');
    
    -- ====================================================
    -- STEP 6: FOR EACH REQUIRED ROLE, RESOLVE TO SKU AND CREATE COMPONENT
    -- ====================================================
    
    FOREACH v_role IN ARRAY v_required_roles
    LOOP
        BEGIN
            -- Step 6.1: Determine UOM for this role
            v_role_uom := CASE v_role
                WHEN 'tube' THEN 'mts'
                WHEN 'bottom_rail_profile' THEN 'mts'
                WHEN 'side_channel_profile' THEN 'mts'
                WHEN 'chain' THEN 'mts'  -- Chain is linear (3/4 of total height * 2)
                WHEN 'fabric' THEN 'm2'
                ELSE 'ea'
            END;
            
            -- Step 6.2: Calculate quantity based on role and dimensions
            v_component_qty := CASE v_role
                -- Linear components (meters)
                WHEN 'tube' THEN v_quote_line_record.width_m
                WHEN 'bottom_rail_profile' THEN v_quote_line_record.width_m
                WHEN 'side_channel_profile' THEN v_quote_line_record.height_m * 2.0  -- Left + right
                WHEN 'chain' THEN 0.75 * v_quote_line_record.height_m * 2.0  -- 3/4 height × 2 chains
                -- Area components (square meters)
                WHEN 'fabric' THEN v_area_sqm
                -- Each components
                WHEN 'bracket' THEN 2.0  -- 2 brackets per shade
                WHEN 'bottom_rail_end_cap' THEN 2.0  -- 2 end caps per bottom rail
                WHEN 'side_channel_end_cap' THEN 4.0  -- 4 end caps (2 per side × 2 sides)
                WHEN 'chain_stop' THEN 2.0  -- 2 chain stops per curtain
                WHEN 'motor' THEN 1.0
                WHEN 'motor_adapter' THEN 1.0
                WHEN 'motor_crown' THEN 1.0
                WHEN 'motor_accessory' THEN 1.0
                WHEN 'operating_system_drive' THEN 1.0
                WHEN 'bracket_cover' THEN 2.0  -- 2 covers per bracket (RC3007 + RC3008)
                WHEN 'cassette' THEN 1.0
                ELSE 1.0
            END;
            
            -- Multiply by quote line quantity
            v_component_qty := v_component_qty * v_quote_line_record.qty;
            
            RAISE NOTICE '  🔍 Processing role: % (qty: %, uom: %)', v_role, v_component_qty, v_role_uom;
            
            -- Step 6.3: RESOLVE ROLE TO SKU using deterministic resolver
            BEGIN
                v_resolved_catalog_item_id := public.resolve_bom_role_to_catalog_item_id(
                    p_product_type_id,
                    v_role,
                    v_quote_line_record.operating_system_variant,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.side_channel_type,
                    v_quote_line_record.hardware_color,
                    p_organization_id
                );
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ⚠️  Resolver error for role %: %', v_role, SQLERRM;
                    v_resolved_catalog_item_id := NULL;
            END;
            
            -- Step 6.4: Fallback to template component_item_id if resolver returns NULL
            IF v_resolved_catalog_item_id IS NULL THEN
                IF v_bom_template_record.id IS NOT NULL THEN
                    BEGIN
                        SELECT bc.catalog_item_id INTO v_template_component_item_id
                        FROM "BOMComponents" bc
                        WHERE bc.bom_template_id = v_bom_template_record.id
                            AND bc.component_role = v_role
                            AND bc.deleted = false
                        LIMIT 1;
                        
                        IF v_template_component_item_id IS NOT NULL THEN
                            v_resolved_catalog_item_id := v_template_component_item_id;
                            RAISE NOTICE '    ⚠️  Using template component_item_id as fallback for role: %', v_role;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE WARNING '    ⚠️  Error loading template component for role %: %', v_role, SQLERRM;
                    END;
                END IF;
            END IF;
            
            -- Step 6.5: If resolution failed, track error and skip critical roles
            IF v_resolved_catalog_item_id IS NULL THEN
                v_resolution_error_count := v_resolution_error_count + 1;
                v_resolution_errors := v_resolution_errors || 
                    format('Role "%s" could not be resolved to a SKU', v_role);
                v_missing_roles := v_missing_roles || ARRAY[v_role];
                RAISE WARNING '    ❌ Could not resolve role "%" to SKU', v_role;
                
                -- For critical roles, throw error
                IF v_role IN ('fabric', 'tube', 'bracket') THEN
                    RAISE EXCEPTION 'CRITICAL: Role "%" could not be resolved to SKU. Check BomRoleSkuMapping table.', v_role;
                END IF;
                
                CONTINUE; -- Skip this role
            END IF;
            
            -- Step 6.6: Get SKU and unit cost for the resolved catalog item
            BEGIN
                SELECT ci.sku, ci.unit_cost_exw INTO v_sku, v_unit_cost_exw
                FROM "CatalogItems" ci
                WHERE ci.id = v_resolved_catalog_item_id
                AND ci.deleted = false;
                
                IF NOT FOUND THEN
                    RAISE WARNING '    ⚠️  CatalogItem % not found or deleted', v_resolved_catalog_item_id;
                    v_sku := NULL;
                    v_unit_cost_exw := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ⚠️  Error loading CatalogItem %: %', v_resolved_catalog_item_id, SQLERRM;
                    v_sku := NULL;
                    v_unit_cost_exw := 0;
            END;
            
            -- Step 6.7: Insert into QuoteLineComponents
            BEGIN
                INSERT INTO "QuoteLineComponents" (
                    organization_id,
                    quote_line_id,
                    catalog_item_id,
                    qty,
                    unit_cost_exw,
                    component_role,
                    source,
                    uom,
                    created_at,
                    updated_at
                )
                VALUES (
                    p_organization_id,
                    p_quote_line_id,
                    v_resolved_catalog_item_id,
                    v_component_qty,
                    v_unit_cost_exw,
                    v_role,
                    'configured_component',
                    v_role_uom,
                    now(),
                    now()
                )
                RETURNING id INTO v_inserted_component_id;
                
                v_created_count := v_created_count + 1;
                
                -- Track inserted component
                v_component_result := jsonb_build_object(
                    'id', v_inserted_component_id,
                    'catalog_item_id', v_resolved_catalog_item_id,
                    'component_role', v_role,
                    'qty', v_component_qty,
                    'uom', v_role_uom,
                    'sku', v_sku
                );
                v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
                
                RAISE NOTICE '    ✅ Created component: role=%, sku=%, qty=%, uom=%', 
                    v_role, COALESCE(v_sku, 'NULL'), v_component_qty, v_role_uom;
                    
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ❌ Error inserting component for role %: %', v_role, SQLERRM;
                    v_resolution_error_count := v_resolution_error_count + 1;
                    v_resolution_errors := v_resolution_errors || 
                        format('Error inserting role "%s": %', v_role, SQLERRM);
            END;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Unexpected error processing role %: %', v_role, SQLERRM;
                v_resolution_error_count := v_resolution_error_count + 1;
                v_resolution_errors := v_resolution_errors || 
                    format('Unexpected error for role "%s": %', v_role, SQLERRM);
        END;
    END LOOP;
    
    -- ====================================================
    -- STEP 7: Final summary and return
    -- ====================================================
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ BOM Generation Complete';
    RAISE NOTICE '  - Soft deleted: % components', v_soft_deleted_count;
    RAISE NOTICE '  - Created: % components', v_created_count;
    RAISE NOTICE '  - Missing roles: %', array_length(v_missing_roles, 1);
    IF array_length(v_missing_roles, 1) > 0 THEN
        RAISE NOTICE '  - Missing roles list: %', array_to_string(v_missing_roles, ', ');
    END IF;
    RAISE NOTICE '========================================';
    
    RETURN jsonb_build_object(
        'success', true,
        'bom_template_id', COALESCE(v_bom_template_record.id::text, NULL),
        'components', v_inserted_components,
        'required_roles', v_required_roles,
        'missing_roles', v_missing_roles,
        'resolution_errors', v_resolution_errors,
        'resolution_error_count', v_resolution_error_count,
        'created_count', v_created_count,
        'soft_deleted_count', v_soft_deleted_count
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating configured BOM for quote line: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
    'Generates complete BOM components (fabric, tube, bracket, motor/manual, bottom_bar, side_channel, cassette) using deterministic resolver (BomRoleSkuMapping). Implements idempotency by soft-deleting existing configured components first. Falls back to template component_item_id if resolver returns NULL.';

COMMIT;


