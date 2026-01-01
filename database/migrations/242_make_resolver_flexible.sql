-- ====================================================
-- Migration 242: Make Role-to-SKU Resolver More Flexible
-- ====================================================
-- Updates resolve_bom_role_to_sku to handle SKUs with/without hyphens,
-- search more flexibly, and prioritize item_name when SKU doesn't match
-- ====================================================

BEGIN;

-- Drop and recreate the resolver function with flexible search
DROP FUNCTION IF EXISTS public.resolve_bom_role_to_sku CASCADE;

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
    v_item_name_pattern text;
    v_normalized_sku text;
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
                v_sku_pattern := '%RTU%42%';
                v_item_name_pattern := '%tube%42%';
            ELSIF p_tube_type ILIKE '%65%' OR p_tube_type ILIKE 'RTU-65' THEN
                v_sku_pattern := '%RTU%65%';
                v_item_name_pattern := '%tube%65%';
            ELSIF p_tube_type ILIKE '%80%' OR p_tube_type ILIKE 'RTU-80' THEN
                v_sku_pattern := '%RTU%80%';
                v_item_name_pattern := '%tube%80%';
            ELSE
                -- Try to extract number from tube_type
                v_sku_pattern := '%RTU%' || REPLACE(REPLACE(UPPER(p_tube_type), 'RTU', ''), '-', '') || '%';
                v_item_name_pattern := '%tube%' || REPLACE(REPLACE(UPPER(p_tube_type), 'RTU', ''), '-', '') || '%';
            END IF;
            
            -- Search: first try exact SKU pattern, then item_name, then flexible (without hyphens)
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (
                    sku ILIKE v_sku_pattern 
                    OR item_name ILIKE v_item_name_pattern
                    OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                    OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
                )
            ORDER BY 
                CASE WHEN sku ILIKE v_sku_pattern THEN 0 ELSE 1 END,
                CASE WHEN item_name ILIKE v_item_name_pattern THEN 0 ELSE 1 END,
                CASE WHEN sku ILIKE '%TUBE%' OR sku ILIKE '%RTU%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_catalog_item_id IS NOT NULL THEN
                RAISE NOTICE '  ✅ Resolved tube to SKU: % (pattern: %)', v_catalog_item_id, v_sku_pattern;
                RETURN v_catalog_item_id;
            END IF;
        END IF;
        
        -- Fallback: try generic tube search
        RAISE WARNING '⚠️ Could not resolve tube SKU for tube_type: %', p_tube_type;
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: bracket
    -- ====================================================
    IF v_normalized_role = 'bracket' THEN
        -- Brackets may vary by tube_type and hardware_color
        v_sku_pattern := '%BRACKET%';
        v_item_name_pattern := '%bracket%';
        
        -- Add tube_type constraint if available
        IF p_tube_type IS NOT NULL THEN
            IF p_tube_type ILIKE '%42%' THEN
                v_sku_pattern := v_sku_pattern || '%42%';
            ELSIF p_tube_type ILIKE '%65%' THEN
                v_sku_pattern := v_sku_pattern || '%65%';
            ELSIF p_tube_type ILIKE '%80%' THEN
                v_sku_pattern := v_sku_pattern || '%80%';
            END IF;
        END IF;
        
        -- Add hardware_color constraint if available
        IF p_hardware_color IS NOT NULL THEN
            v_item_name_pattern := v_item_name_pattern || '%' || LOWER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%bracket%' THEN 0 ELSE 1 END,
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
                v_item_name_pattern := '%standard%m%';
            ELSIF p_operating_system_variant ILIKE '%standard_l%' OR p_operating_system_variant ILIKE '%l%' THEN
                v_sku_pattern := '%STANDARD%L%';
                v_item_name_pattern := '%standard%l%';
            ELSE
                v_sku_pattern := '%' || UPPER(p_operating_system_variant) || '%';
                v_item_name_pattern := '%' || LOWER(p_operating_system_variant) || '%';
            END IF;
        ELSE
            -- Default to standard_m if not specified
            v_sku_pattern := '%STANDARD%M%';
            v_item_name_pattern := '%standard%m%';
        END IF;
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_item_name_pattern := v_item_name_pattern || '%' || LOWER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR (sku ILIKE '%DRIVE%' OR sku ILIKE '%OPERATING%SYSTEM%' OR item_name ILIKE '%drive%' OR item_name ILIKE '%operating%system%')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%DRIVE%' OR sku ILIKE '%OPERATING%SYSTEM%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%drive%' OR item_name ILIKE '%operating%system%' THEN 0 ELSE 1 END,
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
        
        -- Motor search: prioritize item_name (which contains "motor" or "Motor")
        -- Then try SKU patterns (CM-01, CM-02, etc.)
        v_sku_pattern := '%CM%';
        v_item_name_pattern := '%motor%';
        
        -- Add operating_system_variant constraint if available
        IF p_operating_system_variant IS NOT NULL THEN
            IF p_operating_system_variant ILIKE '%standard_m%' OR p_operating_system_variant ILIKE '%m%' THEN
                v_item_name_pattern := '%motor%m%';
            ELSIF p_operating_system_variant ILIKE '%standard_l%' OR p_operating_system_variant ILIKE '%l%' THEN
                v_item_name_pattern := '%motor%l%';
            END IF;
        END IF;
        
        -- Flexible search: item_name with "motor", or SKU starting with "CM"
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                -- Priority 1: item_name contains "motor" (case insensitive)
                item_name ILIKE v_item_name_pattern
                -- Priority 2: SKU starts with "CM" (motor SKUs)
                OR sku ILIKE 'CM%'
                -- Priority 3: Flexible - SKU or item_name with "motor" (normalized, no hyphens)
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE '%MOTOR%'
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE '%MOTOR%'
            )
        ORDER BY 
            -- Highest priority: item_name contains "motor"
            CASE WHEN item_name ILIKE '%motor%' THEN 0 ELSE 1 END,
            -- Second: SKU starts with "CM"
            CASE WHEN sku ILIKE 'CM%' THEN 0 ELSE 1 END,
            -- Third: item_name contains variant (M/L)
            CASE 
                WHEN p_operating_system_variant IS NOT NULL 
                    AND item_name ILIKE '%' || LOWER(p_operating_system_variant) || '%' 
                THEN 0 
                ELSE 1 
            END,
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
        
        -- Motor adapter: look for "adapter" or "endcap" in item_name, or specific SKU patterns
        v_sku_pattern := '%ADAPTER%';
        v_item_name_pattern := '%adapter%';
        
        -- Also search for "endcap" which might be the motor adapter
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                -- Priority 1: item_name contains "adapter" or "endcap" with "motor"
                (item_name ILIKE '%adapter%' OR item_name ILIKE '%endcap%') 
                AND item_name ILIKE '%motor%'
                -- Priority 2: SKU contains "ADAPTER" or "MOTOR"
                OR sku ILIKE '%ADAPTER%'
                OR sku ILIKE '%MOTOR%'
                -- Priority 3: Flexible search (normalized, no hyphens)
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE '%MOTOR%ADAPTER%'
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE '%ADAPTER%MOTOR%'
            )
        ORDER BY 
            -- Highest priority: item_name has both "motor" and "adapter"/"endcap"
            CASE 
                WHEN item_name ILIKE '%motor%' 
                    AND (item_name ILIKE '%adapter%' OR item_name ILIKE '%endcap%') 
                THEN 0 
                ELSE 1 
            END,
            -- Second: item_name contains "motor endcap"
            CASE WHEN item_name ILIKE '%motor%endcap%' THEN 0 ELSE 1 END,
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
                v_item_name_pattern := '%bottom%rail%profile%standard%';
            ELSIF p_bottom_rail_type ILIKE '%wrapped%' THEN
                v_sku_pattern := '%BOTTOM%RAIL%PROFILE%WRAPPED%';
                v_item_name_pattern := '%bottom%rail%profile%wrapped%';
            ELSE
                v_sku_pattern := '%BOTTOM%RAIL%PROFILE%' || UPPER(p_bottom_rail_type) || '%';
                v_item_name_pattern := '%bottom%rail%profile%' || LOWER(p_bottom_rail_type) || '%';
            END IF;
        ELSE
            v_sku_pattern := '%BOTTOM%RAIL%PROFILE%';
            v_item_name_pattern := '%bottom%rail%profile%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%BOTTOM%RAIL%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%bottom%rail%' THEN 0 ELSE 1 END,
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
        v_item_name_pattern := '%bottom%rail%end%cap%';
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_item_name_pattern := v_item_name_pattern || '%' || LOWER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%END%CAP%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%end%cap%' THEN 0 ELSE 1 END,
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
        v_item_name_pattern := '%side%channel%profile%';
        
        -- Add side_channel_type constraint if available
        IF p_side_channel_type IS NOT NULL THEN
            IF p_side_channel_type ILIKE '%side_only%' THEN
                v_item_name_pattern := '%side%channel%profile%side%';
            ELSIF p_side_channel_type ILIKE '%side_and_bottom%' THEN
                v_item_name_pattern := '%side%channel%profile%both%';
            END IF;
        END IF;
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_item_name_pattern := v_item_name_pattern || '%' || LOWER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%SIDE%CHANNEL%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%side%channel%' THEN 0 ELSE 1 END,
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
        v_item_name_pattern := '%side%channel%end%cap%';
        
        -- Add hardware_color if available
        IF p_hardware_color IS NOT NULL THEN
            v_item_name_pattern := v_item_name_pattern || '%' || LOWER(p_hardware_color) || '%';
        END IF;
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%END%CAP%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%end%cap%' THEN 0 ELSE 1 END,
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
        v_item_name_pattern := '%fabric%';
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (
                sku ILIKE v_sku_pattern 
                OR item_name ILIKE v_item_name_pattern
                OR REPLACE(REPLACE(UPPER(sku), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_sku_pattern), '-', ''), ' ', '')
                OR REPLACE(REPLACE(UPPER(item_name), '-', ''), ' ', '') LIKE REPLACE(REPLACE(UPPER(v_item_name_pattern), '-', ''), ' ', '')
            )
        ORDER BY 
            CASE WHEN sku ILIKE '%FABRIC%' THEN 0 ELSE 1 END,
            CASE WHEN item_name ILIKE '%fabric%' THEN 0 ELSE 1 END,
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
    'Deterministically resolves a BOM role to a concrete CatalogItem SKU based on configuration fields. Uses flexible search patterns that work with or without hyphens, prioritizes item_name when SKU patterns don''t match, and handles normalized comparisons. Returns NULL if resolution fails.';

COMMIT;



