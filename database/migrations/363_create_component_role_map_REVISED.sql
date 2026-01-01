-- ====================================================
-- Migration 363 (REVISED): Create Component Role Map
-- ====================================================
-- Creates mapping table: ItemCategories.code → role (canonical) + sub_role (optional)
-- 
-- Architecture: 2-level model
-- - role: Canonical BOM vocabulary (max 15, stable, universal)
-- - sub_role: Part type/specific variant (optional, for future granularity)
-- 
-- This is the SOURCE OF TRUTH for mapping ItemCategories.code to BOM roles
-- Auto-Select uses this mapping to resolve CatalogItems
-- ====================================================

-- ====================================================
-- STEP 1: Create mapping table
-- ====================================================
CREATE TABLE IF NOT EXISTS public."ComponentRoleMap" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- ItemCategories.code (source of truth - what exists in catalog)
    item_category_code text NOT NULL UNIQUE,
    
    -- Canonical BOM role (max 15, stable vocabulary)
    role text NOT NULL,
    
    -- Optional sub-role / part type (for granularity when needed)
    sub_role text NULL,
    
    -- Status
    active boolean NOT NULL DEFAULT true,
    
    -- Optional description
    description text,
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid,
    
    -- Constraints
    CONSTRAINT check_role_not_empty
        CHECK (LENGTH(TRIM(role)) > 0),
    CONSTRAINT check_item_category_code_not_empty
        CHECK (LENGTH(TRIM(item_category_code)) > 0),
    CONSTRAINT check_role_canonical
        CHECK (role IN (
            'fabric',
            'tube',
            'bracket',
            'cassette',
            'side_channel',
            'bottom_bar',
            'bottom_rail',
            'top_rail',
            'drive_manual',
            'drive_motorized',
            'remote_control',
            'battery',
            'tool',
            'hardware',
            'accessory',
            'service',
            'window_film',
            'end_cap',
            'operating_system'
        ))
);

COMMENT ON TABLE public."ComponentRoleMap" IS 
    'Source of truth mapping: ItemCategories.code → role (canonical BOM vocabulary) + sub_role (optional). Used by Auto-Select to resolve CatalogItems. role is stable vocabulary (max 15). sub_role provides optional granularity.';

COMMENT ON COLUMN public."ComponentRoleMap".item_category_code IS 
    'ItemCategories.code (e.g., COMP-TUBE, FABRIC, ACC). This is the PRIMARY KEY - one mapping per category code.';

COMMENT ON COLUMN public."ComponentRoleMap".role IS 
    'Canonical BOM role (stable vocabulary: fabric, tube, bracket, etc.). Max 15 roles.';

COMMENT ON COLUMN public."ComponentRoleMap".sub_role IS 
    'Optional sub-role / part type for granularity (e.g., tube_42mm, chain). NULL by default.';

COMMENT ON COLUMN public."ComponentRoleMap".active IS 
    'Whether this mapping is active. Inactive mappings are ignored by Auto-Select.';

-- ====================================================
-- STEP 2: Create indexes
-- ====================================================
CREATE INDEX IF NOT EXISTS idx_component_role_map_role 
    ON public."ComponentRoleMap"(role) WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_component_role_map_role_sub_role 
    ON public."ComponentRoleMap"(role, sub_role) WHERE active = true AND sub_role IS NOT NULL;

-- ====================================================
-- STEP 3: Insert initial mappings based on real ItemCategories
-- ====================================================
-- Based on Query 5 results: ItemCategories.code values that exist
-- Note: Includes codes with catalog_item_count = 0 (they exist, just not populated yet)

