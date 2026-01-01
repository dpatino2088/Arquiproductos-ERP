-- ====================================================
-- Migration 270: Create resolve_bom_role_to_catalog_item_id Function
-- ====================================================
-- Deterministic resolver using BomRoleSkuMapping table
-- Replaces fuzzy name searches with explicit mappings
-- ====================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.resolve_bom_role_to_catalog_item_id(
    p_product_type_id uuid,
    p_component_role text,
    p_operating_system_variant text DEFAULT NULL,
    p_tube_type text DEFAULT NULL,
    p_bottom_rail_type text DEFAULT NULL,
    p_side_channel_type text DEFAULT NULL,
    p_hardware_color text DEFAULT NULL,
    p_organization_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_catalog_item_id uuid;
    v_normalized_role text;
BEGIN
    -- Normalize role name
    v_normalized_role := LOWER(TRIM(p_component_role));
    
    RAISE NOTICE '🔍 Resolving role "%" with config: product_type_id=%, operating_system_variant=%, tube_type=%, hardware_color=%, organization_id=%', 
        v_normalized_role, p_product_type_id, p_operating_system_variant, p_tube_type, p_hardware_color, p_organization_id;
    
    -- Step 1: Find candidate mappings
    -- Prefer organization-specific mappings, then global (organization_id IS NULL)
    SELECT 
        m.catalog_item_id INTO v_catalog_item_id
    FROM "BomRoleSkuMapping" m
    WHERE m.product_type_id = p_product_type_id
        AND m.component_role = v_normalized_role
        AND m.deleted = false
        AND m.active = true
        -- Match organization (prefer org-specific, fallback to global)
        AND (m.organization_id = p_organization_id OR m.organization_id IS NULL)
        -- Match configuration fields (NULL in mapping means wildcard)
        AND (m.operating_system_variant IS NULL OR m.operating_system_variant = p_operating_system_variant)
        AND (m.tube_type IS NULL OR m.tube_type = p_tube_type)
        AND (m.bottom_rail_type IS NULL OR m.bottom_rail_type = p_bottom_rail_type)
        AND (m.side_channel_type IS NULL OR m.side_channel_type = p_side_channel_type)
        AND (m.hardware_color IS NULL OR m.hardware_color = p_hardware_color)
    ORDER BY 
        -- Prefer organization-specific over global
        CASE WHEN m.organization_id IS NOT NULL THEN 0 ELSE 1 END,
        -- Prefer more specific mappings (more non-NULL fields)
        CASE WHEN m.operating_system_variant IS NOT NULL THEN 0 ELSE 1 END +
        CASE WHEN m.tube_type IS NOT NULL THEN 0 ELSE 1 END +
        CASE WHEN m.bottom_rail_type IS NOT NULL THEN 0 ELSE 1 END +
        CASE WHEN m.side_channel_type IS NOT NULL THEN 0 ELSE 1 END +
        CASE WHEN m.hardware_color IS NOT NULL THEN 0 ELSE 1 END DESC,
        -- Lower priority number = higher priority
        m.priority ASC,
        m.created_at DESC
    LIMIT 1;
    
    -- Step 2: Validate that catalog_item_id is linked to product_type via CatalogItemProductTypes
    -- IMPORTANT: CatalogItemProductTypes has columns: catalog_item_id, product_type_id, organization_id, deleted
    IF v_catalog_item_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM "CatalogItemProductTypes" cipt
            WHERE cipt.catalog_item_id = v_catalog_item_id
                AND cipt.product_type_id = p_product_type_id
                AND (cipt.organization_id = p_organization_id OR p_organization_id IS NULL)
                AND cipt.deleted = false
        ) THEN
            RAISE WARNING '⚠️ Mapped catalog_item_id % is not linked to product_type_id % (org: %) in CatalogItemProductTypes. Treating as invalid.', 
                v_catalog_item_id, p_product_type_id, p_organization_id;
            v_catalog_item_id := NULL;
        END IF;
    END IF;
    
    -- Step 3: Return result
    IF v_catalog_item_id IS NOT NULL THEN
        RAISE NOTICE '  ✅ Resolved role "%" to catalog_item_id: %', v_normalized_role, v_catalog_item_id;
        RETURN v_catalog_item_id;
    ELSE
        RAISE WARNING '⚠️ Could not resolve role "%" to catalog_item_id', v_normalized_role;
        RETURN NULL;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error resolving role "%" to catalog_item_id: %', v_normalized_role, SQLERRM;
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.resolve_bom_role_to_catalog_item_id IS 
    'Deterministic resolver using BomRoleSkuMapping table. Returns catalog_item_id for a given role and configuration. Validates that catalog_item_id is linked to product_type via CatalogItemProductTypes. NULL values in mapping act as wildcards.';

COMMIT;

