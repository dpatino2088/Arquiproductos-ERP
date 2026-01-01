-- ====================================================
-- UPDATE: resolve_dimensional_adjustments() to filter by unit_kind
-- ====================================================
-- Only apply EngineeringRules where source component has unit_kind = 'dimensional'
-- Consumable units do NOT affect dimensions
-- ====================================================

CREATE OR REPLACE FUNCTION public.resolve_dimensional_adjustments(
    p_organization_id uuid,
    p_product_type_id uuid,
    p_quote_line_id uuid,
    p_target_role text,
    p_dimension text
)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_total_adjustment_mm integer := 0;
    v_component_record RECORD;
    v_rule_record RECORD;
    v_adjustment_value_mm integer;
    v_operation_sign integer;
BEGIN
    -- ====================================================
    -- Get all QuoteLineComponents for this quote_line_id
    -- Filter: only components with unit_kind = 'dimensional'
    -- ====================================================
    
    FOR v_component_record IN
        SELECT
            qlc.id,
            qlc.catalog_item_id,
            qlc.qty,
            ci.unit_kind,
            ci.measure_basis
        FROM "QuoteLineComponents" qlc
        INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
        WHERE qlc.quote_line_id = p_quote_line_id
        AND qlc.source = 'configured_component'
        AND qlc.deleted = false
        -- CRITICAL: Only process dimensional units
        AND (
            ci.measure_basis != 'unit' OR  -- Non-unit items (fabric, linear_m) always process
            (ci.measure_basis = 'unit' AND ci.unit_kind = 'dimensional')  -- Only dimensional units
        )
        ORDER BY qlc.id
    LOOP
        -- ====================================================
        -- Find EngineeringRules that match this component
        -- ====================================================
        
        FOR v_rule_record IN
            SELECT
                er.id,
                er.operation,
                er.value_mm,
                er.per_unit,
                er.multiplier
            FROM "EngineeringRules" er
            WHERE er.organization_id = p_organization_id
            AND er.product_type_id = p_product_type_id
            AND er.source_component_id = v_component_record.catalog_item_id
            AND er.target_role = p_target_role
            AND er.dimension = p_dimension
            AND er.active = true
            AND er.deleted = false
        LOOP
            -- ====================================================
            -- Calculate adjustment value
            -- ====================================================
            
            v_adjustment_value_mm := v_rule_record.value_mm;
            
            -- Apply multiplier
            IF v_rule_record.multiplier IS NOT NULL AND v_rule_record.multiplier != 1 THEN
                v_adjustment_value_mm := (v_adjustment_value_mm * v_rule_record.multiplier)::integer;
            END IF;
            
            -- Apply per_unit logic
            IF v_rule_record.per_unit = true THEN
                v_adjustment_value_mm := (v_adjustment_value_mm * v_component_record.qty)::integer;
            END IF;
            
            -- Determine operation sign
            IF v_rule_record.operation = 'ADD' THEN
                v_operation_sign := 1;
            ELSIF v_rule_record.operation = 'SUBTRACT' THEN
                v_operation_sign := -1;
            ELSE
                v_operation_sign := 0;
                RAISE WARNING 'Unknown operation: % for EngineeringRule %', v_rule_record.operation, v_rule_record.id;
            END IF;
            
            -- Add to total
            v_total_adjustment_mm := v_total_adjustment_mm + (v_operation_sign * v_adjustment_value_mm);
        END LOOP;
    END LOOP;
    
    RETURN v_total_adjustment_mm;
END;
$$;

COMMENT ON FUNCTION public.resolve_dimensional_adjustments IS 
'Calculates total dimensional adjustment in mm for a given organization, product_type, quote_line, target_role, and dimension.
Only processes components with unit_kind = ''dimensional'' (or non-unit items like fabric/linear_m).
Consumable units (unit_kind = ''consumable'') are excluded from dimensional calculations.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.resolve_dimensional_adjustments(uuid, uuid, uuid, text, text) TO authenticated;






