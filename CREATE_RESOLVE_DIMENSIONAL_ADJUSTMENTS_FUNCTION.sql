-- ====================================================
-- STEP 3: Create resolve_dimensional_adjustments function
-- ====================================================
-- This function calculates total dimensional adjustments in mm
-- based on EngineeringRules and QuoteLineComponents
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
    v_adjustment_mm integer;
    v_operation_sign integer;
BEGIN
    -- Validate inputs
    IF p_organization_id IS NULL OR p_product_type_id IS NULL OR p_quote_line_id IS NULL THEN
        RETURN 0;
    END IF;
    
    IF p_target_role IS NULL OR p_dimension IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Loop through all QuoteLineComponents for this quote_line_id
    FOR v_component_record IN
        SELECT 
            qlc.id,
            qlc.catalog_item_id,
            qlc.qty,
            qlc.deleted
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = p_quote_line_id
        AND qlc.deleted = false
    LOOP
        -- Find matching EngineeringRules
        FOR v_rule_record IN
            SELECT 
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
            -- Determine operation sign
            IF v_rule_record.operation = 'ADD' THEN
                v_operation_sign := 1;
            ELSIF v_rule_record.operation = 'SUBTRACT' THEN
                v_operation_sign := -1;
            ELSE
                v_operation_sign := 0;
            END IF;
            
            -- Calculate adjustment for this component
            IF v_rule_record.per_unit THEN
                -- Multiply by quantity
                v_adjustment_mm := v_operation_sign * v_rule_record.value_mm * v_component_record.qty * v_rule_record.multiplier;
            ELSE
                -- Fixed value regardless of quantity
                v_adjustment_mm := v_operation_sign * v_rule_record.value_mm * v_rule_record.multiplier;
            END IF;
            
            -- Add to total
            v_total_adjustment_mm := v_total_adjustment_mm + v_adjustment_mm;
        END LOOP;
    END LOOP;
    
    RETURN v_total_adjustment_mm;
END;
$$;

COMMENT ON FUNCTION public.resolve_dimensional_adjustments IS 
'Calculates total dimensional adjustment in mm for a given quote line, product type, target role, and dimension.
Reads QuoteLineComponents and matches against EngineeringRules to compute adjustments.
Returns integer mm (can be negative for SUBTRACT operations).';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.resolve_dimensional_adjustments(uuid, uuid, uuid, text, text) TO authenticated;






