-- ====================================================
-- Migration 227: Create Role-to-SKU Resolver Function
-- ====================================================
-- This migration creates a deterministic resolver function that maps
-- BOM roles to concrete CatalogItems based on configuration fields
-- ====================================================

BEGIN;

-- ====================================================
-- Function: resolve_bom_role_to_sku
-- ====================================================
-- Maps a BOM role to a concrete CatalogItem based on configuration
-- 
-- Parameters:
--   p_role: The canonical BOM role (e.g., 'tube', 'bracket', 'fabric')
--   p_organization_id: Organization context
--   p_drive_type: 'manual' | 'motor'
--   p_operating_system_variant: 'standard_m' | 'standard_l' | NULL
--   p_tube_type: 'RTU-42' | 'RTU-65' | 'RTU-80' | NULL
--   p_bottom_rail_type: 'standard' | 'wrapped' | NULL
--   p_side_channel: boolean
--   p_side_channel_type: 'side_only' | 'side_and_bottom' | NULL
--   p_hardware_color: 'white' | 'black' | 'silver' | 'bronze' | NULL
--   p_cassette: boolean
--   p_cassette_type: 'standard' | 'recessed' | 'surface' | NULL
--
-- Returns: catalog_item_id (uuid) or NULL if cannot resolve
-- ====================================================
CREATE OR REPLACE FUNCTION public.resolve_bom_role_to_sku(
    p_role text,
    p_organization_id uuid,
    p_drive_type text DEFAULT NULL,
    p_operating_system_variant text DEFAULT NULL,
    p_tube_type text DEFAULT NULL,
    p_bottom_rail_type text DEFAULT NULL,
    p_side_channel boolean DEFAULT NULL,
    p_side_channel_type text DEFAULT NULL,
    p_hardware_color text DEFAULT NULL,
    p_cassette boolean DEFAULT NULL,
    p_cassette_type text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_catalog_item_id uuid;
    v_normalized_role text;
    v_sku_pattern text;
    v_resolution_notes text := '';
BEGIN
    -- Normalize role name
    v_normalized_role := LOWER(TRIM(p_role));
    
    RAISE NOTICE '🔍 Resolving role "%" with config: drive_type=%, tube_type=%, operating_system_variant=%, hardware_color=%', 
        v_normalized_role, p_drive_type, p_tube_type, p_operating_system_variant, p_hardware_color;
    
    -- ====================================================
    -- ROLE: tube
    -- ====================================================
    IF v_normalized_role = 'tube' THEN
        -- Use explicit tube_type if provided
        IF p_tube_type IS NOT NULL THEN
            -- Normalize tube_type (RTU-42, RTU-65, RTU-80)
            IF p_tube_type ILIKE '%42%' OR p_tube_type ILIKE 'RTU-42' THEN
                v_sku_pattern := '%RTU-42%';
            ELSIF p_tube_type ILIKE '%65%' OR p_tube_type ILIKE 'RTU-65' THEN
                v_sku_pattern := '%RTU-65%';
            ELSIF p_tube_type ILIKE '%80%' OR p_tube_type ILIKE 'RTU-80' THEN
                v_sku_pattern := '%RTU-80%';
            ELSE
                -- Try to extract number from tube_type
                v_sku_pattern := '%' || REPLACE(UPPER(p_tube_type), 'RTU', 'RTU') || '%';
            END IF;
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
            ORDER BY 
                CASE WHEN sku ILIKE '%TUBE%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_catalog_item_id IS NOT NULL THEN
                RAISE NOTICE '  ✅ Resolved tube to SKU: % (pattern: %)', v_catalog_item_id, v_sku_pattern;
                RETURN v_catalog_item_id;
            END IF;
        END IF;
        
        -- Fallback: try generic tube search (should not happen if tube_type is set)
        RAISE WARNING '⚠️ Could not resolve tube SKU for tube_type: %', p_tube_type;
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: bracket
    -- ====================================================
    IF v_normalized_role = 'bracket' THEN
        -- Brackets may vary by tube_type and hardware_color
        v_sku_pattern := '%BRACKET%';
        
        -- Add tube_type constraint if available
        IF p_tube_type IS NOT NULL THEN
            IF p_tube_type ILIKE '%42%' THEN
                v_sku_pattern := '%BRACKET%42%';
            ELSIF p_tube_type ILIKE '%65%' THEN
                v_sku_pattern := '%BRACKET%65%';
            ELSIF p_tube_type ILIKE '%80%' THEN
                v_sku_pattern := '%BRACKET%80%';
            END IF;
        END IF;
        
        -- Add hardware_color constraint if available
        IF p_hardware_color IS NOT NULL THEN
            v_sku_pattern := v_sku_pattern || '%' || UPPER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved bracket to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve bracket SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: operating_system_drive
    -- ====================================================
    IF v_normalized_role IN ('operating_system_drive', 'operating_system', 'drive') THEN
        -- Operating system drive varies by variant (standard_m vs standard_l)
        IF p_operating_system_variant IS NOT NULL THEN
            IF p_operating_system_variant ILIKE '%standard_m%' OR p_operating_system_variant ILIKE '%m%' THEN
                v_sku_pattern := '%STANDARD%M%';
            ELSIF p_operating_system_variant ILIKE '%standard_l%' OR p_operating_system_variant ILIKE '%l%' THEN
                v_sku_pattern := '%STANDARD%L%';
            ELSE
                v_sku_pattern := '%' || UPPER(p_operating_system_variant) || '%';
            END IF;
        ELSE
            -- Default to standard_m if not specified
            v_sku_pattern := '%STANDARD%M%';
        END IF;
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_sku_pattern := v_sku_pattern || '%' || UPPER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
            AND (sku ILIKE '%DRIVE%' OR sku ILIKE '%OPERATING%SYSTEM%' OR item_name ILIKE '%DRIVE%')
        ORDER BY 
            CASE WHEN sku ILIKE '%DRIVE%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved operating_system_drive to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve operating_system_drive SKU for variant: %', p_operating_system_variant;
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: motor (conditional on drive_type = 'motor')
    -- ====================================================
    IF v_normalized_role = 'motor' THEN
        IF p_drive_type != 'motor' THEN
            RAISE NOTICE '  ⏭️ Skipping motor (drive_type is not "motor")';
            RETURN NULL;
        END IF;
        
        -- Motor may vary by operating_system_variant
        IF p_operating_system_variant IS NOT NULL THEN
            IF p_operating_system_variant ILIKE '%standard_m%' OR p_operating_system_variant ILIKE '%m%' THEN
                v_sku_pattern := '%MOTOR%M%';
            ELSIF p_operating_system_variant ILIKE '%standard_l%' OR p_operating_system_variant ILIKE '%l%' THEN
                v_sku_pattern := '%MOTOR%L%';
            ELSE
                v_sku_pattern := '%MOTOR%' || UPPER(p_operating_system_variant) || '%';
            END IF;
        ELSE
            v_sku_pattern := '%MOTOR%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%MOTOR%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved motor to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve motor SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: motor_adapter (conditional on drive_type = 'motor')
    -- ====================================================
    IF v_normalized_role = 'motor_adapter' THEN
        IF p_drive_type != 'motor' THEN
            RAISE NOTICE '  ⏭️ Skipping motor_adapter (drive_type is not "motor")';
            RETURN NULL;
        END IF;
        
        v_sku_pattern := '%MOTOR%ADAPTER%';
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%ADAPTER%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved motor_adapter to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve motor_adapter SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: bottom_rail_profile
    -- ====================================================
    IF v_normalized_role = 'bottom_rail_profile' THEN
        -- Bottom rail profile may vary by bottom_rail_type
        IF p_bottom_rail_type IS NOT NULL THEN
            IF p_bottom_rail_type ILIKE '%standard%' THEN
                v_sku_pattern := '%BOTTOM%RAIL%PROFILE%STANDARD%';
            ELSIF p_bottom_rail_type ILIKE '%wrapped%' THEN
                v_sku_pattern := '%BOTTOM%RAIL%PROFILE%WRAPPED%';
            ELSE
                v_sku_pattern := '%BOTTOM%RAIL%PROFILE%' || UPPER(p_bottom_rail_type) || '%';
            END IF;
        ELSE
            v_sku_pattern := '%BOTTOM%RAIL%PROFILE%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%BOTTOM%RAIL%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved bottom_rail_profile to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve bottom_rail_profile SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: bottom_rail_end_cap
    -- ====================================================
    IF v_normalized_role = 'bottom_rail_end_cap' THEN
        v_sku_pattern := '%BOTTOM%RAIL%END%CAP%';
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_sku_pattern := v_sku_pattern || '%' || UPPER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%END%CAP%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved bottom_rail_end_cap to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve bottom_rail_end_cap SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: side_channel_profile (conditional on side_channel = true)
    -- ====================================================
    IF v_normalized_role = 'side_channel_profile' THEN
        IF p_side_channel != true THEN
            RAISE NOTICE '  ⏭️ Skipping side_channel_profile (side_channel is not true)';
            RETURN NULL;
        END IF;
        
        v_sku_pattern := '%SIDE%CHANNEL%PROFILE%';
        
        -- Add side_channel_type constraint if available
        IF p_side_channel_type IS NOT NULL THEN
            IF p_side_channel_type ILIKE '%side_only%' THEN
                v_sku_pattern := '%SIDE%CHANNEL%PROFILE%SIDE%';
            ELSIF p_side_channel_type ILIKE '%side_and_bottom%' THEN
                v_sku_pattern := '%SIDE%CHANNEL%PROFILE%BOTH%';
            END IF;
        END IF;
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_sku_pattern := v_sku_pattern || '%' || UPPER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%SIDE%CHANNEL%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved side_channel_profile to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve side_channel_profile SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: side_channel_end_cap (conditional on side_channel = true)
    -- ====================================================
    IF v_normalized_role = 'side_channel_end_cap' THEN
        IF p_side_channel != true THEN
            RAISE NOTICE '  ⏭️ Skipping side_channel_end_cap (side_channel is not true)';
            RETURN NULL;
        END IF;
        
        v_sku_pattern := '%SIDE%CHANNEL%END%CAP%';
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_sku_pattern := v_sku_pattern || '%' || UPPER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%END%CAP%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved side_channel_end_cap to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve side_channel_end_cap SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: fabric (generic, no configuration needed)
    -- ====================================================
    IF v_normalized_role = 'fabric' THEN
        v_sku_pattern := '%FABRIC%';
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
        ORDER BY 
            CASE WHEN sku ILIKE '%FABRIC%' THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved fabric to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve fabric SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- UNKNOWN ROLE
    -- ====================================================
    RAISE WARNING '⚠️ Unknown or unsupported role: "%"', v_normalized_role;
    RETURN NULL;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error resolving role "%" to SKU: %', v_normalized_role, SQLERRM;
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.resolve_bom_role_to_sku IS 
    'Deterministically resolves a BOM role to a concrete CatalogItem SKU based on configuration fields (tube_type, operating_system_variant, drive_type, hardware_color, etc.). Returns NULL if resolution fails. This function ensures consistent BOM generation across different configuration variants.';

COMMIT;



