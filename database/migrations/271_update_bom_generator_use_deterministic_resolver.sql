-- ====================================================
-- Migration 271: Update BOM Generator to Use Deterministic Resolver
-- ====================================================
-- Updates generate_configured_bom_for_quote_line() to:
-- 1. Use validate_quote_line_configuration()
-- 2. Use resolve_bom_role_to_catalog_item_id() instead of resolve_bom_role_to_sku()
-- 3. Fallback to template component_item_id if resolver returns NULL
-- ====================================================

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS public.generate_configured_bom_for_quote_line CASCADE;

-- Recreate function with deterministic resolver
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
    -- ⭐ Configuration fields for deterministic SKU resolution
    p_tube_type text DEFAULT NULL, -- 'RTU-42' | 'RTU-65' | 'RTU-80'
    p_operating_system_variant text DEFAULT NULL -- 'standard_m' | 'standard_l'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_template_record RECORD;
    v_bom_component_record RECORD;
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
BEGIN
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    RAISE NOTICE '  Configuration: tube_type=%, operating_system_variant=%, drive_type=%, side_channel=%, bottom_rail_type=%', 
        p_tube_type, p_operating_system_variant, p_drive_type, p_side_channel, p_bottom_rail_type;
    
    -- Step 1: Load QuoteLine to get dimensions and configuration
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.width_m,
        ql.height_m,
        ql.qty,
        -- Load configuration fields from QuoteLine if not provided as parameters
        COALESCE(
            ql.tube_type,
            p_tube_type,
            -- Infer from operating_system_variant (defaults)
            CASE
                WHEN ql.operating_system_variant ILIKE '%standard_m%' OR ql.operating_system_variant ILIKE '%m%' THEN 'RTU-42'
                WHEN ql.operating_system_variant ILIKE '%standard_l%' OR ql.operating_system_variant ILIKE '%l%' THEN 'RTU-65'
                ELSE NULL
            END
        ) as tube_type,
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
    v_quote_line_record.width_m := COALESCE(v_quote_line_record.width_m, p_width_m);
    v_quote_line_record.height_m := COALESCE(v_quote_line_record.height_m, p_height_m);
    v_quote_line_record.qty := COALESCE(v_quote_line_record.qty, p_qty, 1);
    v_area_sqm := CASE 
        WHEN v_quote_line_record.width_m IS NOT NULL AND v_quote_line_record.height_m IS NOT NULL 
        THEN v_quote_line_record.width_m * v_quote_line_record.height_m
        ELSE NULL
    END;
    
    -- Step 2: Validate configuration
    v_validation_result := public.validate_quote_line_configuration(p_quote_line_id);
    
    IF (v_validation_result->>'ok')::boolean = false THEN
        RAISE EXCEPTION 'Configuration validation failed: %', 
            array_to_string((v_validation_result->'errors')::text[], '; ');
    END IF;
    
    -- Step 3: Find BOMTemplate by product_type_id
    SELECT bt.*
    INTO v_bom_template_record
    FROM "BOMTemplates" bt
    WHERE bt.product_type_id = p_product_type_id
    AND bt.organization_id = p_organization_id
    AND bt.deleted = false
    AND bt.active = true
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE WARNING 'No BOMTemplate found for product_type_id: %', p_product_type_id;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No BOMTemplate found',
            'components', '[]'::jsonb
        );
    END IF;
    
    RAISE NOTICE '  ✅ Found BOMTemplate: %', v_bom_template_record.id;
    
    -- ====================================================
    -- STEP 4: EXPLICITLY CREATE ROLES BASED ON CONFIGURATION
    -- ====================================================
    
    -- Always required roles (core structure)
    v_required_roles := ARRAY['tube', 'bracket', 'fabric'];
    
    -- Bottom rail roles (always present for Roller Shade)
    IF v_quote_line_record.bottom_rail_type IS NOT NULL THEN
        v_required_roles := v_required_roles || ARRAY['bottom_rail_profile', 'bottom_rail_end_cap'];
        RAISE NOTICE '  ✅ Added bottom rail roles (bottom_rail_type: %)', v_quote_line_record.bottom_rail_type;
    ELSE
        RAISE WARNING '⚠️ bottom_rail_type is NULL, but adding bottom rail roles anyway (default behavior)';
        v_required_roles := v_required_roles || ARRAY['bottom_rail_profile', 'bottom_rail_end_cap'];
    END IF;
    
    -- Drive mechanism roles (conditional on drive_type)
    IF v_quote_line_record.drive_type = 'motor' THEN
        -- Motorized: motor + motor_adapter + motor_crown + motor_accessory
        v_required_roles := v_required_roles || ARRAY['motor', 'motor_adapter', 'motor_crown', 'motor_accessory'];
        RAISE NOTICE '  ✅ Added motor roles (drive_type: motor) - motor, motor_adapter, motor_crown, motor_accessory';
    ELSIF v_quote_line_record.drive_type = 'manual' OR v_quote_line_record.drive_type IS NULL THEN
        -- Manual: operating_system_drive (RC3001/RC3002/RC3003 según configuración) + chain + chain_stop
        v_required_roles := v_required_roles || ARRAY['operating_system_drive', 'chain', 'chain_stop'];
        RAISE NOTICE '  ✅ Added manual drive mechanism roles (drive_type: manual) - operating_system_drive, chain, chain_stop';
    ELSE
        RAISE WARNING '⚠️ Unknown drive_type: %, adding operating_system_drive as fallback', v_quote_line_record.drive_type;
        v_required_roles := v_required_roles || ARRAY['operating_system_drive'];
    END IF;
    
    -- Bracket covers (always present for both manual and motorized)
    -- RC3007 + RC3008 are decorative covers for bracket RC3006
    v_required_roles := v_required_roles || ARRAY['bracket_cover'];
    RAISE NOTICE '  ✅ Added bracket_cover role (always present for RC3006 bracket)';
    
    -- Side channel roles (conditional on side_channel = true)
    IF v_quote_line_record.side_channel = true THEN
        v_required_roles := v_required_roles || ARRAY['side_channel_profile', 'side_channel_end_cap'];
        RAISE NOTICE '  ✅ Added side channel roles (side_channel: true, type: %)', v_quote_line_record.side_channel_type;
    ELSE
        RAISE NOTICE '  ⏭️ Skipping side channel roles (side_channel: false or NULL)';
    END IF;
    
    RAISE NOTICE '  📋 Required roles: %', array_to_string(v_required_roles, ', ');
    
    -- ====================================================
    -- STEP 5: FOR EACH REQUIRED ROLE, RESOLVE TO SKU AND CREATE COMPONENT
    -- ====================================================
    
    FOREACH v_role IN ARRAY v_required_roles
    LOOP
        -- Step 5.1: Determine UOM and qty_per_unit for this role
        v_role_uom := CASE v_role
            WHEN 'tube' THEN 'mts'
            WHEN 'bottom_rail_profile' THEN 'mts'
            WHEN 'side_channel_profile' THEN 'mts'
            WHEN 'chain' THEN 'mts'  -- Chain is linear (3/4 of total height * 2)
            WHEN 'fabric' THEN 'm2'
            ELSE 'ea'
        END;
        
        v_role_qty_per_unit := CASE v_role
            WHEN 'tube' THEN 1.0  -- Will be multiplied by width_m
            WHEN 'bottom_rail_profile' THEN 1.0  -- Will be multiplied by width_m
            WHEN 'side_channel_profile' THEN 1.0  -- Will be multiplied by height_m * 2
            WHEN 'chain' THEN 0.75  -- 3/4 of total height, will be multiplied by height_m * 2 (two chains)
            WHEN 'fabric' THEN 1.0  -- Will be multiplied by area
            ELSE 1.0  -- ea items
        END;
        
        -- Step 5.2: Calculate quantity based on role and dimensions
        v_component_qty := v_role_qty_per_unit;
        
        IF v_role_uom IN ('mts', 'm', 'linear_m', 'meter') THEN
            -- Linear meters: use width or height based on role
            IF v_role = 'tube' OR v_role = 'bottom_rail_profile' THEN
                -- Horizontal components: use width
                v_component_qty := v_role_qty_per_unit * COALESCE(v_quote_line_record.width_m, 0);
            ELSIF v_role = 'side_channel_profile' THEN
                -- Side channel: height × 2 units (left + right)
                v_component_qty := COALESCE(v_quote_line_record.height_m, 0) * 2.0;
            ELSIF v_role = 'chain' THEN
                -- Chain: 3/4 of total height × 2 (two chains)
                v_component_qty := v_role_qty_per_unit * COALESCE(v_quote_line_record.height_m, 0) * 2.0;
            ELSE
                -- Default: use height for vertical components
                v_component_qty := v_role_qty_per_unit * COALESCE(v_quote_line_record.height_m, 0);
            END IF;
        ELSIF v_role_uom IN ('sqm', 'area', 'm2') THEN
            -- Square meters: use area
            v_component_qty := v_role_qty_per_unit * COALESCE(v_area_sqm, 0);
        END IF;
        
        -- Special handling for chain_stop (2 per curtain, ea)
        IF v_role = 'chain_stop' THEN
            v_component_qty := 2.0;  -- 2 chain stops per curtain
        END IF;
        
        -- Multiply by quote line quantity
        v_component_qty := v_component_qty * COALESCE(v_quote_line_record.qty, 1);
        
        -- Step 5.3: RESOLVE ROLE TO SKU using deterministic resolver
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
        
        -- Step 5.4: Fallback to template component_item_id if resolver returns NULL
        IF v_resolved_catalog_item_id IS NULL THEN
            -- Try to get component_item_id from BOMTemplate
            SELECT bc.catalog_item_id INTO v_template_component_item_id
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_record.id
                AND bc.component_role = v_role
                AND bc.deleted = false
            LIMIT 1;
            
            IF v_template_component_item_id IS NOT NULL THEN
                v_resolved_catalog_item_id := v_template_component_item_id;
                RAISE NOTICE '  ⚠️ Using template component_item_id as fallback for role: %', v_role;
            END IF;
        END IF;
        
        -- Step 5.5: If resolution failed, track error
        IF v_resolved_catalog_item_id IS NULL THEN
            v_resolution_error_count := v_resolution_error_count + 1;
            v_resolution_errors := v_resolution_errors || 
                format('Role "%s" could not be resolved to a SKU (no mapping in BomRoleSkuMapping and no template component_item_id)', v_role);
            v_missing_roles := v_missing_roles || ARRAY[v_role];
            RAISE WARNING '⚠️ Could not resolve role "%" to SKU', v_role;
            
            -- For critical roles, throw error instead of continuing
            -- Note: operating_system_drive is only critical for manual, motor is critical for motorized
            IF v_role IN ('tube', 'bracket', 'fabric') THEN
                RAISE EXCEPTION 'CRITICAL: Role "%" could not be resolved to SKU. Check BomRoleSkuMapping table and ensure mappings exist for product_type_id=%, role=%, operating_system_variant=%, tube_type=%.', 
                    v_role, p_product_type_id, v_role, v_quote_line_record.operating_system_variant, v_quote_line_record.tube_type;
            ELSIF v_role = 'operating_system_drive' AND (v_quote_line_record.drive_type = 'manual' OR v_quote_line_record.drive_type IS NULL) THEN
                RAISE EXCEPTION 'CRITICAL: Role "operating_system_drive" (manual mechanism) could not be resolved to SKU. Check BomRoleSkuMapping table for manual drive components (RC3001, RC3002, RC3003, etc.).';
            ELSIF v_role = 'motor' AND v_quote_line_record.drive_type = 'motor' THEN
                RAISE EXCEPTION 'CRITICAL: Role "motor" could not be resolved to SKU. Check BomRoleSkuMapping table for motor components (CM-09, CM-10, etc.).';
            ELSIF v_role = 'chain' AND (v_quote_line_record.drive_type = 'manual' OR v_quote_line_record.drive_type IS NULL) THEN
                RAISE EXCEPTION 'CRITICAL: Role "chain" (manual) could not be resolved to SKU. Check BomRoleSkuMapping table for chain components (V15DP, RB.., V15M, RB..M, etc.).';
            END IF;
            
            CONTINUE; -- Skip this role
        END IF;
        
        -- Step 5.6: Get unit cost for the resolved catalog item
        DECLARE
            v_unit_cost_exw numeric;
        BEGIN
            SELECT cost_exw INTO v_unit_cost_exw
            FROM "CatalogItems"
            WHERE id = v_resolved_catalog_item_id
            AND deleted = false;
            
            -- Step 5.7: Insert into QuoteLineComponents
            INSERT INTO "QuoteLineComponents" (
                organization_id,
                quote_line_id,
                catalog_item_id,
                qty,
                unit_cost_exw,
                component_role,
                source,
                uom
            )
            VALUES (
                p_organization_id,
                p_quote_line_id,
                v_resolved_catalog_item_id,
                v_component_qty,
                v_unit_cost_exw,
                v_role,
                'configured_component',
                v_role_uom
            )
            ON CONFLICT (quote_line_id, catalog_item_id, component_role, source) 
            WHERE deleted = false
            DO UPDATE SET
                qty = EXCLUDED.qty,
                unit_cost_exw = EXCLUDED.unit_cost_exw,
                uom = EXCLUDED.uom,
                updated_at = now()
            RETURNING id INTO v_inserted_component_id;
            
            -- Step 5.8: Track inserted component
            IF v_inserted_component_id IS NOT NULL THEN
                DECLARE
                    v_sku text;
                BEGIN
                    SELECT sku INTO v_sku
                    FROM "CatalogItems"
                    WHERE id = v_resolved_catalog_item_id;
                    
                    v_component_result := jsonb_build_object(
                        'id', v_inserted_component_id,
                        'catalog_item_id', v_resolved_catalog_item_id,
                        'component_role', v_role,
                        'qty', v_component_qty,
                        'uom', v_role_uom,
                        'sku', v_sku
                    );
                    v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
                    
                    RAISE NOTICE '  ✅ Created component: role=%, sku=%, qty=%', v_role, v_sku, v_component_qty;
                END;
            END IF;
        END;
    END LOOP;
    
    -- Step 6: Validate that all required roles were created
    IF array_length(v_missing_roles, 1) > 0 THEN
        RAISE WARNING '⚠️ Missing roles that could not be resolved: %', array_to_string(v_missing_roles, ', ');
    END IF;
    
    -- Step 7: Return result with resolution errors if any
    RETURN jsonb_build_object(
        'success', true,
        'bom_template_id', v_bom_template_record.id,
        'components', v_inserted_components,
        'required_roles', v_required_roles,
        'missing_roles', v_missing_roles,
        'resolution_errors', v_resolution_errors,
        'resolution_error_count', v_resolution_error_count
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating configured BOM for quote line: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
    'Generates BOM components using deterministic resolver (BomRoleSkuMapping). Validates configuration using validate_quote_line_configuration(). Creates roles conditionally based on configuration (motor roles when drive_type=motor, side_channel roles when side_channel=true). Falls back to template component_item_id if resolver returns NULL.';

COMMIT;

