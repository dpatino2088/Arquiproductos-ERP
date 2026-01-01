-- ====================================================
-- Migration: Rebuild generate_configured_bom_for_quote_line from scratch
-- ====================================================
-- This migration rebuilds the BOM generation function cleanly
-- with all fixes and improvements
-- ====================================================

CREATE OR REPLACE FUNCTION public.generate_configured_bom_for_quote_line(
    p_quote_line_id uuid,
    p_product_type_id uuid,
    p_organization_id uuid,
    p_drive_type text, -- 'manual' | 'motor'
    p_bottom_rail_type text, -- 'standard' | 'wrapped'
    p_cassette boolean,
    p_cassette_type text, -- 'round' | 'square' | 'l-shape' (NULL if cassette = false)
    p_side_channel boolean,
    p_side_channel_type text, -- 'side_only' | 'side_and_bottom' (NULL if side_channel = false)
    p_hardware_color text, -- 'white' | 'black' | 'silver' | 'bronze' | etc.
    p_width_m numeric,
    p_height_m numeric,
    p_qty numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record record;
    v_bom_template_record record;
    v_bom_component_record record;
    v_resolved_catalog_item_id uuid;
    v_component_qty numeric;
    v_block_condition_match boolean;
    v_color_match boolean;
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
    v_inserted_component_id uuid;
    v_area_sqm numeric;
    v_tube_width_rule text;
    v_catalog_uom text; -- UOM from CatalogItems (source of truth)
    v_final_uom text; -- Final UOM to store (forced to m/m2 for fabrics)
    v_canonical_uom text; -- Canonical UOM for cost calculation ('m', 'm2', or 'ea')
    v_catalog_item_record record;
    v_block_condition_key text;
    v_block_condition_value text;
BEGIN
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    
    -- Step 1: Load QuoteLine to get dimensions
    SELECT * INTO v_quote_line_record
    FROM "QuoteLines"
    WHERE id = p_quote_line_id 
    AND organization_id = p_organization_id 
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine not found: %', p_quote_line_id;
    END IF;
    
    -- Calculate area for area-based components
    v_area_sqm := COALESCE(p_width_m, v_quote_line_record.width_m, 0) * 
                  COALESCE(p_height_m, v_quote_line_record.height_m, 0);
    
    -- Determine tube width rule based on width
    IF COALESCE(p_width_m, v_quote_line_record.width_m, 0) <= 3.0 THEN
        v_tube_width_rule := '42';
    ELSIF COALESCE(p_width_m, v_quote_line_record.width_m, 0) <= 4.0 THEN
        v_tube_width_rule := '65';
    ELSE
        v_tube_width_rule := '80';
    END IF;
    
    -- Step 2: Delete existing configured components (except fabric - handled separately)
    DELETE FROM "QuoteLineComponents"
    WHERE quote_line_id = p_quote_line_id
    AND source = 'configured_component'
    AND component_role NOT LIKE '%fabric%'
    AND organization_id = p_organization_id;
    
    -- Step 3: Find BOM Template by product_type_id
    SELECT * INTO v_bom_template_record
    FROM "BOMTemplates" bt
    WHERE bt.product_type_id = p_product_type_id
    AND bt.organization_id = p_organization_id
    AND bt.deleted = false
    AND bt.active = true
    ORDER BY bt.created_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active BOM template found for product type: %', p_product_type_id;
    END IF;
    
    RAISE NOTICE '  📋 Using BOM Template: % (ID: %)', v_bom_template_record.name, v_bom_template_record.id;
    
    -- Step 4: Loop through BOM Components and resolve them
    FOR v_bom_component_record IN
        SELECT bc.*
        FROM "BOMComponents" bc
        WHERE bc.bom_template_id = v_bom_template_record.id
        AND bc.deleted = false
        -- Note: organization_id check removed - BOMComponents may not have it or may be shared
        ORDER BY bc.sequence_order NULLS LAST, bc.id
    LOOP
        -- Step 4.1: Check block condition matching
        v_block_condition_match := true;
        
        IF v_bom_component_record.block_condition IS NOT NULL 
           AND v_bom_component_record.block_condition::text != '{}' THEN
            
            -- Iterate through each key in block_condition
            FOR v_block_condition_key, v_block_condition_value IN 
                SELECT key, value FROM jsonb_each_text(v_bom_component_record.block_condition)
            LOOP
                -- Check each condition key
                IF v_block_condition_key = 'drive_type' THEN
                    IF v_block_condition_value != p_drive_type THEN
                        v_block_condition_match := false;
                        EXIT; -- Exit the loop if one condition fails
                    END IF;
                    
                ELSIF v_block_condition_key = 'bottom_rail_type' THEN
                    IF v_block_condition_value != p_bottom_rail_type THEN
                        v_block_condition_match := false;
                        EXIT;
                    END IF;
                    
                ELSIF v_block_condition_key = 'cassette' THEN
                    -- Handle both 'cassette' and 'casette' (typo fix)
                    IF (v_block_condition_value::boolean) != p_cassette THEN
                        v_block_condition_match := false;
                        EXIT;
                    END IF;
                    
                ELSIF v_block_condition_key = 'casette' THEN
                    -- Handle typo 'casette' (legacy support)
                    IF (v_block_condition_value::boolean) != p_cassette THEN
                        v_block_condition_match := false;
                        EXIT;
                    END IF;
                    
                ELSIF v_block_condition_key = 'cassette_type' THEN
                    IF p_cassette = false OR v_block_condition_value != p_cassette_type THEN
                        v_block_condition_match := false;
                        EXIT;
                    END IF;
                    
                ELSIF v_block_condition_key = 'side_channel' THEN
                    IF (v_block_condition_value::boolean) != p_side_channel THEN
                        v_block_condition_match := false;
                        EXIT;
                    END IF;
                    
                ELSIF v_block_condition_key = 'side_channel_type' THEN
                    IF p_side_channel = false OR v_block_condition_value != p_side_channel_type THEN
                        v_block_condition_match := false;
                        EXIT;
                    END IF;
                END IF;
            END LOOP;
        END IF;
        
        -- Skip if block condition doesn't match
        IF NOT v_block_condition_match THEN
            RAISE NOTICE '  ⏭️  Skipping component % (role: %) - block condition does not match', 
                v_bom_component_record.id, v_bom_component_record.component_role;
            CONTINUE;
        END IF;
        
        -- Step 4.2: Resolve catalog_item_id
        v_resolved_catalog_item_id := NULL;
        
        -- First, check if component has fixed component_item_id
        IF v_bom_component_record.component_item_id IS NOT NULL THEN
            v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
            
            -- Step 4.2.1: Check color mapping if applies_color = true
            IF v_bom_component_record.applies_color = true AND p_hardware_color IS NOT NULL THEN
                SELECT mapped_part_id INTO v_resolved_catalog_item_id
                FROM "HardwareColorMapping"
                WHERE base_part_id = v_bom_component_record.component_item_id
                AND hardware_color = p_hardware_color
                AND organization_id = p_organization_id
                AND deleted = false
                LIMIT 1;
                
                -- If no mapping found, use base SKU
                IF v_resolved_catalog_item_id IS NULL THEN
                    v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
                END IF;
            END IF;
            
        ELSIF v_bom_component_record.auto_select = true THEN
            -- Step 4.2.2: Resolve by rule (e.g., tube by width)
            IF v_bom_component_record.sku_resolution_rule = 'width_rule_42_65_80' THEN
                -- Resolve tube by width rule
                IF v_tube_width_rule = '42' THEN
                    SELECT id INTO v_resolved_catalog_item_id
                    FROM "CatalogItems"
                    WHERE (sku ILIKE '%RTU%42%' OR sku ILIKE '%TUBE%42%' OR sku ILIKE '%TUBE-42%')
                    AND organization_id = p_organization_id
                    AND deleted = false
                    ORDER BY sku
                    LIMIT 1;
                ELSIF v_tube_width_rule = '65' THEN
                    SELECT id INTO v_resolved_catalog_item_id
                    FROM "CatalogItems"
                    WHERE (sku ILIKE '%RTU%65%' OR sku ILIKE '%TUBE%65%' OR sku ILIKE '%TUBE-65%')
                    AND organization_id = p_organization_id
                    AND deleted = false
                    ORDER BY sku
                    LIMIT 1;
                ELSIF v_tube_width_rule = '80' THEN
                    SELECT id INTO v_resolved_catalog_item_id
                    FROM "CatalogItems"
                    WHERE (sku ILIKE '%RTU%80%' OR sku ILIKE '%TUBE%80%' OR sku ILIKE '%TUBE-80%')
                    AND organization_id = p_organization_id
                    AND deleted = false
                    ORDER BY sku
                    LIMIT 1;
                END IF;
                
                -- If still not found, try MotorTubeCompatibility
                IF v_resolved_catalog_item_id IS NULL THEN
                    SELECT tube_catalog_item_id INTO v_resolved_catalog_item_id
                    FROM "MotorTubeCompatibility"
                    WHERE motor_family = COALESCE(p_drive_type, 'motor')
                    AND tube_width_rule = v_tube_width_rule
                    AND organization_id = p_organization_id
                    AND deleted = false
                    LIMIT 1;
                END IF;
            END IF;
        END IF;
        
        -- Skip if no catalog_item_id resolved
        IF v_resolved_catalog_item_id IS NULL THEN
            RAISE NOTICE '  ⚠️  Skipping component % (role: %) - could not resolve catalog_item_id', 
                v_bom_component_record.id, v_bom_component_record.component_role;
            CONTINUE;
        END IF;
        
        -- Step 4.3: Get CatalogItem to determine UOM
        SELECT * INTO v_catalog_item_record
        FROM "CatalogItems"
        WHERE id = v_resolved_catalog_item_id
        AND organization_id = p_organization_id
        AND deleted = false;
        
        IF NOT FOUND THEN
            RAISE NOTICE '  ⚠️  CatalogItem not found: %', v_resolved_catalog_item_id;
            CONTINUE;
        END IF;
        
        -- Step 4.4: Determine UOM (force mts/m2 for fabrics, never 'ea')
        -- Map to valid constraint values: 'mts', 'yd', 'ft', 'und', 'pcs', 'ea', 'set', 'pack', 'm2', 'yd2'
        v_catalog_uom := COALESCE(v_catalog_item_record.uom, 'ea');
        
        IF v_catalog_item_record.is_fabric = true THEN
            -- Force fabric UOM to mts or m2, never 'ea'
            IF v_catalog_item_record.fabric_pricing_mode = 'per_linear_m' THEN
                v_final_uom := 'mts'; -- Use 'mts' (not 'm') to match constraint
            ELSIF v_catalog_item_record.fabric_pricing_mode = 'per_sqm' THEN
                v_final_uom := 'm2';
            ELSIF v_catalog_uom IN ('m', 'mts', 'yd', 'ft') THEN
                v_final_uom := 'mts'; -- Map 'm' to 'mts' for constraint
            ELSIF v_catalog_uom IN ('m2', 'yd2', 'ft2', 'sqm', 'area') THEN
                v_final_uom := 'm2'; -- Map all area units to 'm2'
            ELSE
                -- Default to m2 for fabrics if unclear
                v_final_uom := 'm2';
            END IF;
        ELSE
            -- Map catalog UOM to valid constraint values for non-fabrics
            IF v_catalog_uom IN ('m', 'mts') THEN
                v_final_uom := 'mts';
            ELSIF v_catalog_uom IN ('m2', 'sqm', 'area') THEN
                v_final_uom := 'm2';
            ELSIF v_catalog_uom IN ('yd2', 'ft2') THEN
                v_final_uom := 'yd2'; -- Use yd2 (ft2 not in constraint, map to yd2)
            ELSIF v_catalog_uom IN ('und', 'pcs', 'ea', 'set', 'pack') THEN
                v_final_uom := v_catalog_uom; -- Already valid
            ELSIF v_catalog_uom IN ('yd', 'ft') THEN
                v_final_uom := v_catalog_uom; -- Already valid
            ELSE
                -- Default to 'ea' for unknown UOMs
                v_final_uom := 'ea';
            END IF;
        END IF;
        
        -- Step 4.5: Calculate component quantity based on UOM
        v_component_qty := 0;
        
        -- Handle linear UOMs (mts, yd, ft) - note: 'm' is mapped to 'mts'
        IF v_final_uom IN ('mts', 'yd', 'ft') THEN
            -- Use qty_per_unit from BOMComponent
            v_component_qty := COALESCE(v_bom_component_record.qty_per_unit, 0);
            
            -- Special handling for specific component roles
            IF v_bom_component_record.component_role LIKE '%side%channel%' OR
               v_bom_component_record.component_role LIKE '%side_channel%' THEN
                -- Side channel profiles: height × 2 units (always 2 profiles)
                v_component_qty := COALESCE(p_height_m, v_quote_line_record.height_m, 0) * 2;
            ELSIF v_bom_component_record.component_role LIKE '%bottom%channel%' OR
                  v_bom_component_record.component_role LIKE '%bottom_channel%' OR
                  v_bom_component_record.component_role LIKE '%bottom%rail%' THEN
                -- Bottom channel/rail profile: width × 1 unit (single profile)
                v_component_qty := COALESCE(p_width_m, v_quote_line_record.width_m, 0) * 1;
            ELSE
                -- Use height for other vertical components
                v_component_qty := v_bom_component_record.qty_per_unit * 
                                  COALESCE(p_height_m, v_quote_line_record.height_m, 0);
            END IF;
            
        -- Handle area UOMs (m2, yd2) - FOR FABRICS
        ELSIF v_final_uom IN ('m2', 'yd2') THEN
            -- Square meters/yards: use area
            v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_area_sqm, 0);
            
        -- Handle piece UOMs (ea, pcs, und, set, pack)
        ELSIF v_final_uom IN ('ea', 'pcs', 'und', 'set', 'pack') THEN
            -- Use qty_per_unit as-is
            v_component_qty := COALESCE(v_bom_component_record.qty_per_unit, 0);
        END IF;
        
        -- Multiply by quote line quantity
        v_component_qty := v_component_qty * COALESCE(p_qty, v_quote_line_record.qty, 1);
        
        -- Step 4.6: Determine canonical UOM for cost calculation
        -- Canonical UOMs: 'm' (linear), 'm2' (area), 'ea' (pieces)
        IF v_final_uom IN ('mts', 'yd', 'ft') THEN
            v_canonical_uom := 'm'; -- Map to canonical 'm' for cost calculation
        ELSIF v_final_uom IN ('m2', 'yd2') THEN
            v_canonical_uom := 'm2'; -- Map to canonical 'm2' for cost calculation
        ELSE
            -- All piece units (ea, pcs, und, set, pack) map to 'ea'
            v_canonical_uom := 'ea';
        END IF;
        
        -- Step 4.7: Insert into QuoteLineComponents
        INSERT INTO "QuoteLineComponents" (
            organization_id,
            quote_line_id,
            catalog_item_id,
            qty,
            uom, -- Store v_final_uom (forced to mts/m2 for fabrics, mapped to constraint values)
            unit_cost_exw,
            component_role,
            source
        )
        VALUES (
            p_organization_id,
            p_quote_line_id,
            v_resolved_catalog_item_id,
            v_component_qty,
            v_final_uom, -- Use v_final_uom (forced to mts/m2 for fabrics, mapped to constraint values)
            public.get_unit_cost_in_uom(v_resolved_catalog_item_id, v_canonical_uom, p_organization_id),
            v_bom_component_record.component_role,
            'configured_component'
        )
        RETURNING id INTO v_inserted_component_id;
        
        -- Add to result array
        v_component_result := jsonb_build_object(
            'id', v_inserted_component_id,
            'catalog_item_id', v_resolved_catalog_item_id,
            'qty', v_component_qty,
            'uom', v_final_uom,
            'component_role', v_bom_component_record.component_role
        );
        v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
        
        RAISE NOTICE '  ✅ Generated component: % (role: %, qty: %, uom: %)', 
            v_catalog_item_record.sku, 
            v_bom_component_record.component_role,
            v_component_qty,
            v_final_uom;
    END LOOP;
    
    RAISE NOTICE '  ✅ Generated % configured components', jsonb_array_length(v_inserted_components);
    
    RETURN jsonb_build_object(
        'success', true,
        'quote_line_id', p_quote_line_id,
        'components_count', jsonb_array_length(v_inserted_components),
        'components', v_inserted_components
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating BOM: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
    'Generates BOM components using block-based system. Rebuilt from scratch with all fixes. Handles block_condition matching (supports both "cassette" and "casette" for backward compatibility), SKU resolution (auto_select, color mapping), and UOM handling. FORCES area/linear UOM (mts, m2, yd, yd2, ft) for fabric components - NEVER allows "ea". Maps UOMs to valid constraint values: m→mts, m2→m2, yd2→yd2, ft2→yd2. If CatalogItem has "ea" or NULL, determines UOM from fabric_pricing_mode (per_sqm → m2, per_linear_m → mts). Converts to canonical UOM (m, m2, ea) for cost calculations via get_unit_cost_in_uom. Each customer choice (drive_type, bottom_rail_type, cassette, side_channel, side_channel_type, hardware_color) activates specific BOM blocks.';

-- ====================================================
-- Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 188 completed successfully!';
    RAISE NOTICE '📋 Rebuilt:';
    RAISE NOTICE '   - Function: generate_configured_bom_for_quote_line()';
    RAISE NOTICE '   - Clean implementation with all fixes';
    RAISE NOTICE '   - Supports both "cassette" and "casette" in block_conditions';
    RAISE NOTICE '   - Forces fabric UOM to mts/m2 (never "ea")';
    RAISE NOTICE '   - Maps UOMs to valid constraint values (m→mts)';
    RAISE NOTICE '   - Proper block_condition matching';
    RAISE NOTICE '   - SKU resolution (auto_select, color mapping)';
    RAISE NOTICE '';
END $$;

