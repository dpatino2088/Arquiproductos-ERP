-- ====================================================
-- Migration 223: Fix Generate BOM and Ensure Engineering Rules Applied
-- ====================================================
-- This migration ensures that:
-- 1. generate_bom_for_manufacturing_order exists and calls engineering rules
-- 2. apply_engineering_rules_to_bom_instance has better logging (RAISE NOTICE)
-- 3. Engineering rules correctly match part_role vs affects_role (not component_role)
-- 4. Linear materials are converted to meters
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Update apply_engineering_rules_to_bom_instance 
-- to add detailed logging and ensure correct matching
-- ====================================================

-- First, let's add better logging to the existing function
-- We'll recreate it with RAISE NOTICE statements for debugging

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
    v_template_name text;
    v_rules_found_count integer := 0;
    v_rules_applied_count integer := 0;
    v_lines_updated_count integer := 0;
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
    
    -- Get template name for logging
    SELECT name INTO v_template_name
    FROM "BOMTemplates"
    WHERE id = v_bom_instance.bom_template_id;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Applying engineering rules to BomInstance % (template: %)', p_bom_instance_id, COALESCE(v_template_name, 'N/A');
    
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
    
    RAISE NOTICE '   📐 Dimensions: width=%.2fm, height=%.2fm', v_width_m, v_height_m;
    
    -- Count rules in template
    SELECT COUNT(*) INTO v_rules_found_count
    FROM "BOMComponents" bc
    WHERE bc.bom_template_id = v_bom_template_id
    AND bc.deleted = false
    AND bc.affects_role IS NOT NULL
    AND bc.cut_axis IS NOT NULL
    AND bc.cut_axis != 'none'
    AND bc.cut_delta_mm IS NOT NULL;
    
    RAISE NOTICE '   📋 Found % engineering rule(s) in template', v_rules_found_count;
    
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
        -- ⚠️ IMPORTANT: Match by affects_role (NOT component_role)
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
            
            -- ✅ CRITICAL: Match bil.part_role with bc.affects_role (NOT component_role)
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
                v_rules_applied_count := v_rules_applied_count + 1;
                
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
            
            v_lines_updated_count := v_lines_updated_count + 1;
            
            IF v_cut_length_mm IS NOT NULL THEN
                RAISE NOTICE '   ✅ Updated % (part_role=%): cut_length_mm=%.2f, notes=%', 
                    v_target_line.resolved_sku, v_target_line.part_role, v_cut_length_mm, LEFT(v_calc_notes, 100);
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Applied engineering rules: % rule(s) applied, % line(s) updated', v_rules_applied_count, v_lines_updated_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error applying engineering rules to BomInstance %: %', p_bom_instance_id, SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.apply_engineering_rules_to_bom_instance IS 
    'Applies engineering rules from BOMComponents to compute cut dimensions (cut_length_mm, cut_width_mm, cut_height_mm) in BomInstanceLines. Matches bil.part_role with bc.affects_role (NOT component_role). Includes detailed logging via RAISE NOTICE.';

-- ====================================================
-- STEP 2: Create/Update generate_bom_for_manufacturing_order RPC function
-- ====================================================

-- Drop existing function if it exists (might have different return type)
DROP FUNCTION IF EXISTS public.generate_bom_for_manufacturing_order(uuid);

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_manufacturing_order RECORD;
    v_sale_order RECORD;
    v_bom_instance RECORD;
    v_bom_instance_id uuid;
    v_result jsonb := '{}'::jsonb;
    v_count integer := 0;
BEGIN
    -- Get Manufacturing Order
    SELECT * INTO v_manufacturing_order
    FROM "ManufacturingOrders"
    WHERE id = p_manufacturing_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Generating BOM for Manufacturing Order %', v_manufacturing_order.manufacturing_order_no;
    
    -- Get Sale Order
    SELECT * INTO v_sale_order
    FROM "SalesOrders"
    WHERE id = v_manufacturing_order.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_manufacturing_order.sale_order_id, p_manufacturing_order_id;
    END IF;
    
    -- Process each BomInstance linked to this Sale Order
    FOR v_bom_instance IN
        SELECT bi.id
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order.id
        AND bi.deleted = false
        AND sol.deleted = false
    LOOP
        v_bom_instance_id := v_bom_instance.id;
        v_count := v_count + 1;
        
        RAISE NOTICE '   📦 Processing BomInstance %', v_bom_instance_id;
        
        -- Apply engineering rules, fix NULL part_roles, and convert linear roles to meters
        -- This wrapper function does all three steps in the correct order
        BEGIN
            PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
            RAISE NOTICE '   ✅ Applied engineering rules and converted linear roles for BomInstance %', v_bom_instance_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error applying engineering rules/conversion to BomInstance %: %', v_bom_instance_id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ BOM generation completed: % BomInstance(s) processed', v_count;
    
    v_result := jsonb_build_object(
        'success', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'bom_instances_processed', v_count
    );
    
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in generate_bom_for_manufacturing_order: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'Generates/updates BOM for a Manufacturing Order by: (1) applying engineering rules, (2) fixing NULL part_roles, (3) converting linear roles to meters. Calls apply_engineering_rules_and_convert_linear_uom for each BomInstance.';

COMMIT;