INSERT INTO public."ComponentRoleMap" (item_category_code, role, sub_role, description, active)
VALUES 
    -- Core BOM components
    ('FABRIC', 'fabric', NULL, 'Fabric components', true),
    ('COMP-TUBE', 'tube', NULL, 'Tube components', true),
    ('COMP-BRACKET', 'bracket', NULL, 'Bracket components', true),
    ('COMP-CASSETTE', 'cassette', NULL, 'Cassette components', true),
    ('COMP-SIDE', 'side_channel', NULL, 'Side channel components', true),
    ('COMP-BOTTOM-BAR', 'bottom_bar', NULL, 'Bottom bar components', true),
    ('COMP-BOTTOM-RAIL', 'bottom_rail', NULL, 'Bottom rail components (even if count=0)', true),
    ('COMP-TOP-RAIL', 'top_rail', NULL, 'Top rail components (even if count=0)', true),
    
    -- Drive/Control components
    ('DRIVE-MANUAL', 'drive_manual', NULL, 'Manual drive components', true),
    ('DRIVE-MOTORIZED', 'drive_motorized', NULL, 'Motorized drive components', true),
    ('COMP-CHAIN', 'drive_manual', 'chain', 'Chain components (sub-role: chain)', true),
    
    -- Accessories
    ('ACC', 'accessory', NULL, 'General accessory components', true),
    ('ACC-REMOTE-CONTROL', 'remote_control', NULL, 'Remote control accessories', true),
    ('ACC-BATTERY', 'battery', NULL, 'Battery accessories', true),
    ('ACC-TOOL', 'tool', NULL, 'Tool accessories', true),
    
    -- Hardware/Misc (with sub_roles for granularity)
    -- Note: COMP-HARDWARE maps to role='hardware' with sub_role=NULL (generic)
    -- The UI supports sub_roles: fastener, end_cap, adapter (these help filter/classify within COMP-HARDWARE)
    ('COMP-HARDWARE', 'hardware', NULL, 'Hardware components (generic - sub_roles: fastener, end_cap, adapter)', true),
    
    -- Service/Non-BOM (optional, for future)
    ('SERVICE', 'service', NULL, 'Service items (not physical BOM)', true),
    ('WINDOW-FILM', 'window_film', NULL, 'Window film (future, not hardware BOM)', true)
    
ON CONFLICT (item_category_code) 
DO UPDATE SET
    role = EXCLUDED.role,
    sub_role = EXCLUDED.sub_role,
    description = EXCLUDED.description,
    active = EXCLUDED.active,
    updated_at = now();

-- ====================================================
-- STEP 4: Helper function to get role(s) from item_category_code
-- ====================================================
CREATE OR REPLACE FUNCTION public.get_role_from_item_category_code(
    p_item_category_code text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_role text;
BEGIN
    IF p_item_category_code IS NULL OR TRIM(p_item_category_code) = '' THEN
        RAISE EXCEPTION 'item_category_code cannot be NULL or empty';
    END IF;
    
    SELECT role INTO v_role
    FROM public."ComponentRoleMap"
    WHERE item_category_code = TRIM(p_item_category_code)
    AND active = true
    LIMIT 1;
    
    IF v_role IS NULL THEN
        RAISE EXCEPTION 'No mapping found for item_category_code: %. Please add mapping to ComponentRoleMap table.', p_item_category_code;
    END IF;
    
    RETURN v_role;
END;
$$;

COMMENT ON FUNCTION public.get_role_from_item_category_code IS 
    'Gets canonical role for a given ItemCategories.code. Raises exception if mapping not found.';

-- ====================================================
-- STEP 5: Helper function to get item_category_code(s) from role
-- ====================================================
-- Returns array of item_category_codes that map to the given role (and optionally sub_role)
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
    'Gets array of ItemCategories.code values that map to a given role (and optionally sub_role). Used by Auto-Select to resolve CatalogItems.';

-- ====================================================
-- STEP 6: Verification query
-- ====================================================
-- Run this to verify mappings are correct
SELECT 
    m.item_category_code,
    m.role,
    m.sub_role,
    m.description,
    m.active,
    COUNT(ci.id) as catalog_item_count
FROM public."ComponentRoleMap" m
LEFT JOIN public."ItemCategories" ic ON ic.code = m.item_category_code AND ic.deleted = false
LEFT JOIN public."CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
GROUP BY m.item_category_code, m.role, m.sub_role, m.description, m.active
ORDER BY m.role, m.item_category_code;

