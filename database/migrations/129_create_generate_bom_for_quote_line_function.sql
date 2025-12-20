-- ====================================================
-- Migration: Create generate_bom_for_quote_line function
-- ====================================================
-- This function generates BOM components for a quote line by:
-- 1. Finding the appropriate BOMTemplate based on product_type_id, operating_system, manufacturer
-- 2. Getting BOMComponents from the template
-- 3. Resolving components (using rules if needed)
-- 4. Inserting components into QuoteLineComponents with component_role
-- ====================================================

-- Drop existing function(s) with different signatures to avoid ambiguity
DROP FUNCTION IF EXISTS public.generate_bom_for_quote_line(uuid, uuid, text, text, numeric, numeric, text, uuid, jsonb, uuid);
DROP FUNCTION IF EXISTS public.generate_bom_for_quote_line(uuid, uuid, uuid, text, text, numeric, numeric, text, jsonb, uuid);

CREATE OR REPLACE FUNCTION public.generate_bom_for_quote_line(
    p_quote_line_id uuid,
    p_product_type_id uuid,
    p_organization_id uuid,
    p_operating_system text DEFAULT NULL,
    p_manufacturer text DEFAULT NULL,
    p_width_mm numeric DEFAULT NULL,
    p_height_mm numeric DEFAULT NULL,
    p_hardware_color text DEFAULT NULL,
    p_sales_config jsonb DEFAULT '{}'::jsonb,
    p_fabric_catalog_item_id uuid DEFAULT NULL
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
    v_inserted_component_id uuid;
    v_component_qty numeric;
    v_width_m numeric;
    v_height_m numeric;
    v_area_sqm numeric;
    v_fabric_qty numeric;
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
BEGIN
    -- Step 1: Load QuoteLine to get dimensions
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.width_m,
        ql.height_m,
        ql.qty
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Use dimensions from QuoteLine or parameters (convert mm to m)
    v_width_m := COALESCE(v_quote_line_record.width_m, p_width_mm / 1000.0);
    v_height_m := COALESCE(v_quote_line_record.height_m, p_height_mm / 1000.0);
    v_area_sqm := CASE 
        WHEN v_width_m IS NOT NULL AND v_height_m IS NOT NULL THEN v_width_m * v_height_m
        ELSE NULL
    END;
    
    -- Step 2: Find BOMTemplate
    -- First try to find template matching operating_system and manufacturer (if columns exist)
    -- If not found or columns don't exist, fallback to any template for product_type_id
    BEGIN
        -- Try with operating_system and manufacturer filters
        SELECT bt.*
        INTO v_bom_template_record
        FROM "BOMTemplates" bt
        WHERE bt.product_type_id = p_product_type_id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        AND (bt.operating_system IS NULL OR bt.operating_system = p_operating_system)
        AND (bt.manufacturer IS NULL OR bt.manufacturer = p_manufacturer)
        ORDER BY 
            CASE WHEN bt.operating_system IS NOT NULL THEN 1 ELSE 2 END,
            CASE WHEN bt.manufacturer IS NOT NULL THEN 1 ELSE 2 END
        LIMIT 1;
    EXCEPTION
        WHEN undefined_column THEN
            -- Columns don't exist, just find by product_type_id
            SELECT bt.*
            INTO v_bom_template_record
            FROM "BOMTemplates" bt
            WHERE bt.product_type_id = p_product_type_id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            LIMIT 1;
    END;
    
    -- If still not found, try without filters
    IF NOT FOUND THEN
        SELECT bt.*
        INTO v_bom_template_record
        FROM "BOMTemplates" bt
        WHERE bt.product_type_id = p_product_type_id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        LIMIT 1;
    END IF;
    
    IF NOT FOUND THEN
        RAISE WARNING 'No BOMTemplate found for product_type_id: %, operating_system: %, manufacturer: %', 
            p_product_type_id, p_operating_system, p_manufacturer;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No BOMTemplate found',
            'components', '[]'::jsonb
        );
    END IF;
    
    -- Step 3: Loop through BOMComponents and insert into QuoteLineComponents
    FOR v_bom_component_record IN
        SELECT 
            bom.*,
            ci.cost_exw as component_cost_exw
        FROM "BOMComponents" bom
        LEFT JOIN "CatalogItems" ci ON bom.component_item_id = ci.id
        WHERE bom.bom_template_id = v_bom_template_record.id
        AND bom.organization_id = p_organization_id
        AND bom.deleted = false
        ORDER BY bom.sequence_order
    LOOP
        -- Step 3.1: Resolve catalog_item_id
        -- If component has fixed component_item_id, use it
        -- Otherwise, if auto_select=true, resolve using rules (future implementation)
        IF v_bom_component_record.component_item_id IS NOT NULL THEN
            v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
        ELSIF v_bom_component_record.auto_select = true THEN
            -- TODO: Implement rule-based resolution using resolve_component_by_rule()
            -- For now, skip components without fixed item_id
            CONTINUE;
        ELSE
            -- Component without item_id and not auto_select - skip
            CONTINUE;
        END IF;
        
        -- Step 3.2: Handle fabric component specially
        IF v_bom_component_record.component_role = 'fabric' AND p_fabric_catalog_item_id IS NOT NULL THEN
            v_resolved_catalog_item_id := p_fabric_catalog_item_id;
            
            -- Calculate fabric qty: roll_width_m × height_m
            SELECT roll_width_m INTO v_fabric_qty
            FROM "CatalogItems"
            WHERE id = p_fabric_catalog_item_id
            AND deleted = false;
            
            IF v_fabric_qty IS NOT NULL AND v_height_m IS NOT NULL THEN
                v_component_qty := v_fabric_qty * v_height_m * COALESCE(v_quote_line_record.qty, 1);
            ELSE
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_quote_line_record.qty, 1);
            END IF;
        ELSE
            -- Step 3.3: Calculate quantity based on UOM
            v_component_qty := v_bom_component_record.qty_per_unit;
            
            IF v_bom_component_record.uom IN ('m', 'linear_m', 'meter') THEN
                -- Linear meters: use width or height
                IF v_bom_component_record.component_role = 'tube' THEN
                    v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_width_m, 0);
                ELSE
                    v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_height_m, 0);
                END IF;
            ELSIF v_bom_component_record.uom IN ('sqm', 'area', 'm2') THEN
                -- Square meters: use area
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_area_sqm, 0);
            END IF;
            
            -- Multiply by quote line quantity
            v_component_qty := v_component_qty * COALESCE(v_quote_line_record.qty, 1);
        END IF;
        
        -- Step 3.4: Insert into QuoteLineComponents with component_role
        INSERT INTO "QuoteLineComponents" (
            organization_id,
            quote_line_id,
            catalog_item_id,
            qty,
            unit_cost_exw,
            component_role
        )
        VALUES (
            p_organization_id,
            p_quote_line_id,
            v_resolved_catalog_item_id,
            v_component_qty,
            v_bom_component_record.component_cost_exw,
            v_bom_component_record.component_role
        )
        ON CONFLICT DO NOTHING
        RETURNING id INTO v_inserted_component_id;
        
        -- Step 3.5: Track inserted component
        IF v_inserted_component_id IS NOT NULL THEN
            v_component_result := jsonb_build_object(
                'id', v_inserted_component_id,
                'catalog_item_id', v_resolved_catalog_item_id,
                'component_role', v_bom_component_record.component_role,
                'qty', v_component_qty
            );
            v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
        END IF;
    END LOOP;
    
    -- Step 4: Return result
    RETURN jsonb_build_object(
        'success', true,
        'bom_template_id', v_bom_template_record.id,
        'components', v_inserted_components
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating BOM for quote line: %', SQLERRM;
END;
$$;

-- Add comment
COMMENT ON FUNCTION public.generate_bom_for_quote_line IS 
    'Generates BOM components for a quote line by finding BOMTemplate, resolving components, and inserting into QuoteLineComponents with component_role. Returns JSONB with success status and inserted components.';

