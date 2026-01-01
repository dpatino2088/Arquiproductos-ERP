-- ====================================================
-- Migration 374: Fix end_cap mapping - Use COMP-HARDWARE
-- ====================================================
-- Problem: end_cap role has no mapping because end_cap items are in COMP-HARDWARE
-- but COMP-HARDWARE is already mapped to 'hardware'
-- 
-- Solution: Update get_item_category_codes_from_role to handle end_cap as a special case
-- that maps to COMP-HARDWARE (same category as hardware, but filtered by sub_role in resolution)
-- ====================================================

-- Since we can't have COMP-HARDWARE mapped to both 'hardware' and 'end_cap',
-- we'll update get_item_category_codes_from_role to return COMP-HARDWARE for 'end_cap'
-- The actual filtering by sub_role will happen in resolve_auto_select_sku

CREATE OR REPLACE FUNCTION public.get_item_category_codes_from_role(
    p_role text,
    p_sub_role text DEFAULT NULL
)
RETURNS text[]
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_category_codes text[];
BEGIN
    IF p_role IS NULL OR TRIM(p_role) = '' THEN
        RAISE EXCEPTION 'role cannot be NULL or empty';
    END IF;
    
    -- Special case: end_cap items are in COMP-HARDWARE category
    -- (same as hardware, but will be filtered by sub_role during resolution)
    IF TRIM(p_role) = 'end_cap' THEN
        SELECT ARRAY['COMP-HARDWARE'] INTO v_category_codes;
        RETURN v_category_codes;
    END IF;
    
    -- Normal case: lookup in ComponentRoleMap
    SELECT ARRAY_AGG(item_category_code ORDER BY item_category_code)
    INTO v_category_codes
    FROM public."ComponentRoleMap"
    WHERE role = TRIM(p_role)
    AND active = true
    AND (p_sub_role IS NULL OR sub_role = p_sub_role);
    
    IF v_category_codes IS NULL OR array_length(v_category_codes, 1) IS NULL THEN
        RAISE EXCEPTION 'No item_category_code(s) found for role: % (sub_role: %). Please add mapping to ComponentRoleMap table.', 
            p_role, COALESCE(p_sub_role, 'NULL');
    END IF;
    
    RETURN v_category_codes;
END;
$$;

COMMENT ON FUNCTION public.get_item_category_codes_from_role IS 
    'Gets array of ItemCategories.code values that map to a given role (and optionally sub_role). Special case: end_cap maps to COMP-HARDWARE (same as hardware, filtered by sub_role during resolution). Used by Auto-Select to resolve CatalogItems.';

