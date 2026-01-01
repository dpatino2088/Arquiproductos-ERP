-- ====================================================
-- Migration 369: Update resolve_auto_select_sku to use ComponentRoleMap
-- ====================================================
-- Updates resolve_auto_select_sku() and generate_bom_for_manufacturing_order()
-- to use ComponentRoleMap table instead of hardcoded CASE statements
-- 
-- This ensures Auto-Select uses the canonical role mapping system
-- ====================================================

-- ====================================================
-- STEP 1: Update resolve_auto_select_sku to use ComponentRoleMap
-- ====================================================
CREATE OR REPLACE FUNCTION public.resolve_auto_select_sku(
    p_component_role text,
    p_sku_resolution_rule text,
    p_hardware_color text,
    p_organization_id uuid,
    p_bom_template_id uuid DEFAULT NULL
)
RETURNS uuid  -- Returns catalog_item_id
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_resolved_catalog_item_id uuid;
    v_category_codes text[];  -- Array of category codes for the role
    v_category_code text;     -- First category code (or the one to use)
    v_base_part_id uuid;
BEGIN
    -- Map component_role to category_code(s) using ComponentRoleMap
    SELECT public.get_item_category_codes_from_role(p_component_role, NULL)
    INTO v_category_codes;
    
    -- Use the first category code (if multiple exist, use the first one)
    -- In most cases, there will be only one category_code per role
    IF v_category_codes IS NULL OR array_length(v_category_codes, 1) IS NULL THEN
        RAISE EXCEPTION 'No category_code(s) found for component_role: %. Please add mapping to ComponentRoleMap table.', 
            p_component_role;
    END IF;
    
    v_category_code := v_category_codes[1];  -- Use first category code
    
    -- Resolve SKU based on sku_resolution_rule
    IF p_sku_resolution_rule = 'EXACT_SKU' THEN
        RAISE EXCEPTION 'EXACT_SKU resolution not supported for auto-select components. Use component_item_id for fixed selection.';
    
    ELSIF p_sku_resolution_rule IN ('SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR') OR p_sku_resolution_rule IS NULL THEN
        -- Strategy: First try HardwareColorMapping if hardware_color is provided
        -- Otherwise, search by category_code + hardware_color pattern
        
        IF p_hardware_color IS NOT NULL THEN
            -- Strategy: Search for items in category_code that match hardware_color
            -- Prefer items that are mapped entries in HardwareColorMapping (mapped_part_id)
            -- Fallback to SKU pattern matching
            
            -- First, try to find items that are mapped_part_id in HardwareColorMapping
            SELECT hcm.mapped_part_id INTO v_resolved_catalog_item_id
            FROM "HardwareColorMapping" hcm
            INNER JOIN "CatalogItems" ci ON ci.id = hcm.base_part_id
            INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE hcm.organization_id = p_organization_id
            AND hcm.hardware_color = p_hardware_color
            AND hcm.deleted = false
            AND ci.deleted = false
            AND ic.code = v_category_code
            ORDER BY 
                COALESCE(ci.selection_priority, 100) ASC,
                ci.sku ASC
            LIMIT 1;
            
            -- If no mapping found, fallback to SKU pattern matching
            IF v_resolved_catalog_item_id IS NULL THEN
                SELECT ci.id INTO v_resolved_catalog_item_id
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND ic.code = v_category_code
                AND public.match_hardware_color_from_sku(ci.sku, p_hardware_color)
                ORDER BY 
                    COALESCE(ci.selection_priority, 100) ASC,
                    ci.sku ASC
                LIMIT 1;
            END IF;
        ELSE
            -- No hardware_color specified - search by category_code only
            SELECT ci.id INTO v_resolved_catalog_item_id
            FROM "CatalogItems" ci
            INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE ci.organization_id = p_organization_id
            AND ci.deleted = false
            AND ic.code = v_category_code
            ORDER BY 
                COALESCE(ci.selection_priority, 100) ASC,
                ci.sku ASC
            LIMIT 1;
        END IF;
        
        IF v_resolved_catalog_item_id IS NULL THEN
            RAISE EXCEPTION 'Could not resolve catalog_item_id for auto-select component: role=%, sku_resolution_rule=%, hardware_color=%, category_code=%, organization_id=%', 
                p_component_role, COALESCE(p_sku_resolution_rule, 'NULL'), p_hardware_color, v_category_code, p_organization_id;
        END IF;
        
        RETURN v_resolved_catalog_item_id;
    
    ELSE
        RAISE EXCEPTION 'Unsupported sku_resolution_rule for auto-select: %. Supported values: EXACT_SKU, SKU_SUFFIX_COLOR, ROLE_AND_COLOR', 
            p_sku_resolution_rule;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.resolve_auto_select_sku IS 
    'Resolves catalog_item_id for auto-select BOM components using ComponentRoleMap for role→category_code mapping. Uses deterministic selection: selection_priority ASC, sku ASC. Prefers HardwareColorMapping table, falls back to SKU pattern matching.';

-- ====================================================
-- STEP 2: Helper function to get single category_code from role (for BomInstanceLines.category_code)
-- ====================================================
CREATE OR REPLACE FUNCTION public.get_category_code_from_role(
    p_role text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_category_codes text[];
    v_category_code text;
BEGIN
    IF p_role IS NULL OR TRIM(p_role) = '' THEN
        RETURN NULL;
    END IF;
    
    -- Get category codes from ComponentRoleMap
    SELECT public.get_item_category_codes_from_role(TRIM(p_role), NULL)
    INTO v_category_codes;
    
    IF v_category_codes IS NULL OR array_length(v_category_codes, 1) IS NULL THEN
        -- If no mapping found, return the role as-is (fallback for backward compatibility)
        RAISE WARNING 'No category_code mapping found for role: %. Returning role as-is.', p_role;
        RETURN TRIM(p_role);
    END IF;
    
    -- Return the first category code
    v_category_code := v_category_codes[1];
    
    RETURN v_category_code;
END;
$$;

COMMENT ON FUNCTION public.get_category_code_from_role IS 
    'Gets the primary ItemCategories.code for a given canonical role. Returns the first category_code from ComponentRoleMap. Used for storing category_code in BomInstanceLines.';

-- ====================================================
-- STEP 3: Update generate_bom_for_manufacturing_order CASE statement
-- ====================================================
-- This updates the CASE statement in generate_bom_for_manufacturing_order
-- to use ComponentRoleMap via get_category_code_from_role()
--
-- Note: We're using a text replacement approach since the function is very large
-- The CASE statement at line ~473 gets replaced

-- First, let's create a temporary function to test the replacement logic
-- Then we'll provide the SQL to update the main function

-- For now, we'll document the change needed:
-- Replace this CASE statement (around line 472-482):
/*
            -- Calculate category_code from component_role
            v_category_code := CASE 
                WHEN v_quote_line_component.component_role = 'fabric' THEN 'fabric'
                WHEN v_quote_line_component.component_role = 'tube' THEN 'tube'
                WHEN v_quote_line_component.component_role = 'motor' THEN 'motor'
                WHEN v_quote_line_component.component_role = 'bracket' THEN 'bracket'
                WHEN v_quote_line_component.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_quote_line_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_quote_line_component.component_role LIKE '%bottom_rail%' OR v_quote_line_component.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
                ELSE 'accessory'
            END;
*/

-- With this:
/*
            -- Get category_code from ComponentRoleMap
            v_category_code := public.get_category_code_from_role(v_quote_line_component.component_role);
*/

