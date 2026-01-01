-- ====================================================
-- Migration 215: Fix apply_engineering_rules_to_bom_instance function
-- ====================================================
-- This fixes the function to correctly get engineering rules from BOMComponents
-- and apply them to compute cut dimensions. Also handles bottom_rail_profile.
-- ====================================================

BEGIN;

-- Fix the apply_engineering_rules_to_bom_instance function
CREATE OR REPLACE FUNCTION public.apply_engineering_rules_to_bom_instance(
    p_bom_instance_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_bom_instance RECORD;
    v_sale_order_line RECORD;
    v_target_line RECORD;
    v_rule_component RECORD;
    v_source_line RECORD;
    v_base_length_mm numeric;
    v_base_width_mm numeric;
    v_base_height_mm numeric;
    v_cut_length_mm numeric;
    v_cut_width_mm numeric;
    v_cut_height_mm numeric;
    v_length_delta numeric;
    v_width_delta numeric;
    v_height_delta numeric;
    v_calc_notes text;
    v_rule_applied boolean;
    v_quote_line RECORD;
    v_width_m numeric;
    v_height_m numeric;
    v_normalized_target_role text;
    v_normalized_affects_role text;
    v_bom_template_id uuid;
BEGIN
    -- Get BOM instance details
    SELECT * INTO v_bom_instance
    FROM "BomInstances"
    WHERE id = p_bom_instance_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'BomInstance % not found', p_bom_instance_id;
        RETURN;
    END IF;
    
    -- Get SaleOrderLine first (needed for both template lookup and dimensions)
    SELECT * INTO v_sale_order_line
    FROM "SalesOrderLines"
    WHERE id = v_bom_instance.sale_order_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'SaleOrderLine % not found for BomInstance %', v_bom_instance.sale_order_line_id, p_bom_instance_id;
        RETURN;
    END IF;
    
    -- Get the BOM template ID (prefer bom_template_id from BomInstance, fallback to finding via product_type_id)
    v_bom_template_id := v_bom_instance.bom_template_id;
    
    IF v_bom_template_id IS NULL THEN
        -- Try to find template via product_type_id from SaleOrderLine
        IF v_sale_order_line.product_type_id IS NOT NULL THEN
            -- Find template by product_type_id
            SELECT id INTO v_bom_template_id
            FROM "BOMTemplates"
            WHERE product_type_id = v_sale_order_line.product_type_id
            AND deleted = false
            AND active = true
            ORDER BY 
                CASE WHEN organization_id = v_bom_instance.organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
    END IF;
    
    IF v_bom_template_id IS NULL THEN
        RAISE WARNING 'Cannot find BOM template for BomInstance %. BomInstance.bom_template_id is NULL and SaleOrderLine.product_type_id is %', 
            p_bom_instance_id, v_sale_order_line.product_type_id;
        RETURN;
    END IF;
    
    -- Get QuoteLine for dimensions (width_m, height_m)
    SELECT * INTO v_quote_line
    FROM "QuoteLines"
    WHERE id = v_sale_order_line.quote_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        -- Fallback: try to get dimensions from SalesOrderLine if available
        v_width_m := COALESCE(v_sale_order_line.width_m, 0);
        v_height_m := COALESCE(v_sale_order_line.height_m, 0);
        IF v_width_m = 0 AND v_height_m = 0 THEN
            RAISE WARNING 'QuoteLine % not found and SalesOrderLine has no dimensions for BomInstance %', 
                v_sale_order_line.quote_line_id, p_bom_instance_id;
            RETURN;
        END IF;
    ELSE
        -- Extract dimensions from QuoteLine (convert meters to mm)
        v_width_m := COALESCE(v_quote_line.width_m, v_sale_order_line.width_m, 0);
        v_height_m := COALESCE(v_quote_line.height_m, v_sale_order_line.height_m, 0);
    END IF;
    
    -- Process each BomInstanceLine that might be affected by engineering rules
    FOR v_target_line IN
        SELECT bil.*
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = p_bom_instance_id
        AND bil.deleted = false
        AND bil.part_role IS NOT NULL
    LOOP
        -- Normalize target role for consistent comparison
        v_normalized_target_role := normalize_component_role(v_target_line.part_role);
        
        -- Initialize base dimensions based on role
        v_base_length_mm := NULL;
        v_base_width_mm := NULL;
        v_base_height_mm := NULL;
        
        -- Determine base dimensions based on normalized role
        IF v_normalized_target_role = 'tube' THEN
            -- Tube length is typically the width of the curtain
            v_base_length_mm := COALESCE(v_width_m * 1000, 0);
        ELSIF v_normalized_target_role = 'bottom_rail_profile' THEN
            -- Bottom rail length is the width of the curtain
            v_base_length_mm := COALESCE(v_width_m * 1000, 0);
        ELSIF v_normalized_target_role IN ('fabric', 'fabric_panel') THEN
            -- Fabric dimensions depend on area calculation
            v_base_width_mm := COALESCE(v_width_m * 1000, 0);
            v_base_height_mm := COALESCE(v_height_m * 1000, 0);
        ELSIF v_normalized_target_role = 'bracket' THEN
            -- Brackets are typically fixed size, no base dimension from quote
            v_base_length_mm := NULL;
        END IF;
        
        -- Initialize cut dimensions with base values
        v_cut_length_mm := v_base_length_mm;
        v_cut_width_mm := v_base_width_mm;
        v_cut_height_mm := v_base_height_mm;
        
        -- Reset deltas and notes
        v_length_delta := 0;
        v_width_delta := 0;
        v_height_delta := 0;
        v_calc_notes := '';
        v_rule_applied := false;
        
        -- Find all BOMComponents from the template that have engineering rules affecting this target role
        FOR v_rule_component IN
            SELECT 
                bc.component_role as source_role,
                bc.affects_role,
                bc.cut_axis,
                bc.cut_delta_mm,
                bc.cut_delta_scope
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_id
            AND bc.deleted = false
            AND bc.affects_role IS NOT NULL
            AND bc.cut_axis IS NOT NULL
            AND bc.cut_axis != 'none'
            AND bc.cut_delta_mm IS NOT NULL
        LOOP
            -- Normalize affects_role for comparison
            v_normalized_affects_role := normalize_component_role(v_rule_component.affects_role);
            
            -- Check if this rule affects the target role (using normalized values)
            IF v_normalized_affects_role IS NULL OR v_normalized_affects_role != v_normalized_target_role THEN
                CONTINUE; -- Skip this rule, it doesn't affect the target
            END IF;
            
            -- Find source BomInstanceLines that match this rule's component_role
            FOR v_source_line IN
                SELECT bil.id, bil.part_role, bil.qty
                FROM "BomInstanceLines" bil
                WHERE bil.bom_instance_id = p_bom_instance_id
                AND bil.deleted = false
                AND normalize_component_role(bil.part_role) = normalize_component_role(v_rule_component.source_role)
            LOOP
                v_rule_applied := true;
                
                -- Accumulate deltas per axis based on scope
                IF v_rule_component.cut_axis = 'length' THEN
                    IF v_rule_component.cut_delta_scope = 'per_item' THEN
                        v_length_delta := v_length_delta + (v_rule_component.cut_delta_mm * COALESCE(v_source_line.qty, 1));
                    ELSIF v_rule_component.cut_delta_scope = 'per_side' THEN
                        v_length_delta := v_length_delta + (2 * v_rule_component.cut_delta_mm);
                    END IF;
                ELSIF v_rule_component.cut_axis = 'width' THEN
                    IF v_rule_component.cut_delta_scope = 'per_item' THEN
                        v_width_delta := v_width_delta + (v_rule_component.cut_delta_mm * COALESCE(v_source_line.qty, 1));
                    ELSIF v_rule_component.cut_delta_scope = 'per_side' THEN
                        v_width_delta := v_width_delta + (2 * v_rule_component.cut_delta_mm);
                    END IF;
                ELSIF v_rule_component.cut_axis = 'height' THEN
                    IF v_rule_component.cut_delta_scope = 'per_item' THEN
                        v_height_delta := v_height_delta + (v_rule_component.cut_delta_mm * COALESCE(v_source_line.qty, 1));
                    ELSIF v_rule_component.cut_delta_scope = 'per_side' THEN
                        v_height_delta := v_height_delta + (2 * v_rule_component.cut_delta_mm);
                    END IF;
                END IF;
                
                -- Build calc_notes
                IF v_calc_notes != '' THEN
                    v_calc_notes := v_calc_notes || '; ';
                END IF;
                v_calc_notes := v_calc_notes || format('%s (qty=%s) affects %s %s: %s mm (%s)',
                    v_rule_component.source_role,
                    COALESCE(v_source_line.qty::text, '1'),
                    v_target_line.part_role,
                    v_rule_component.cut_axis,
                    v_rule_component.cut_delta_mm::text,
                    v_rule_component.cut_delta_scope
                );
            END LOOP;
        END LOOP;
        
        -- Always update base dimensions if we have them, even without rules
        -- Apply deltas to cut dimensions
        IF v_base_length_mm IS NOT NULL OR v_base_width_mm IS NOT NULL OR v_base_height_mm IS NOT NULL OR v_rule_applied THEN
            -- Apply deltas to the appropriate axes
            IF v_length_delta != 0 AND v_cut_length_mm IS NOT NULL THEN
                v_cut_length_mm := v_cut_length_mm + v_length_delta;
            END IF;
            IF v_width_delta != 0 AND v_cut_width_mm IS NOT NULL THEN
                v_cut_width_mm := v_cut_width_mm + v_width_delta;
            END IF;
            IF v_height_delta != 0 AND v_cut_height_mm IS NOT NULL THEN
                v_cut_height_mm := v_cut_height_mm + v_height_delta;
            END IF;
            
            -- Build base dimension note
            IF v_base_length_mm IS NOT NULL OR v_base_width_mm IS NOT NULL THEN
                IF v_calc_notes != '' THEN
                    v_calc_notes := format('Base: width=%.2fm (%.0fmm)', v_width_m, COALESCE(v_base_length_mm, v_base_width_mm)) || '; ' || v_calc_notes;
                ELSE
                    v_calc_notes := format('Base: width=%.2fm (%.0fmm)', v_width_m, COALESCE(v_base_length_mm, v_base_width_mm));
                END IF;
            END IF;
            
            -- Update BomInstanceLine with calculated cut dimensions and notes
            UPDATE "BomInstanceLines"
            SET
                cut_length_mm = CASE 
                    WHEN v_cut_length_mm IS NOT NULL THEN v_cut_length_mm
                    ELSE cut_length_mm
                END,
                cut_width_mm = CASE 
                    WHEN v_cut_width_mm IS NOT NULL THEN v_cut_width_mm
                    ELSE cut_width_mm
                END,
                cut_height_mm = CASE 
                    WHEN v_cut_height_mm IS NOT NULL THEN v_cut_height_mm
                    ELSE cut_height_mm
                END,
                calc_notes = CASE 
                    WHEN v_calc_notes != '' THEN v_calc_notes
                    ELSE COALESCE(calc_notes, '')
                END
            WHERE id = v_target_line.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Applied engineering rules to BomInstance %', p_bom_instance_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error applying engineering rules to BomInstance %: %', p_bom_instance_id, SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.apply_engineering_rules_to_bom_instance IS 
    'Applies engineering rules from BOMComponents to compute cut dimensions (cut_length_mm, cut_width_mm, cut_height_mm) in BomInstanceLines. Fixed to get rules from BOM template directly, not through QuoteLineComponents. Handles tube and bottom_rail_profile base dimensions.';

COMMIT;

