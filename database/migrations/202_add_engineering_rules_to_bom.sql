-- ====================================================
-- Migration: Add Engineering Rules to BOM Components
-- ====================================================
-- This migration adds engineering rules support to BOMComponents
-- for dimensional cut adjustments (e.g., bracket affects tube length)
-- ====================================================

-- STEP 1: Add engineering rules columns to BOMComponents
DO $$
BEGIN
    -- Add affects_role column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'affects_role'
    ) THEN
        ALTER TABLE "BOMComponents"
        ADD COLUMN affects_role text;
        
        COMMENT ON COLUMN "BOMComponents".affects_role IS 
            'Target role that this component affects (e.g., "tube" when bracket affects tube length)';
        
        RAISE NOTICE '✅ Added affects_role to BOMComponents';
    ELSE
        RAISE NOTICE '⏭️  affects_role already exists in BOMComponents';
    END IF;
    
    -- Add cut_axis column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'cut_axis'
    ) THEN
        ALTER TABLE "BOMComponents"
        ADD COLUMN cut_axis text CHECK (cut_axis IS NULL OR cut_axis IN ('length', 'width', 'height'));
        
        COMMENT ON COLUMN "BOMComponents".cut_axis IS 
            'Axis that this component affects: length, width, or height';
        
        RAISE NOTICE '✅ Added cut_axis to BOMComponents';
    ELSE
        RAISE NOTICE '⏭️  cut_axis already exists in BOMComponents';
    END IF;
    
    -- Add cut_delta_mm column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'cut_delta_mm'
    ) THEN
        ALTER TABLE "BOMComponents"
        ADD COLUMN cut_delta_mm numeric(10,2);
        
        COMMENT ON COLUMN "BOMComponents".cut_delta_mm IS 
            'Dimensional adjustment in millimeters (positive or negative)';
        
        RAISE NOTICE '✅ Added cut_delta_mm to BOMComponents';
    ELSE
        RAISE NOTICE '⏭️  cut_delta_mm already exists in BOMComponents';
    END IF;
    
    -- Add cut_delta_scope column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'cut_delta_scope'
    ) THEN
        ALTER TABLE "BOMComponents"
        ADD COLUMN cut_delta_scope text CHECK (cut_delta_scope IS NULL OR cut_delta_scope IN ('per_side', 'per_item'));
        
        COMMENT ON COLUMN "BOMComponents".cut_delta_scope IS 
            'Scope of delta: per_side (applied twice, once per side) or per_item (applied once)';
        
        RAISE NOTICE '✅ Added cut_delta_scope to BOMComponents';
    ELSE
        RAISE NOTICE '⏭️  cut_delta_scope already exists in BOMComponents';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Create function to apply engineering rules
