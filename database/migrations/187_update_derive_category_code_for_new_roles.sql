-- ====================================================
-- Migration: Update derive_category_code_from_role for new BOM roles
-- ====================================================
-- This updates the function to correctly map new component_role values
-- to category_code based on the new BOM structure
-- ====================================================

CREATE OR REPLACE FUNCTION public.derive_category_code_from_role(
    p_component_role text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_component_role IS NULL THEN
        RETURN 'accessory';
    END IF;
    
    -- Case-insensitive matching
    -- Fabric
    IF LOWER(p_component_role) LIKE '%fabric%' THEN
        RETURN 'fabric';
    
    -- Tube
    ELSIF LOWER(p_component_role) LIKE '%tube%' THEN
        RETURN 'tube';
    
    -- Motor / Drive
    ELSIF LOWER(p_component_role) LIKE '%motor%' 
       OR LOWER(p_component_role) LIKE '%drive%'
       OR LOWER(p_component_role) LIKE '%operating_system_drive%' THEN
        RETURN 'motor';
    
    -- Bracket
    ELSIF LOWER(p_component_role) LIKE '%bracket%' THEN
        RETURN 'bracket';
    
    -- Cassette
    ELSIF LOWER(p_component_role) LIKE '%cassette%' THEN
        RETURN 'cassette';
    
    -- Side Channel (includes side_channel_profile, side_channel_cover, etc.)
    ELSIF LOWER(p_component_role) LIKE '%side_channel%' 
       OR LOWER(p_component_role) LIKE '%side channel%' THEN
        RETURN 'side_channel';
    
    -- Bottom Rail / Bottom Channel (includes bottom_rail_profile, bottom_rail_end_cap, bottom_channel, etc.)
    ELSIF LOWER(p_component_role) LIKE '%bottom_rail%'
       OR LOWER(p_component_role) LIKE '%bottom rail%'
       OR LOWER(p_component_role) LIKE '%bottom_channel%'
       OR LOWER(p_component_role) LIKE '%bottom channel%' THEN
        RETURN 'bottom_channel';
    
    -- Default: accessory
    ELSE
        RETURN 'accessory';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.derive_category_code_from_role IS 
    'Derives category_code from component_role using pattern matching. Maps new BOM roles: bottom_rail_profile, bottom_rail_end_cap, side_channel_profile, side_channel_cover, etc.';








