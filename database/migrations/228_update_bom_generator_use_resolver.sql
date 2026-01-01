-- ====================================================
-- Migration 228: Update BOM Generator to Use Role-to-SKU Resolver
-- ====================================================
-- Updates generate_configured_bom_for_quote_line to use the new
-- resolve_bom_role_to_sku function for deterministic SKU resolution
-- ====================================================

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS public.generate_configured_bom_for_quote_line CASCADE;

-- Create updated function with new signature including configuration fields
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
    -- ⭐ NEW: Configuration fields for deterministic SKU resolution
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
    v_resolved_catalog_item_id uuid;
    v_component_qty numeric;
    v_block_condition_match boolean;
    v_color_match boolean;
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
    v_inserted_component_id uuid;
    v_area_sqm numeric;
    v_resolution_error_count integer := 0;
    v_resolution_errors text[] := ARRAY[]::text[];
BEGIN
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    RAISE NOTICE '  Configuration: tube_type=%, operating_system_variant=%, drive_type=%, hardware_color=%', 
        p_tube_type, p_operating_system_variant, p_drive_type, p_hardware_color;
    
    -- Step 1: Load QuoteLine to get dimensions and configuration
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.width_m,
        ql.height_m,
        ql.qty,
        -- ⭐ Load configuration fields from QuoteLine if not provided as parameters
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
    v_quote_line_record.width_m := COALESCE(v_quote_line_record.width_m, p_width_m);
    v_quote_line_record.height_m := COALESCE(v_quote_line_record.height_m, p_height_m);
    v_quote_line_record.qty := COALESCE(v_quote_line_record.qty, p_qty, 1);
    v_area_sqm := CASE 
        WHEN v_quote_line_record.width_m IS NOT NULL AND v_quote_line_record.height_m IS NOT NULL 
        THEN v_quote_line_record.width_m * v_quote_line_record.height_m
        ELSE NULL
    END;
    
    -- Step 2: Find BOMTemplate by product_type_id
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
    
    -- Step 3: Loop through BOMComponents and resolve to SKUs
    FOR v_bom_component_record IN
        SELECT 
            bom.*,
            ci.cost_exw as component_cost_exw,
            ci.sku as component_sku
        FROM "BOMComponents" bom
        LEFT JOIN "CatalogItems" ci ON bom.component_item_id = ci.id
        WHERE bom.bom_template_id = v_bom_template_record.id
        AND bom.organization_id = p_organization_id
        AND bom.deleted = false
        ORDER BY bom.block_type, bom.sequence_order
    LOOP
        -- Step 3.1: Check if block condition matches
        v_block_condition_match := true;
        
        IF v_bom_component_record.block_condition IS NOT NULL THEN
            -- Check drive_type condition
            IF v_bom_component_record.block_condition->>'drive_type' IS NOT NULL THEN
                IF v_bom_component_record.block_condition->>'drive_type' != v_quote_line_record.drive_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check bottom_rail_type condition
            IF v_bom_component_record.block_condition->>'bottom_rail_type' IS NOT NULL THEN
                IF v_bom_component_record.block_condition->>'bottom_rail_type' != v_quote_line_record.bottom_rail_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check cassette condition
            IF v_bom_component_record.block_condition->>'cassette' IS NOT NULL THEN
                IF (v_bom_component_record.block_condition->>'cassette')::boolean != v_quote_line_record.cassette THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check cassette_type condition (if cassette is true)
            IF v_bom_component_record.block_condition->>'cassette_type' IS NOT NULL THEN
                IF v_quote_line_record.cassette = false OR v_bom_component_record.block_condition->>'cassette_type' != v_quote_line_record.cassette_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check side_channel condition
            IF v_bom_component_record.block_condition->>'side_channel' IS NOT NULL THEN
                IF (v_bom_component_record.block_condition->>'side_channel')::boolean != v_quote_line_record.side_channel THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check side_channel_type condition (if side_channel is true)
            IF v_bom_component_record.block_condition->>'side_channel_type' IS NOT NULL THEN
                IF v_quote_line_record.side_channel = false OR v_bom_component_record.block_condition->>'side_channel_type' != v_quote_line_record.side_channel_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
        END IF;
        
        -- Skip if block condition doesn't match
        IF NOT v_block_condition_match THEN
            CONTINUE;
        END IF;
        
        -- Step 3.2: Check color match
        v_color_match := true;
        
        IF v_bom_component_record.applies_color = true THEN
            IF v_bom_component_record.hardware_color != v_quote_line_record.hardware_color THEN
                v_color_match := false;
            END IF;
        END IF;
        
        -- Skip if color doesn't match
        IF NOT v_color_match THEN
            CONTINUE;
        END IF;
        
        -- Step 3.3: ⭐ RESOLVE catalog_item_id using the new resolver function
        -- Priority: 1) Use resolver with configuration fields, 2) Use component_item_id, 3) Use auto_select rules
        v_resolved_catalog_item_id := NULL;
        
        -- Try resolver first (for deterministic SKU resolution)
        IF v_bom_component_record.component_role IS NOT NULL THEN
            v_resolved_catalog_item_id := public.resolve_bom_role_to_sku(
                v_bom_component_record.component_role,
                p_organization_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.operating_system_variant,
                v_quote_line_record.tube_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.cassette,
                v_quote_line_record.cassette_type
            );
        END IF;
        
        -- Fallback 1: Use component_item_id if resolver returned NULL
        IF v_resolved_catalog_item_id IS NULL AND v_bom_component_record.component_item_id IS NOT NULL THEN
            v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
            RAISE NOTICE '  📌 Using component_item_id for role "%": %', 
                v_bom_component_record.component_role, v_resolved_catalog_item_id;
        END IF;
        
        -- Fallback 2: Use auto_select rules (legacy behavior for backward compatibility)
        IF v_resolved_catalog_item_id IS NULL AND v_bom_component_record.auto_select = true THEN
            IF v_bom_component_record.sku_resolution_rule = 'width_rule_42_65_80' THEN
                -- Legacy: Resolve tube by width rule (if tube_type is not set)
                DECLARE
                    v_tube_width_rule text;
                BEGIN
                    IF v_quote_line_record.width_m IS NOT NULL THEN
                        IF v_quote_line_record.width_m < 0.042 THEN
                            v_tube_width_rule := '42';
                        ELSIF v_quote_line_record.width_m < 0.065 THEN
                            v_tube_width_rule := '65';
                        ELSE
                            v_tube_width_rule := '80';
                        END IF;
                        
                        IF v_tube_width_rule = '42' THEN
                            SELECT id INTO v_resolved_catalog_item_id
                            FROM "CatalogItems"
                            WHERE (sku ILIKE '%TUBE%42%' OR sku ILIKE '%TUBE-42%')
                            AND organization_id = p_organization_id
                            AND deleted = false
                            LIMIT 1;
                        ELSIF v_tube_width_rule = '65' THEN
                            SELECT id INTO v_resolved_catalog_item_id
                            FROM "CatalogItems"
                            WHERE (sku ILIKE '%TUBE%65%' OR sku ILIKE '%TUBE-65%')
                            AND organization_id = p_organization_id
                            AND deleted = false
                            LIMIT 1;
                        ELSIF v_tube_width_rule = '80' THEN
                            SELECT id INTO v_resolved_catalog_item_id
                            FROM "CatalogItems"
                            WHERE (sku ILIKE '%TUBE%80%' OR sku ILIKE '%TUBE-80%')
                            AND organization_id = p_organization_id
                            AND deleted = false
                            LIMIT 1;
                        END IF;
                    END IF;
                END;
            END IF;
        END IF;
        
        -- If still NULL, log error and skip
        IF v_resolved_catalog_item_id IS NULL THEN
            v_resolution_error_count := v_resolution_error_count + 1;
            v_resolution_errors := v_resolution_errors || 
                format('Role "%s" (block_type: %s) could not be resolved to a SKU', 
                    v_bom_component_record.component_role, 
                    v_bom_component_record.block_type);
            RAISE WARNING '⚠️ Could not resolve role "%" to SKU (block_type: %)', 
                v_bom_component_record.component_role, v_bom_component_record.block_type;
            CONTINUE;
        END IF;
        
        -- Step 3.4: Calculate quantity
        v_component_qty := v_bom_component_record.qty_per_unit;
        
        IF v_bom_component_record.uom IN ('m', 'linear_m', 'meter') THEN
            -- Linear meters: use width or height based on component_role
            IF v_bom_component_record.component_role = 'tube' OR 
               v_bom_component_record.component_role LIKE '%profile%' OR
               v_bom_component_record.component_role LIKE '%rail%' OR
               v_bom_component_record.component_role LIKE '%cassette%' THEN
                -- Use width for horizontal components
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_quote_line_record.width_m, 0);
            ELSIF v_bom_component_record.component_role LIKE '%side_channel%' OR
                  v_bom_component_record.component_role LIKE '%side%channel%' THEN
                -- Side channel: height × 2 units (always required)
                v_component_qty := COALESCE(v_quote_line_record.height_m, 0) * 2;
            ELSE
                -- Use height for vertical components
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_quote_line_record.height_m, 0);
            END IF;
        ELSIF v_bom_component_record.uom IN ('sqm', 'area', 'm2') THEN
            -- Square meters: use area
            v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_area_sqm, 0);
        END IF;
        
        -- Multiply by quote line quantity
        v_component_qty := v_component_qty * COALESCE(v_quote_line_record.qty, 1);
        
        -- Step 3.5: Insert into QuoteLineComponents with source='configured_component'
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
            v_bom_component_record.component_cost_exw,
            v_bom_component_record.component_role,
            'configured_component',
            v_bom_component_record.uom
        )
        ON CONFLICT (quote_line_id, catalog_item_id, component_role, source) 
        WHERE deleted = false
        DO UPDATE SET
            qty = EXCLUDED.qty,
            unit_cost_exw = EXCLUDED.unit_cost_exw,
            updated_at = now()
        RETURNING id INTO v_inserted_component_id;
        
        -- Step 3.6: Track inserted component
        IF v_inserted_component_id IS NOT NULL THEN
            SELECT sku INTO v_component_result
            FROM "CatalogItems"
            WHERE id = v_resolved_catalog_item_id;
            
            v_component_result := jsonb_build_object(
                'id', v_inserted_component_id,
                'catalog_item_id', v_resolved_catalog_item_id,
                'component_role', v_bom_component_record.component_role,
                'block_type', v_bom_component_record.block_type,
                'qty', v_component_qty,
                'sku', v_component_result
            );
            v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
        END IF;
    END LOOP;
    
    -- Step 4: Return result with resolution errors if any
    RETURN jsonb_build_object(
        'success', true,
        'bom_template_id', v_bom_template_record.id,
        'components', v_inserted_components,
        'resolution_errors', v_resolution_errors,
        'resolution_error_count', v_resolution_error_count
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating configured BOM for quote line: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
    'Generates BOM components using block-based system with deterministic SKU resolution. Uses resolve_bom_role_to_sku() to map roles to concrete CatalogItems based on configuration fields (tube_type, operating_system_variant, drive_type, hardware_color, etc.). Returns JSONB with success status, inserted components, and any resolution errors.';

-- Update the trigger function call to pass new configuration fields
-- This is done in migration 226, but we need to ensure the signature matches
-- The trigger already loads these fields from QuoteLines, so we just need to pass them

COMMIT;



