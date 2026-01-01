-- ====================================================
-- Migration: Update BOM Function to Use BOMComponents UOM
-- ====================================================
-- Updates generate_configured_bom_for_quote_line to:
-- 1. Use UOM directly from BOMComponents (pre-established)
-- 2. Store UOM in QuoteLineComponents
-- 3. Convert to canonical UOM (m, m2, ea) for cost calculations
-- Valid UOMs: m, y, m2, y2, und, pcs, ea, set, pack
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
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
    v_inserted_component_id uuid;
    v_area_sqm numeric;
    v_tube_width_rule text;
    v_bom_uom text; -- UOM from BOMComponents (pre-established: mts, yd, ft, m2, yd2, und, pcs, ea, set, pack)
    v_canonical_uom text; -- Canonical UOM for cost calculation ('m', 'm2', or 'ea')
BEGIN
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    
    -- Step 1: Load QuoteLine to get dimensions
    SELECT * INTO v_quote_line_record
    FROM "QuoteLines"
    WHERE id = p_quote_line_id AND organization_id = p_organization_id AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine not found: %', p_quote_line_id;
    END IF;
    
    -- Calculate area for area-based components
    v_area_sqm := COALESCE(p_width_m, v_quote_line_record.width_m, 0) * COALESCE(p_height_m, v_quote_line_record.height_m, 0);
    
    -- Determine tube width rule based on width
    IF COALESCE(p_width_m, v_quote_line_record.width_m, 0) <= 3.0 THEN
        v_tube_width_rule := '42';
    ELSIF COALESCE(p_width_m, v_quote_line_record.width_m, 0) <= 4.0 THEN
        v_tube_width_rule := '65';
    ELSE
        v_tube_width_rule := '80';
    END IF;
    
    -- Step 2: Delete existing configured components for this quote line
    DELETE FROM "QuoteLineComponents"
    WHERE quote_line_id = p_quote_line_id
    AND source = 'configured_component'
    AND organization_id = p_organization_id;
    
    -- Step 3: Find BOM Template by product_type_id
    SELECT * INTO v_bom_template_record
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
            'inserted_components', '[]'::jsonb,
            'count', 0
        );
    END IF;
    
    RAISE NOTICE '  ✅ Found BOMTemplate: %', v_bom_template_record.id;
    
    -- Step 4: Iterate through BOM Components and filter by block_condition
    FOR v_bom_component_record IN
        SELECT bom.*
        FROM "BOMComponents" bom
        WHERE bom.bom_template_id = v_bom_template_record.id
        AND bom.organization_id = p_organization_id
        AND bom.deleted = false
        ORDER BY bom.block_type, bom.sequence_order
    LOOP
        -- Step 4.1: Check if block condition matches
        v_block_condition_match := true;
        
        IF v_bom_component_record.block_condition IS NOT NULL THEN
            -- Check drive_type condition
            IF v_bom_component_record.block_condition->>'drive_type' IS NOT NULL THEN
                IF v_bom_component_record.block_condition->>'drive_type' != p_drive_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check bottom_rail_type condition
            IF v_bom_component_record.block_condition->>'bottom_rail_type' IS NOT NULL THEN
                IF v_bom_component_record.block_condition->>'bottom_rail_type' != p_bottom_rail_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check cassette condition
            IF v_bom_component_record.block_condition->>'cassette' IS NOT NULL THEN
                IF (v_bom_component_record.block_condition->>'cassette')::boolean != p_cassette THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check cassette_type condition (if cassette is true)
            IF v_bom_component_record.block_condition->>'cassette_type' IS NOT NULL THEN
                IF p_cassette = false OR v_bom_component_record.block_condition->>'cassette_type' != p_cassette_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check side_channel condition
            IF v_bom_component_record.block_condition->>'side_channel' IS NOT NULL THEN
                IF (v_bom_component_record.block_condition->>'side_channel')::boolean != p_side_channel THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
            
            -- Check side_channel_type condition (if side_channel is true)
            -- IMPORTANT: Bottom channel components require side_channel_type = 'side_and_bottom'
            IF v_bom_component_record.block_condition->>'side_channel_type' IS NOT NULL THEN
                IF p_side_channel = false THEN
                    -- If side_channel is false, skip components that require a specific side_channel_type
                    v_block_condition_match := false;
                ELSIF v_bom_component_record.component_role LIKE '%bottom%channel%' OR 
                      v_bom_component_record.component_role LIKE '%bottom_channel%' THEN
                    -- Bottom channel components require side_channel_type = 'side_and_bottom'
                    IF p_side_channel_type != 'side_and_bottom' THEN
                        v_block_condition_match := false;
                    END IF;
                ELSIF v_bom_component_record.block_condition->>'side_channel_type' != p_side_channel_type THEN
                    -- For other side channel components, check exact match
                    v_block_condition_match := false;
                END IF;
            END IF;
        END IF;
        
        -- Skip if block condition doesn't match
        IF NOT v_block_condition_match THEN
            CONTINUE;
        END IF;
        
        -- Step 4.2: Check color match (using HardwareColorMapping if applies_color = true)
        IF v_bom_component_record.applies_color = true THEN
            -- Try to find mapped SKU via HardwareColorMapping
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
        ELSE
            -- Component doesn't apply color, use base SKU
            v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
        END IF;
        
        -- Step 4.3: Resolve catalog_item_id (if not already resolved by color mapping)
        IF v_resolved_catalog_item_id IS NULL THEN
            IF v_bom_component_record.component_item_id IS NOT NULL THEN
                v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
            ELSIF v_bom_component_record.auto_select = true THEN
                -- Resolve by rule (e.g., tube by width)
                IF v_bom_component_record.sku_resolution_rule = 'width_rule_42_65_80' THEN
                    -- Resolve tube by width rule
                    IF v_tube_width_rule = '42' THEN
                        SELECT id INTO v_resolved_catalog_item_id
                        FROM "CatalogItems"
                        WHERE (sku ILIKE '%RTU%42%' OR sku ILIKE '%TUBE%42%' OR sku ILIKE '%TUBE-42%')
                        AND organization_id = p_organization_id
                        AND deleted = false
                        LIMIT 1;
                    ELSIF v_tube_width_rule = '65' THEN
                        SELECT id INTO v_resolved_catalog_item_id
                        FROM "CatalogItems"
                        WHERE (sku ILIKE '%RTU%65%' OR sku ILIKE '%TUBE%65%' OR sku ILIKE '%TUBE-65%')
                        AND organization_id = p_organization_id
                        AND deleted = false
                        LIMIT 1;
                    ELSIF v_tube_width_rule = '80' THEN
                        SELECT id INTO v_resolved_catalog_item_id
                        FROM "CatalogItems"
                        WHERE (sku ILIKE '%RTU%80%' OR sku ILIKE '%TUBE%80%' OR sku ILIKE '%TUBE-80%')
                        AND organization_id = p_organization_id
                        AND deleted = false
                        LIMIT 1;
                    END IF;
                    
                    IF v_resolved_catalog_item_id IS NULL THEN
                        RAISE WARNING 'Could not resolve tube SKU for width rule: %', v_tube_width_rule;
                        CONTINUE;
                    END IF;
                ELSE
                    -- Unknown resolution rule
                    RAISE WARNING 'Unknown sku_resolution_rule: %', v_bom_component_record.sku_resolution_rule;
                    CONTINUE;
                END IF;
            ELSE
                -- Component without item_id and not auto_select - skip
                CONTINUE;
            END IF;
        END IF;
        
        -- Step 4.4: Calculate quantity
        v_component_qty := v_bom_component_record.qty_per_unit;
        
        -- Use UOM from BOMComponent to determine calculation method
        -- Handle linear UOMs (mts, yd, ft)
        IF v_bom_component_record.uom IN ('mts', 'yd', 'ft') THEN
            -- Linear meters/yards: use width or height based on component_role
            IF v_bom_component_record.component_role = 'tube' OR 
               v_bom_component_record.component_role LIKE '%profile%' OR
               v_bom_component_record.component_role LIKE '%rail%' OR
               v_bom_component_record.component_role LIKE '%cassette%' THEN
                -- Use width for horizontal components
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(p_width_m, v_quote_line_record.width_m, 0);
            ELSIF v_bom_component_record.component_role LIKE '%side%channel%' AND 
                  v_bom_component_record.component_role NOT LIKE '%bottom%' THEN
                -- Side channel profiles: height × 2 units (always 2 profiles)
                v_component_qty := COALESCE(p_height_m, v_quote_line_record.height_m, 0) * 2;
            ELSIF v_bom_component_record.component_role LIKE '%bottom%channel%' OR
                  v_bom_component_record.component_role LIKE '%bottom_channel%' THEN
                -- Bottom channel profile: width × 1 unit (single profile)
                v_component_qty := COALESCE(p_width_m, v_quote_line_record.width_m, 0) * 1;
            ELSE
                -- Use height for other vertical components
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(p_height_m, v_quote_line_record.height_m, 0);
            END IF;
        -- Handle area UOMs (m2, yd2)
        ELSIF v_bom_component_record.uom IN ('m2', 'yd2') THEN
            -- Square meters/yards: use area
            v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_area_sqm, 0);
        END IF;
        -- For piece UOMs (ea, pcs, und, set, pack), qty_per_unit is already correct
        
        -- Multiply by quote line quantity
        v_component_qty := v_component_qty * COALESCE(p_qty, v_quote_line_record.qty, 1);
        
        -- Step 4.5: Get UOM from BOMComponent (pre-established)
        v_bom_uom := COALESCE(v_bom_component_record.uom, 'ea');
        
        -- Step 4.6: Convert to canonical UOM for cost calculation
        -- Canonical UOMs: 'm' (linear), 'm2' (area), 'ea' (pieces)
        -- Map valid UOMs to canonical:
        -- Linear: 'mts' -> 'm', 'yd' -> 'm', 'ft' -> 'm' (will be converted via UomConversions in get_unit_cost_in_uom)
        -- Area: 'm2' -> 'm2', 'yd2' -> 'm2' (will be converted via UomConversions in get_unit_cost_in_uom)
        -- Pieces: 'ea', 'pcs', 'und', 'set', 'pack' -> 'ea'
        IF v_bom_uom IN ('mts', 'yd', 'ft') THEN
            v_canonical_uom := 'm';
        ELSIF v_bom_uom IN ('m2', 'yd2') THEN
            v_canonical_uom := 'm2';
        ELSE
            -- All piece units (ea, pcs, und, set, pack) map to 'ea'
            v_canonical_uom := 'ea';
        END IF;
        
        -- Step 4.7: Insert into QuoteLineComponents with source='configured_component'
        -- Calculate unit_cost_exw in canonical UOM using get_unit_cost_in_uom function
        -- Store the original UOM from BOMComponent in QuoteLineComponents.uom
        INSERT INTO "QuoteLineComponents" (
            organization_id,
            quote_line_id,
            catalog_item_id,
            qty,
            uom, -- Store pre-established UOM from BOMComponent
            unit_cost_exw,
            component_role,
            source
        )
        VALUES (
            p_organization_id,
            p_quote_line_id,
            v_resolved_catalog_item_id,
            v_component_qty,
            v_bom_uom, -- Store pre-established UOM (mts, yd, ft, m2, yd2, und, pcs, ea, set, pack)
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
            'uom', v_bom_uom,
            'component_role', v_bom_component_record.component_role
        );
        v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
        
        -- Reset resolved_catalog_item_id for next iteration
        v_resolved_catalog_item_id := NULL;
    END LOOP;
    
    RAISE NOTICE '  ✅ Generated % configured components', jsonb_array_length(v_inserted_components);
    
    RETURN jsonb_build_object(
        'success', true,
        'inserted_components', v_inserted_components,
        'count', jsonb_array_length(v_inserted_components)
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error generating BOM: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'inserted_components', '[]'::jsonb,
            'count', 0
        );
END;
$$;

COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
    'Generates BOM components using block-based system. Uses UOM from BOMComponents (pre-established: mts, yd, ft, m2, yd2, und, pcs, ea, set, pack) and stores it in QuoteLineComponents. Converts to canonical UOM (m, m2, ea) for cost calculations via get_unit_cost_in_uom. Each customer choice (drive_type, bottom_rail_type, cassette, side_channel, side_channel_type, hardware_color) activates specific BOM blocks.';
