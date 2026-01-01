-- ====================================================
-- Fix Format Error in populate_bom_line_base_pricing_fields
-- ====================================================
-- Fixes the "unrecognized format() type specifier" error
-- by converting numeric values to text before using format()
-- ====================================================

CREATE OR REPLACE FUNCTION public.populate_bom_line_base_pricing_fields(
    p_bom_instance_line_id uuid,
    p_catalog_item_id uuid,
    p_component_qty numeric,
    p_component_uom text,
    p_component_role text,
    p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_catalog_item RECORD;
    v_qty_base numeric;
    v_uom_base text;
    v_qty_pricing numeric;
    v_uom_pricing text;
    v_unit_cost_base numeric;
    v_unit_cost_pricing numeric;
    v_total_cost_base numeric;
    v_total_cost_pricing numeric;
    v_calc_notes text;
    v_pricing_result RECORD;
BEGIN
    -- Get catalog item data
    SELECT 
        ci.is_fabric,
        ci.roll_width_m,
        ci.fabric_pricing_mode::text,
        ci.measure_basis,
        ci.uom
    INTO v_catalog_item
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
    AND ci.organization_id = p_organization_id
    AND ci.deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'CatalogItem % not found for BOM line %', p_catalog_item_id, p_bom_instance_line_id;
        RETURN;
    END IF;
    
    -- Determine base UOM and quantity
    IF v_catalog_item.is_fabric THEN
        -- Fabric: base is always m2
        v_uom_base := 'm2';
        -- Convert component qty to m2 if needed
        IF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            v_qty_base := p_component_qty;
        ELSIF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M', 'MTS', 'METER', 'METERS') THEN
            -- Linear meters -> m2: multiply by roll width
            IF v_catalog_item.roll_width_m IS NOT NULL AND v_catalog_item.roll_width_m > 0 THEN
                v_qty_base := p_component_qty * v_catalog_item.roll_width_m;
            ELSE
                -- No roll width: cannot convert, use component qty as-is (will be wrong, but better than NULL)
                v_qty_base := p_component_qty;
                v_calc_notes := 'WARNING: No roll_width_m for fabric, cannot convert linear m to m2';
            END IF;
        ELSE
            -- Unknown UOM: use component qty as-is
            v_qty_base := p_component_qty;
            v_calc_notes := 'WARNING: Unknown fabric UOM, using component qty as base';
        END IF;
    ELSE
        -- Non-fabric: normalize to canonical
        v_uom_base := public.normalize_uom_to_canonical(p_component_uom);
        v_qty_base := p_component_qty;
    END IF;
    
    -- Determine pricing UOM and quantity
    IF v_catalog_item.is_fabric AND v_catalog_item.fabric_pricing_mode IS NOT NULL THEN
        -- Use fabric pricing mode
        SELECT * INTO v_pricing_result
        FROM public.calculate_fabric_pricing_qty(
            v_qty_base,
            v_catalog_item.fabric_pricing_mode,
            v_catalog_item.roll_width_m
        );
        v_qty_pricing := v_pricing_result.qty_pricing;
        v_uom_pricing := v_pricing_result.uom_pricing;
    ELSE
        -- Non-fabric or no pricing mode: same as base
        v_qty_pricing := v_qty_base;
        v_uom_pricing := v_uom_base;
    END IF;
    
    -- Calculate costs
    v_unit_cost_base := public.get_unit_cost_in_uom(p_catalog_item_id, v_uom_base, p_organization_id);
    v_unit_cost_pricing := public.get_unit_cost_in_pricing_uom(p_catalog_item_id, v_uom_pricing, p_organization_id);
    
    -- If costs are 0 or NULL, try to use existing unit_cost_exw from BomInstanceLines
    IF (v_unit_cost_base IS NULL OR v_unit_cost_base = 0) THEN
        SELECT unit_cost_exw INTO v_unit_cost_base
        FROM "BomInstanceLines"
        WHERE id = p_bom_instance_line_id;
    END IF;
    
    IF (v_unit_cost_pricing IS NULL OR v_unit_cost_pricing = 0) THEN
        v_unit_cost_pricing := v_unit_cost_base;
    END IF;
    
    v_total_cost_base := v_qty_base * COALESCE(v_unit_cost_base, 0);
    v_total_cost_pricing := v_qty_pricing * COALESCE(v_unit_cost_pricing, 0);
    
    -- Build calc_notes (FIXED: convert numerics to text before format())
    IF v_calc_notes IS NULL THEN
        v_calc_notes := '';
    END IF;
    
    IF v_catalog_item.is_fabric THEN
        v_calc_notes := v_calc_notes || 
            format('Fabric: base=%s %s, pricing=%s %s (mode=%s, roll_width=%s m)',
                ROUND(v_qty_base, 4)::text, 
                v_uom_base, 
                ROUND(v_qty_pricing, 4)::text, 
                v_uom_pricing,
                COALESCE(v_catalog_item.fabric_pricing_mode, 'none'),
                ROUND(COALESCE(v_catalog_item.roll_width_m, 0), 4)::text);
    ELSE
        v_calc_notes := v_calc_notes || 
            format('Base=%s %s, pricing=%s %s',
                ROUND(v_qty_base, 4)::text, 
                v_uom_base, 
                ROUND(v_qty_pricing, 4)::text, 
                v_uom_pricing);
    END IF;
    
    -- Update BomInstanceLine
    UPDATE "BomInstanceLines"
    SET
        qty_base = v_qty_base,
        uom_base = v_uom_base,
        qty_pricing = v_qty_pricing,
        uom_pricing = v_uom_pricing,
        unit_cost_base = v_unit_cost_base,
        unit_cost_pricing = v_unit_cost_pricing,
        total_cost_base = v_total_cost_base,
        total_cost_pricing = v_total_cost_pricing,
        calc_notes = COALESCE(calc_notes, '') || CASE WHEN calc_notes IS NOT NULL THEN '; ' ELSE '' END || v_calc_notes
    WHERE id = p_bom_instance_line_id;
END;
$$;

COMMENT ON FUNCTION public.populate_bom_line_base_pricing_fields IS 
    'Populates base and pricing quantity/UOM fields in BomInstanceLines. Fixed format() error by converting numerics to text.';

-- Re-run backfill for failed lines
DO $$
DECLARE
    v_failed_count integer;
    v_success_count integer;
BEGIN
    -- Count failed lines
    SELECT COUNT(*) INTO v_failed_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bil.deleted = false
    AND (bil.qty_base IS NULL OR bil.uom_base IS NULL);
    
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Re-running backfill for % failed lines...', v_failed_count;
    RAISE NOTICE '';
    
    -- The backfill will be run manually by the user
    RAISE NOTICE 'Run: SELECT * FROM backfill_bom_lines_base_pricing();';
    RAISE NOTICE '';
END $$;