-- ====================================================

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
    v_rule_line RECORD;
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
    
    -- Get SaleOrderLine to access quote dimensions
    SELECT * INTO v_sale_order_line
    FROM "SalesOrderLines"
    WHERE id = v_bom_instance.sale_order_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'SaleOrderLine % not found for BomInstance %', v_bom_instance.sale_order_line_id, p_bom_instance_id;
        RETURN;
    END IF;
    
    -- Get QuoteLine for dimensions (width_m, height_m)
    SELECT * INTO v_quote_line
    FROM "QuoteLines"
    WHERE id = v_sale_order_line.quote_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'QuoteLine % not found for SaleOrderLine %', v_sale_order_line.quote_line_id, v_sale_order_line.id;
        RETURN;
    END IF;
    
    -- Extract dimensions from QuoteLine (convert meters to mm)
    v_width_m := COALESCE(v_quote_line.width_m, 0);
    v_height_m := COALESCE(v_quote_line.height_m, 0);
    
    -- Process each BomInstanceLine that might be affected by engineering rules
    FOR v_target_line IN
        SELECT bil.*
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = p_bom_instance_id
        AND bil.deleted = false
        AND bil.part_role IS NOT NULL
    LOOP
        -- Initialize base dimensions based on role
        v_base_length_mm := NULL;
        v_base_width_mm := NULL;
        v_base_height_mm := NULL;
        
        -- Determine base dimensions based on role
        IF v_target_line.part_role = 'tube' THEN
            -- Tube length is typically the width of the curtain
            v_base_length_mm := COALESCE(v_width_m * 1000, 0);
            v_base_height_mm := COALESCE(v_height_m * 1000, 0);
        ELSIF v_target_line.part_role IN ('fabric', 'fabric_panel') THEN
            -- Fabric dimensions depend on area calculation
            v_base_width_mm := COALESCE(v_width_m * 1000, 0);
            v_base_height_mm := COALESCE(v_height_m * 1000, 0);
        ELSIF v_target_line.part_role IN ('bracket', 'brackets') THEN
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
        
        -- Find all source components that affect this target role and accumulate deltas per axis
        FOR v_rule_line IN
            SELECT 
                bil.part_role as source_role,
                bc.cut_axis,
                bc.cut_delta_mm,
                bc.cut_delta_scope,
                bil.qty
            FROM "BomInstanceLines" bil
            INNER JOIN "QuoteLineComponents" qlc ON qlc.id = bil.quote_line_component_id
            INNER JOIN "BOMComponents" bc ON bc.id = qlc.bom_component_id
            WHERE bil.bom_instance_id = p_bom_instance_id
            AND bil.deleted = false
            AND bc.affects_role = v_target_line.part_role
            AND bc.cut_axis IS NOT NULL
            AND bc.cut_delta_mm IS NOT NULL
        LOOP
            v_rule_applied := true;
            
            -- Accumulate deltas per axis based on scope
            IF v_rule_line.cut_axis = 'length' THEN
                IF v_rule_line.cut_delta_scope = 'per_item' THEN
                    v_length_delta := v_length_delta + (v_rule_line.cut_delta_mm * COALESCE(v_rule_line.qty, 1));
                ELSIF v_rule_line.cut_delta_scope = 'per_side' THEN
                    v_length_delta := v_length_delta + (2 * v_rule_line.cut_delta_mm);
                END IF;
            ELSIF v_rule_line.cut_axis = 'width' THEN
                IF v_rule_line.cut_delta_scope = 'per_item' THEN
                    v_width_delta := v_width_delta + (v_rule_line.cut_delta_mm * COALESCE(v_rule_line.qty, 1));
                ELSIF v_rule_line.cut_delta_scope = 'per_side' THEN
                    v_width_delta := v_width_delta + (2 * v_rule_line.cut_delta_mm);
                END IF;
            ELSIF v_rule_line.cut_axis = 'height' THEN
                IF v_rule_line.cut_delta_scope = 'per_item' THEN
                    v_height_delta := v_height_delta + (v_rule_line.cut_delta_mm * COALESCE(v_rule_line.qty, 1));
                ELSIF v_rule_line.cut_delta_scope = 'per_side' THEN
                    v_height_delta := v_height_delta + (2 * v_rule_line.cut_delta_mm);
                END IF;
            END IF;
            
            -- Build calc_notes
            IF v_calc_notes != '' THEN
                v_calc_notes := v_calc_notes || '; ';
            END IF;
            v_calc_notes := v_calc_notes || format('%s (%s) affects %s %s: %s mm (%s)',
                v_rule_line.source_role,
                COALESCE(v_rule_line.qty::text, '1'),
                v_target_line.part_role,
                v_rule_line.cut_axis,
                v_rule_line.cut_delta_mm::text,
                v_rule_line.cut_delta_scope
            );
        END LOOP;
        
        -- Apply deltas to cut dimensions
        IF v_rule_applied THEN
            -- Apply to the appropriate axes
            IF v_length_delta != 0 AND v_cut_length_mm IS NOT NULL THEN
                v_cut_length_mm := v_cut_length_mm + v_length_delta;
            END IF;
            IF v_width_delta != 0 AND v_cut_width_mm IS NOT NULL THEN
                v_cut_width_mm := v_cut_width_mm + v_width_delta;
            END IF;
            IF v_height_delta != 0 AND v_cut_height_mm IS NOT NULL THEN
                v_cut_height_mm := v_cut_height_mm + v_height_delta;
            END IF;
            
            -- Update BomInstanceLine with calculated cut dimensions and notes
            UPDATE "BomInstanceLines"
            SET
                cut_length_mm = COALESCE(v_cut_length_mm, cut_length_mm),
                cut_width_mm = COALESCE(v_cut_width_mm, cut_width_mm),
                cut_height_mm = COALESCE(v_cut_height_mm, cut_height_mm),
                calc_notes = COALESCE(calc_notes, '') || 
                    CASE WHEN calc_notes IS NOT NULL THEN '; ' ELSE '' END ||
                    'Engineering rules: ' || v_calc_notes
            WHERE id = v_target_line.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Applied engineering rules to BomInstance %', p_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.apply_engineering_rules_to_bom_instance IS 
    'Applies engineering rules from BOMComponents to compute cut dimensions (cut_length_mm, cut_width_mm, cut_height_mm) in BomInstanceLines. Only updates cut dimensions and calc_notes, never modifies qty/uom/resolved_part_id.';

-- ====================================================
-- STEP 3: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 202 completed: Engineering Rules for BOM';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Created/Updated:';
    RAISE NOTICE '   - Columns: BOMComponents.affects_role, cut_axis, cut_delta_mm, cut_delta_scope';
    RAISE NOTICE '   - Function: apply_engineering_rules_to_bom_instance()';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Next Step:';
    RAISE NOTICE '   - Run migration 203 to update trigger to call engineering rules';
    RAISE NOTICE '';
END $$;
