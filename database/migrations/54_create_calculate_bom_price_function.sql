-- ====================================================
-- Migration: Create calculate_bom_price function
-- ====================================================
-- This function calculates the total cost of a product based on its BOM (Bill of Materials)
-- It takes into account dimensions (width, height, area) to calculate quantities for linear/area-based components
-- ====================================================

CREATE OR REPLACE FUNCTION calculate_bom_price(
  p_parent_item_id uuid,
  p_organization_id uuid,
  p_width_m numeric DEFAULT NULL,
  p_height_m numeric DEFAULT NULL,
  p_area_sqm numeric DEFAULT NULL
)
RETURNS TABLE (
  component_item_id uuid,
  component_sku text,
  component_name text,
  qty_needed numeric,
  uom text,
  unit_cost_exw numeric,
  extended_cost numeric,
  category_id uuid,
  category_name text,
  is_fabric boolean,
  collection_name text,
  variant_name text
) AS $$
DECLARE
  v_parent_item record;
  v_component record;
  v_calculated_qty numeric;
  v_component_cost numeric;
  v_area_calculated numeric;
BEGIN
  -- Get parent item details
  SELECT ci.*, ic.id as category_id, ic.name as category_name
  INTO v_parent_item
  FROM "CatalogItems" ci
  LEFT JOIN "ItemCategories" ic ON ci.item_category_id = ic.id
  WHERE ci.id = p_parent_item_id
    AND ci.organization_id = p_organization_id
    AND ci.deleted = false;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Parent item not found: %', p_parent_item_id;
  END IF;
  
  -- Calculate area if not provided but width and height are available
  v_area_calculated := COALESCE(p_area_sqm, 
    CASE 
      WHEN p_width_m IS NOT NULL AND p_height_m IS NOT NULL THEN p_width_m * p_height_m
      ELSE NULL
    END
  );
  
  -- Loop through BOM components
  FOR v_component IN
    SELECT 
      bom.*,
      ci.sku as component_sku,
      ci.item_name as component_name,
      ci.cost_exw as component_cost_exw,
      ci.measure_basis as component_measure_basis,
      ci.item_category_id,
      ci.is_fabric,
      ci.collection_name,
      ci.variant_name,
      ic.name as category_name
    FROM "BOMComponents" bom
    INNER JOIN "CatalogItems" ci ON bom.component_item_id = ci.id
    LEFT JOIN "ItemCategories" ic ON ci.item_category_id = ic.id
    WHERE bom.parent_item_id = p_parent_item_id
      AND bom.organization_id = p_organization_id
      AND bom.deleted = false
      AND ci.deleted = false
    ORDER BY bom.sequence_order
  LOOP
    -- Calculate quantity needed based on UOM
    v_calculated_qty := v_component.qty_per_unit;
    
    -- Handle different UOM types
    IF v_component.uom = 'm' OR v_component.uom = 'linear_m' OR v_component.uom = 'meter' THEN
      -- Linear meters: use width or height based on component type
      IF v_component.component_measure_basis = 'width_linear' THEN
        v_calculated_qty := v_component.qty_per_unit * COALESCE(p_width_m, 0);
      ELSIF v_component.component_measure_basis = 'height_linear' THEN
        v_calculated_qty := v_component.qty_per_unit * COALESCE(p_height_m, 0);
      ELSE
        -- Default: use width for linear components
        v_calculated_qty := v_component.qty_per_unit * COALESCE(p_width_m, 0);
      END IF;
      
    ELSIF v_component.uom = 'sqm' OR v_component.uom = 'area' OR v_component.uom = 'm2' THEN
      -- Square meters: use area
      v_calculated_qty := v_component.qty_per_unit * COALESCE(v_area_calculated, 0);
      
    ELSIF v_component.uom = 'unit' OR v_component.uom = 'pcs' OR v_component.uom = 'piece' THEN
      -- Units: use qty_per_unit as-is
      v_calculated_qty := v_component.qty_per_unit;
      
    ELSE
      -- Unknown UOM: default to qty_per_unit
      v_calculated_qty := v_component.qty_per_unit;
    END IF;
    
    -- Ensure non-negative quantity
    IF v_calculated_qty < 0 THEN
      v_calculated_qty := 0;
    END IF;
    
    -- Get component cost
    v_component_cost := COALESCE(v_component.component_cost_exw, 0);
    
    -- Return component details
    RETURN QUERY SELECT
      v_component.component_item_id,
      v_component.component_sku,
      v_component.component_name,
      v_calculated_qty,
      v_component.uom,
      v_component_cost,
      v_calculated_qty * v_component_cost as extended_cost,
      v_component.item_category_id,
      v_component.category_name,
      COALESCE(v_component.is_fabric, false),
      v_component.collection_name,
      v_component.variant_name;
  END LOOP;
  
  -- If no BOM components found, return empty result
  RETURN;
END;
$$ LANGUAGE plpgsql;

-- Add comments
COMMENT ON FUNCTION calculate_bom_price IS 'Calculates the total cost of a product based on its BOM components. Takes dimensions (width, height, area) to calculate quantities for linear/area-based components. Returns component details with calculated quantities and costs.';

-- ====================================================
-- Verification
-- ====================================================
-- Test the function with:
-- SELECT * FROM calculate_bom_price(
--   'parent-item-uuid'::uuid,
--   2.0,  -- width_m
--   1.5,  -- height_m
--   NULL, -- area_sqm (will be calculated)
--   'organization-uuid'::uuid
-- );

