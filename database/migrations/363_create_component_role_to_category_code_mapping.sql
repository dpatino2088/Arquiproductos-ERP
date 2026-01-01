-- ====================================================
-- Migration 363: Create Component Role to Category Code Mapping
-- ====================================================
-- Creates a canonical mapping table between component_role (BOM vocabulary)
-- and ItemCategories.code (real catalog codes)
-- 
-- Architecture: component_role is canonical BOM language (stable, never changes)
-- ItemCategories.code is catalog/import specific (can change with imports)
-- This mapping provides the translation layer
-- ====================================================

-- ====================================================
-- STEP 1: Create mapping table
-- ====================================================
CREATE TABLE IF NOT EXISTS public."ComponentRoleToCategoryCode" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Canonical component_role (BOM vocabulary - NEVER changes)
    component_role text NOT NULL UNIQUE,
    
    -- Real ItemCategories.code (can change with catalog imports)
    item_category_code text NOT NULL,
    
    -- Optional: description for documentation
    description text,
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid,
    
    -- Note: No FOREIGN KEY to ItemCategories.code because:
    -- 1. ItemCategories.code can change with catalog imports
    -- 2. We want the mapping to be stable even if catalog changes
    -- 3. Validation happens at runtime when resolving SKUs
    CONSTRAINT check_component_role_not_empty
        CHECK (LENGTH(TRIM(component_role)) > 0),
    CONSTRAINT check_item_category_code_not_empty
        CHECK (LENGTH(TRIM(item_category_code)) > 0)
);

COMMENT ON TABLE public."ComponentRoleToCategoryCode" IS 
    'Canonical mapping between component_role (BOM vocabulary) and ItemCategories.code (catalog codes). component_role is stable BOM language that never changes. ItemCategories.code can change with catalog imports.';

COMMENT ON COLUMN public."ComponentRoleToCategoryCode".component_role IS 
    'Canonical BOM component role (stable vocabulary: fabric, tube, bracket, etc.)';

COMMENT ON COLUMN public."ComponentRoleToCategoryCode".item_category_code IS 
    'Real ItemCategories.code used in catalog (e.g., COMP-TUBE, FABRIC, ACC)';

-- ====================================================
-- STEP 2: Create index for lookups
-- ====================================================
CREATE INDEX IF NOT EXISTS idx_component_role_to_category_code_role 
    ON public."ComponentRoleToCategoryCode"(component_role);

CREATE INDEX IF NOT EXISTS idx_component_role_to_category_code_category 
    ON public."ComponentRoleToCategoryCode"(item_category_code);

-- ====================================================
-- STEP 3: Insert canonical mappings based on real data
-- ====================================================
-- Mappings based on Query 9 results (BomInstanceLines.category_code) 
-- and Query 5 results (ItemCategories.code real values)

INSERT INTO public."ComponentRoleToCategoryCode" (component_role, item_category_code, description)
VALUES 
    -- Canonical roles from Query 9 (actually used in BomInstanceLines)
    ('fabric', 'FABRIC', 'Fabric components'),
    ('tube', 'COMP-TUBE', 'Tube components'),
    ('bracket', 'COMP-BRACKET', 'Bracket components'),
    ('bottom_channel', 'COMP-BOTTOM-RAIL', 'Bottom channel/rail components (maps to COMP-BOTTOM-RAIL)'),
    ('accessory', 'ACC', 'Accessory components')
    
ON CONFLICT (component_role) 
DO UPDATE SET
    item_category_code = EXCLUDED.item_category_code,
    description = EXCLUDED.description,
    updated_at = now();

-- Note: If you need additional canonical roles, add them here:
-- Example (uncomment and adjust as needed):
-- INSERT INTO public."ComponentRoleToCategoryCode" (component_role, item_category_code, description)
-- VALUES 
--     ('cassette', 'COMP-CASSETTE', 'Cassette components'),
--     ('side_channel', 'COMP-SIDE', 'Side channel components'),
--     ('motor', 'DRIVE-MOTORIZED', 'Motor/drive components'),
--     ('operating_system', 'DRIVE-MOTORIZED', 'Operating system/drive components'),
--     ('bottom_bar', 'COMP-BOTTOM-BAR', 'Bottom bar components')
-- ON CONFLICT (component_role) DO UPDATE SET item_category_code = EXCLUDED.item_category_code;

-- ====================================================
-- STEP 4: Helper function to get category code from component_role
-- ====================================================
CREATE OR REPLACE FUNCTION public.get_category_code_from_component_role(
    p_component_role text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_category_code text;
BEGIN
    IF p_component_role IS NULL OR TRIM(p_component_role) = '' THEN
        RAISE EXCEPTION 'component_role cannot be NULL or empty';
    END IF;
    
    SELECT item_category_code INTO v_category_code
    FROM public."ComponentRoleToCategoryCode"
    WHERE component_role = TRIM(p_component_role)
    LIMIT 1;
    
    IF v_category_code IS NULL THEN
        RAISE EXCEPTION 'No mapping found for component_role: %. Please add mapping to ComponentRoleToCategoryCode table.', p_component_role;
    END IF;
    
    RETURN v_category_code;
END;
$$;

COMMENT ON FUNCTION public.get_category_code_from_component_role IS 
    'Gets ItemCategories.code for a given canonical component_role. Raises exception if mapping not found.';

-- ====================================================
-- STEP 5: Verification query
-- ====================================================
-- Run this to verify mappings are correct
SELECT 
    m.component_role as canonical_role,
    m.item_category_code as catalog_code,
    m.description,
    COUNT(ci.id) as catalog_item_count
FROM public."ComponentRoleToCategoryCode" m
LEFT JOIN public."ItemCategories" ic ON ic.code = m.item_category_code AND ic.deleted = false
LEFT JOIN public."CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
GROUP BY m.component_role, m.item_category_code, m.description
ORDER BY m.component_role;

