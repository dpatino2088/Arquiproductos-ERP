-- ====================================================
-- Migration 263: Update Resolver to Use CatalogItemProductTypes
-- ====================================================
-- Updates resolve_bom_role_to_sku() to use CatalogItemProductTypes table
-- to filter by product_type_id instead of text patterns
-- ====================================================

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS public.resolve_bom_role_to_sku CASCADE;

-- Recreate function with CatalogItemProductTypes JOIN
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
    p_product_type_name text DEFAULT NULL,
    -- NEW: Add product_type_id parameter
    p_product_type_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_catalog_item_id uuid;
    v_normalized_role text;
    v_sku_pattern text;
BEGIN
    -- Normalize role name
    v_normalized_role := LOWER(TRIM(p_role));
    
    RAISE NOTICE '🔍 Resolving role "%" with config: drive_type=%, tube_type=%, operating_system_variant=%, hardware_color=%, product_type_id=%', 
        v_normalized_role, p_drive_type, p_tube_type, p_operating_system_variant, p_hardware_color, p_product_type_id;
    
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
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                -- Filter by product_type_id if provided
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%TUBE%' THEN 0 ELSE 1 END,
                ci.created_at DESC
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
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                ci.created_at DESC
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
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 3: With color but without tube_type
        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN
            v_sku_pattern := '%BRACKET%' || UPPER(p_hardware_color) || '%';
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 4: Generic bracket search
        IF v_catalog_item_id IS NULL THEN
            v_sku_pattern := '%BRACKET%';
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%BRACKET%' THEN 0 ELSE 1 END,
                ci.created_at DESC
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
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (ci.sku ILIKE '%DRIVE%' OR ci.sku ILIKE '%OPERATING%SYSTEM%' OR ci.item_name ILIKE '%DRIVE%' OR ci.item_name ILIKE '%BELT%')
                AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%TOOL%' OR ci.item_name ILIKE '%TOOL%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%DRIVE%' THEN 0 WHEN ci.sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                ci.created_at DESC
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
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (ci.sku ILIKE '%DRIVE%' OR ci.sku ILIKE '%OPERATING%SYSTEM%' OR ci.item_name ILIKE '%DRIVE%' OR ci.item_name ILIKE '%BELT%')
                AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%TOOL%' OR ci.item_name ILIKE '%TOOL%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%DRIVE%' THEN 0 WHEN ci.sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 3: With color but without variant
        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN
            v_sku_pattern := '%DRIVE%' || UPPER(p_hardware_color) || '%';
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
                AND (ci.sku ILIKE '%DRIVE%' OR ci.sku ILIKE '%OPERATING%SYSTEM%' OR ci.item_name ILIKE '%DRIVE%' OR ci.item_name ILIKE '%BELT%')
                AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%TOOL%' OR ci.item_name ILIKE '%TOOL%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%DRIVE%' THEN 0 WHEN ci.sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 4: Generic drive/belt search (exclude measurement tools)
        IF v_catalog_item_id IS NULL THEN
            v_sku_pattern := '%DRIVE%';
            
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern OR ci.sku ILIKE '%BELT%' OR ci.item_name ILIKE '%BELT%')
                AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%TOOL%' OR ci.item_name ILIKE '%TOOL%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.item_name ILIKE '%DRIVE%PLUG%' THEN 0 
                     WHEN ci.item_name ILIKE '%DRIVE%' THEN 1 
                     WHEN ci.item_name ILIKE '%BELT%' THEN 2 
                     ELSE 3 END,
                ci.created_at DESC
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
        
        SELECT ci.id INTO v_catalog_item_id
        FROM "CatalogItems" ci
        LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE ci.organization_id = p_organization_id
            AND ci.deleted = false
            AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
            AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
        ORDER BY 
            CASE WHEN ci.sku ILIKE '%MOTOR%' THEN 0 ELSE 1 END,
            ci.created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            RAISE NOTICE '  ✅ Resolved motor to SKU: %', v_catalog_item_id;
            RETURN v_catalog_item_id;
        END IF;
        
        RAISE WARNING '⚠️ Could not resolve motor SKU';
        RETURN NULL;
    END IF;
    
    -- ====================================================
    -- ROLE: motor_adapter (FLEXIBLE SEARCH)
    -- ====================================================
    IF v_normalized_role = 'motor_adapter' THEN
        IF p_drive_type != 'motor' THEN
            RAISE NOTICE '  ⏭️ Skipping motor_adapter (drive_type is not "motor")';
            RETURN NULL;
        END IF;
        
        -- Try 1: Look for "Bracket adapter motor" (most specific - RC3162-BK)
        SELECT ci.id INTO v_catalog_item_id
        FROM "CatalogItems" ci
        LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE ci.organization_id = p_organization_id
            AND ci.deleted = false
            AND (ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' OR ci.item_name ILIKE '%ADAPTER%MOTOR%BRACKET%')
            AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
        ORDER BY 
            CASE WHEN ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' THEN 0 ELSE 1 END,
            ci.created_at DESC
        LIMIT 1;
        
        -- Try 2: Look for any adapter with "motor" in name (flexible order)
        IF v_catalog_item_id IS NULL THEN
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.item_name ILIKE '%ADAPTER%' AND ci.item_name ILIKE '%MOTOR%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.item_name ILIKE '%MOTOR%' THEN 0 ELSE 1 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 3: Look for "Bracket adapter" (fallback - might be motor adapter)
        IF v_catalog_item_id IS NULL THEN
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.item_name ILIKE '%BRACKET%ADAPTER%' OR ci.sku ILIKE '%RC3162%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.sku ILIKE '%RC3162%' THEN 0 ELSE 1 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
        -- Try 4: Look for any adapter (last resort)
        IF v_catalog_item_id IS NULL THEN
            SELECT ci.id INTO v_catalog_item_id
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
            WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND (ci.item_name ILIKE '%ADAPTER%' OR ci.sku ILIKE '%ADAPTER%')
                AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
            ORDER BY 
                CASE WHEN ci.item_name ILIKE '%BRACKET%ADAPTER%' THEN 0 
                     WHEN ci.item_name ILIKE '%TUBE%ADAPTER%' THEN 1
                     ELSE 2 END,
                ci.created_at DESC
            LIMIT 1;
        END IF;
        
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
        
        SELECT ci.id INTO v_catalog_item_id
        FROM "CatalogItems" ci
        LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE ci.organization_id = p_organization_id
            AND ci.deleted = false
            AND (ci.sku ILIKE v_sku_pattern OR ci.item_name ILIKE v_sku_pattern)
            -- Filter by product_type_id if provided
            AND (p_product_type_id IS NULL OR cipt.product_type_id = p_product_type_id)
        ORDER BY 
            CASE WHEN ci.sku ILIKE '%FABRIC%' THEN 0 ELSE 1 END,
            ci.created_at DESC
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
    'Deterministically resolves a BOM role to a concrete CatalogItem SKU based on configuration fields. Uses CatalogItemProductTypes table to filter by product_type_id for accurate product type filtering. Includes flexible search for brackets and operating_system_drive (4 levels of fallback).';

COMMIT;

