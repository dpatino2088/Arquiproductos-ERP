-- ====================================================
-- Migration 260: Recreate Resolver Complete with Flexible Search
-- ====================================================
-- Recreates resolve_bom_role_to_sku() with flexible search for
-- brackets and operating_system_drive, plus product type filtering
-- ====================================================

BEGIN;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.resolve_bom_role_to_sku CASCADE;

-- Recreate the complete function with all fixes
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
    p_cassette_type text DEFAULT NULL,
    p_product_type_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_catalog_item_id uuid;
    v_normalized_role text;
    v_sku_pattern text;
    v_exclude_patterns text[] := ARRAY[]::text[];
BEGIN
    -- Normalize role name
    v_normalized_role := LOWER(TRIM(p_role));
    
    -- Build exclusion patterns based on product type
    IF p_product_type_name IS NOT NULL THEN
        IF p_product_type_name ILIKE '%roller%shade%' THEN
            v_exclude_patterns := ARRAY['%DRAPERY%', '%DRAPER%', '%DUAL%SHADE%', '%DUALSHADE%', 'DRF%'];
        ELSIF p_product_type_name ILIKE '%drapery%' OR p_product_type_name ILIKE '%draper%' THEN
            v_exclude_patterns := ARRAY['%ROLLER%SHADE%', '%ROLLERSHADE%', '%DUAL%SHADE%', '%DUALSHADE%'];
        ELSIF p_product_type_name ILIKE '%dual%shade%' OR p_product_type_name ILIKE '%dualshade%' THEN
            v_exclude_patterns := ARRAY['%ROLLER%SHADE%', '%ROLLERSHADE%', '%DRAPERY%', '%DRAPER%'];
        END IF;
    END IF;
    
    RAISE NOTICE '🔍 Resolving role "%" with config: drive_type=%, tube_type=%, operating_system_variant=%, hardware_color=%, product_type=%, exclude_patterns=%', 
        v_normalized_role, p_drive_type, p_tube_type, p_operating_system_variant, p_hardware_color, p_product_type_name, v_exclude_patterns;
    
    -- ====================================================
    -- ROLE: tube
    -- ====================================================
    IF v_normalized_role = 'tube' THEN
        IF p_tube_type IS NOT NULL THEN
            IF p_tube_type ILIKE '%42%' OR p_tube_type ILIKE 'RTU-42' THEN
                v_sku_pattern := '%RTU-42%';
            ELSIF p_tube_type ILIKE '%65%' OR p_tube_type ILIKE 'RTU-65' THEN
                v_sku_pattern := '%RTU-65%';
            ELSIF p_tube_type ILIKE '%80%' OR p_tube_type ILIKE 'RTU-80' THEN
                v_sku_pattern := '%RTU-80%';
            ELSE
                v_sku_pattern := '%' || REPLACE(UPPER(p_tube_type), 'RTU', 'RTU') || '%';
            END IF;
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            ORDER BY 
                CASE WHEN sku ILIKE '%TUBE%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_catalog_item_id IS NOT NULL THEN
                RAISE NOTICE '  ✅ Resolved tube to SKU: % (pattern: %)', v_catalog_item_id, v_sku_pattern;
                RETURN v_catalog_item_id;
            END IF;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve tube SKU for tube_type: %', p_tube_type;
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: bracket (FLEXIBLE SEARCH - 4 levels)
    -- ====================================================
    IF v_normalized_role = 'bracket' THEN
        -- Try 1: Specific pattern with tube_type and color
        IF p_tube_type IS NOT NULL AND p_hardware_color IS NOT NULL THEN
            IF p_tube_type ILIKE '%42%' THEN
                v_sku_pattern := '%BRACKET%42%' || UPPER(p_hardware_color) || '%';
            ELSIF p_tube_type ILIKE '%65%' THEN
                v_sku_pattern := '%BRACKET%65%' || UPPER(p_hardware_color) || '%';
            ELSIF p_tube_type ILIKE '%80%' THEN
                v_sku_pattern := '%BRACKET%80%' || UPPER(p_hardware_color) || '%';
            END IF;
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            ORDER BY 
                CASE WHEN sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 2: With tube_type but without color
        IF v_catalog_item_id IS NULL AND p_tube_type IS NOT NULL THEN
            IF p_tube_type ILIKE '%42%' THEN
                v_sku_pattern := '%BRACKET%42%';
            ELSIF p_tube_type ILIKE '%65%' THEN
                v_sku_pattern := '%BRACKET%65%';
            ELSIF p_tube_type ILIKE '%80%' THEN
                v_sku_pattern := '%BRACKET%80%';
            END IF;
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            ORDER BY 
                CASE WHEN sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 3: With color but without tube_type
        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN
            v_sku_pattern := '%BRACKET%' || UPPER(p_hardware_color) || '%';
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            ORDER BY 
                CASE WHEN sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 4: Generic bracket search
        IF v_catalog_item_id IS NULL THEN
            v_sku_pattern := '%BRACKET%';
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            ORDER BY 
                CASE WHEN sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved bracket to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve bracket SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: operating_system_drive (FLEXIBLE SEARCH - 4 levels)
    -- ====================================================
    IF v_normalized_role IN ('operating_system_drive', 'operating_system', 'drive') THEN
        -- Try 1: With variant and color
        IF p_operating_system_variant IS NOT NULL AND p_hardware_color IS NOT NULL THEN
            IF p_operating_system_variant ILIKE '%standard_m%' OR p_operating_system_variant ILIKE '%m%' THEN
                v_sku_pattern := '%STANDARD%M%' || UPPER(p_hardware_color) || '%';
            ELSIF p_operating_system_variant ILIKE '%standard_l%' OR p_operating_system_variant ILIKE '%l%' THEN
                v_sku_pattern := '%STANDARD%L%' || UPPER(p_hardware_color) || '%';
            ELSE
                v_sku_pattern := '%' || UPPER(p_operating_system_variant) || '%' || UPPER(p_hardware_color) || '%';
            END IF;
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND (sku ILIKE '%DRIVE%' OR sku ILIKE '%OPERATING%SYSTEM%' OR item_name ILIKE '%DRIVE%' OR item_name ILIKE '%BELT%')
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
                AND NOT (p_product_type_name ILIKE '%roller%shade%' AND (sku ILIKE '%CC1002%' OR item_name ILIKE '%CC1002%'))
            ORDER BY 
                CASE WHEN sku ILIKE '%DRIVE%' THEN 0 WHEN sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 2: With variant but without color
        IF v_catalog_item_id IS NULL AND p_operating_system_variant IS NOT NULL THEN
            IF p_operating_system_variant ILIKE '%standard_m%' OR p_operating_system_variant ILIKE '%m%' THEN
                v_sku_pattern := '%STANDARD%M%';
            ELSIF p_operating_system_variant ILIKE '%standard_l%' OR p_operating_system_variant ILIKE '%l%' THEN
                v_sku_pattern := '%STANDARD%L%';
            ELSE
                v_sku_pattern := '%' || UPPER(p_operating_system_variant) || '%';
            END IF;
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND (sku ILIKE '%DRIVE%' OR sku ILIKE '%OPERATING%SYSTEM%' OR item_name ILIKE '%DRIVE%' OR item_name ILIKE '%BELT%')
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
                AND NOT (p_product_type_name ILIKE '%roller%shade%' AND (sku ILIKE '%CC1002%' OR item_name ILIKE '%CC1002%'))
            ORDER BY 
                CASE WHEN sku ILIKE '%DRIVE%' THEN 0 WHEN sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 3: With color but without variant
        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN
            v_sku_pattern := '%DRIVE%' || UPPER(p_hardware_color) || '%';
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
                AND (sku ILIKE '%DRIVE%' OR sku ILIKE '%OPERATING%SYSTEM%' OR item_name ILIKE '%DRIVE%' OR item_name ILIKE '%BELT%')
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
                AND NOT (p_product_type_name ILIKE '%roller%shade%' AND (sku ILIKE '%CC1002%' OR item_name ILIKE '%CC1002%'))
            ORDER BY 
                CASE WHEN sku ILIKE '%DRIVE%' THEN 0 WHEN sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 4: Generic drive/belt search
        IF v_catalog_item_id IS NULL THEN
            v_sku_pattern := '%DRIVE%';
            
            SELECT id INTO v_catalog_item_id
            FROM "CatalogItems"
            WHERE organization_id = p_organization_id
                AND deleted = false
                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern OR sku ILIKE '%BELT%' OR item_name ILIKE '%BELT%')
                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
                AND NOT (p_product_type_name ILIKE '%roller%shade%' AND (sku ILIKE '%CC1002%' OR item_name ILIKE '%CC1002%'))
            ORDER BY 
                CASE WHEN sku ILIKE '%DRIVE%' THEN 0 WHEN sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                created_at DESC
            LIMIT 1;
        END IF;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved operating_system_drive to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve operating_system_drive SKU for variant: %', p_operating_system_variant;
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: motor
    -- ====================================================
    IF v_normalized_role = 'motor' THEN
        IF p_drive_type != 'motor' THEN
            RAISE NOTICE '  ⏭️ Skipping motor (drive_type is not "motor")';
            RETURN NULL;
        END IF;
        
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
            AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
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
    -- ROLE: motor_adapter
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
            AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            AND NOT (p_product_type_name ILIKE '%roller%shade%' AND (sku ILIKE '%CC1019%' OR item_name ILIKE '%CC1019%'))
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
    -- ROLE: fabric
    -- ====================================================
    IF v_normalized_role = 'fabric' THEN
        v_sku_pattern := '%FABRIC%';
        
        SELECT id INTO v_catalog_item_id
        FROM "CatalogItems"
        WHERE organization_id = p_organization_id
            AND deleted = false
            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)
            AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))
            AND NOT (p_product_type_name ILIKE '%roller%shade%' AND (sku ILIKE '%DUAL%' OR item_name ILIKE '%DUAL%' OR sku ILIKE 'DRF%' OR item_name ILIKE 'DRF%'))
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
    -- Other roles (bottom_rail_profile, side_channel_profile, etc.)
    -- Keep simple for now - can be expanded later
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
    'Deterministically resolves a BOM role to a concrete CatalogItem SKU based on configuration fields. Includes flexible search for brackets and operating_system_drive (4 levels of fallback), plus product type filtering to exclude SKUs from other product types.';

COMMIT;

