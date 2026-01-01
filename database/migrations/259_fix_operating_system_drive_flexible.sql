-- ====================================================
-- Migration 259: Fix Operating System Drive Resolver with Flexible Search
-- ====================================================
-- Updates resolve_bom_role_to_sku() to use flexible search for operating_system_drive
-- ====================================================

BEGIN;

-- Drop and recreate function with flexible operating_system_drive search
DROP FUNCTION IF EXISTS public.resolve_bom_role_to_sku CASCADE;

-- Get the current function and modify just the operating_system_drive section
DO $$
DECLARE
    v_func_sql text;
    v_old_drive_section text;
    v_new_drive_section text;
BEGIN
    -- Get function definition
    SELECT pg_get_functiondef(oid) INTO v_func_sql
    FROM pg_proc
    WHERE proname = 'resolve_bom_role_to_sku'
    AND pronamespace = 'public'::regnamespace;
    
    IF v_func_sql IS NULL THEN
        RAISE EXCEPTION 'Function resolve_bom_role_to_sku not found. Please run migration 258 first.';
    END IF;
    
    -- Define the new flexible operating_system_drive section
    v_new_drive_section := E'    -- ====================================================\n' ||
        E'    -- ROLE: operating_system_drive (FLEXIBLE SEARCH)\n' ||
        E'    -- ====================================================\n' ||
        E'    IF v_normalized_role IN (''operating_system_drive'', ''operating_system'', ''drive'') THEN\n' ||
        E'        -- Try 1: With variant and color\n' ||
        E'        IF p_operating_system_variant IS NOT NULL AND p_hardware_color IS NOT NULL THEN\n' ||
        E'            IF p_operating_system_variant ILIKE ''%standard_m%'' OR p_operating_system_variant ILIKE ''%m%'' THEN\n' ||
        E'                v_sku_pattern := ''%STANDARD%M%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            ELSIF p_operating_system_variant ILIKE ''%standard_l%'' OR p_operating_system_variant ILIKE ''%l%'' THEN\n' ||
        E'                v_sku_pattern := ''%STANDARD%L%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            ELSE\n' ||
        E'                v_sku_pattern := ''%'' || UPPER(p_operating_system_variant) || ''%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            END IF;\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'' OR item_name ILIKE ''%BELT%'')\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        -- Try 2: With variant but without color\n' ||
        E'        IF v_catalog_item_id IS NULL AND p_operating_system_variant IS NOT NULL THEN\n' ||
        E'            IF p_operating_system_variant ILIKE ''%standard_m%'' OR p_operating_system_variant ILIKE ''%m%'' THEN\n' ||
        E'                v_sku_pattern := ''%STANDARD%M%'';\n' ||
        E'            ELSIF p_operating_system_variant ILIKE ''%standard_l%'' OR p_operating_system_variant ILIKE ''%l%'' THEN\n' ||
        E'                v_sku_pattern := ''%STANDARD%L%'';\n' ||
        E'            ELSE\n' ||
        E'                v_sku_pattern := ''%'' || UPPER(p_operating_system_variant) || ''%'';\n' ||
        E'            END IF;\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'' OR item_name ILIKE ''%BELT%'')\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        -- Try 3: With color but without variant\n' ||
        E'        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN\n' ||
        E'            v_sku_pattern := ''%DRIVE%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'' OR item_name ILIKE ''%BELT%'')\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        -- Try 4: Generic drive search\n' ||
        E'        IF v_catalog_item_id IS NULL THEN\n' ||
        E'            v_sku_pattern := ''%DRIVE%'';\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern OR sku ILIKE ''%BELT%'' OR item_name ILIKE ''%BELT%'')\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 WHEN sku ILIKE ''%BELT%'' THEN 1 ELSE 2 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        IF v_catalog_item_id IS NOT NULL THEN\n' ||
        E'            RAISE NOTICE ''  ✅ Resolved operating_system_drive to SKU: %'', v_catalog_item_id;\n' ||
        E'            RETURN v_catalog_item_id;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        RAISE WARNING ''⚠️ Could not resolve operating_system_drive SKU for variant: %'', p_operating_system_variant;\n' ||
        E'        RETURN NULL;\n' ||
        E'    END IF;';
    
    -- Replace the old operating_system_drive section
    -- Find the section from "ROLE: operating_system_drive" to the END IF that closes it
    v_func_sql := regexp_replace(
        v_func_sql,
        E'-- ====================================================\\s*-- ROLE: operating_system_drive\\s*-- ====================================================\\s*IF v_normalized_role IN.*?END IF;',
        v_new_drive_section,
        'gs'
    );
    
    -- If regex didn't work, try a simpler replacement
    IF v_func_sql NOT LIKE '%Try 1: With variant and color%' THEN
        -- Try replacing just the IF block content
        v_func_sql := replace(v_func_sql,
            E'        IF p_operating_system_variant IS NOT NULL THEN\n' ||
            E'            IF p_operating_system_variant ILIKE ''%standard_m%'' OR p_operating_system_variant ILIKE ''%m%'' THEN\n' ||
            E'                v_sku_pattern := ''%STANDARD%M%'';\n' ||
            E'            ELSIF p_operating_system_variant ILIKE ''%standard_l%'' OR p_operating_system_variant ILIKE ''%l%'' THEN\n' ||
            E'                v_sku_pattern := ''%STANDARD%L%'';\n' ||
            E'            ELSE\n' ||
            E'                v_sku_pattern := ''%'' || UPPER(p_operating_system_variant) || ''%'';\n' ||
            E'            END IF;\n' ||
            E'        ELSE\n' ||
            E'            v_sku_pattern := ''%STANDARD%M%'';\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        IF p_hardware_color IS NOT NULL THEN\n' ||
            E'            v_sku_pattern := v_sku_pattern || ''%'' || UPPER(p_hardware_color) || ''%'';\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        SELECT id INTO v_catalog_item_id\n' ||
            E'        FROM "CatalogItems"\n' ||
            E'        WHERE organization_id = p_organization_id\n' ||
            E'            AND deleted = false\n' ||
            E'            AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
            E'            AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'')\n' ||
            E'            AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
            E'            AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
            E'        ORDER BY \n' ||
            E'            CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
            E'            created_at DESC\n' ||
            E'        LIMIT 1;\n' ||
            E'        \n' ||
            E'        IF v_catalog_item_id IS NOT NULL THEN\n' ||
            E'            RAISE NOTICE ''  ✅ Resolved operating_system_drive to SKU: %'', v_catalog_item_id;\n' ||
            E'            RETURN v_catalog_item_id;\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        RAISE WARNING ''⚠️ Could not resolve operating_system_drive SKU for variant: %'', p_operating_system_variant;\n' ||
            E'        RETURN NULL;',
            -- Replace with flexible search
            E'        -- Try 1: With variant and color\n' ||
            E'        IF p_operating_system_variant IS NOT NULL AND p_hardware_color IS NOT NULL THEN\n' ||
            E'            IF p_operating_system_variant ILIKE ''%standard_m%'' OR p_operating_system_variant ILIKE ''%m%'' THEN\n' ||
            E'                v_sku_pattern := ''%STANDARD%M%'' || UPPER(p_hardware_color) || ''%'';\n' ||
            E'            ELSIF p_operating_system_variant ILIKE ''%standard_l%'' OR p_operating_system_variant ILIKE ''%l%'' THEN\n' ||
            E'                v_sku_pattern := ''%STANDARD%L%'' || UPPER(p_hardware_color) || ''%'';\n' ||
            E'            ELSE\n' ||
            E'                v_sku_pattern := ''%'' || UPPER(p_operating_system_variant) || ''%'' || UPPER(p_hardware_color) || ''%'';\n' ||
            E'            END IF;\n' ||
            E'            \n' ||
            E'            SELECT id INTO v_catalog_item_id\n' ||
            E'            FROM "CatalogItems"\n' ||
            E'            WHERE organization_id = p_organization_id\n' ||
            E'                AND deleted = false\n' ||
            E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
            E'                AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'' OR item_name ILIKE ''%BELT%'')\n' ||
            E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
            E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
            E'            ORDER BY \n' ||
            E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
            E'                created_at DESC\n' ||
            E'            LIMIT 1;\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        -- Try 2: With variant but without color\n' ||
            E'        IF v_catalog_item_id IS NULL AND p_operating_system_variant IS NOT NULL THEN\n' ||
            E'            IF p_operating_system_variant ILIKE ''%standard_m%'' OR p_operating_system_variant ILIKE ''%m%'' THEN\n' ||
            E'                v_sku_pattern := ''%STANDARD%M%'';\n' ||
            E'            ELSIF p_operating_system_variant ILIKE ''%standard_l%'' OR p_operating_system_variant ILIKE ''%l%'' THEN\n' ||
            E'                v_sku_pattern := ''%STANDARD%L%'';\n' ||
            E'            ELSE\n' ||
            E'                v_sku_pattern := ''%'' || UPPER(p_operating_system_variant) || ''%'';\n' ||
            E'            END IF;\n' ||
            E'            \n' ||
            E'            SELECT id INTO v_catalog_item_id\n' ||
            E'            FROM "CatalogItems"\n' ||
            E'            WHERE organization_id = p_organization_id\n' ||
            E'                AND deleted = false\n' ||
            E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
            E'                AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'' OR item_name ILIKE ''%BELT%'')\n' ||
            E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
            E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
            E'            ORDER BY \n' ||
            E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
            E'                created_at DESC\n' ||
            E'            LIMIT 1;\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        -- Try 3: With color but without variant\n' ||
            E'        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN\n' ||
            E'            v_sku_pattern := ''%DRIVE%'' || UPPER(p_hardware_color) || ''%'';\n' ||
            E'            \n' ||
            E'            SELECT id INTO v_catalog_item_id\n' ||
            E'            FROM "CatalogItems"\n' ||
            E'            WHERE organization_id = p_organization_id\n' ||
            E'                AND deleted = false\n' ||
            E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
            E'                AND (sku ILIKE ''%DRIVE%'' OR sku ILIKE ''%OPERATING%SYSTEM%'' OR item_name ILIKE ''%DRIVE%'' OR item_name ILIKE ''%BELT%'')\n' ||
            E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
            E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
            E'            ORDER BY \n' ||
            E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 ELSE 1 END,\n' ||
            E'                created_at DESC\n' ||
            E'            LIMIT 1;\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        -- Try 4: Generic drive search\n' ||
            E'        IF v_catalog_item_id IS NULL THEN\n' ||
            E'            v_sku_pattern := ''%DRIVE%'';\n' ||
            E'            \n' ||
            E'            SELECT id INTO v_catalog_item_id\n' ||
            E'            FROM "CatalogItems"\n' ||
            E'            WHERE organization_id = p_organization_id\n' ||
            E'                AND deleted = false\n' ||
            E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern OR sku ILIKE ''%BELT%'' OR item_name ILIKE ''%BELT%'')\n' ||
            E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
            E'                AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%CC1002%'' OR item_name ILIKE ''%CC1002%''))\n' ||
            E'            ORDER BY \n' ||
            E'                CASE WHEN sku ILIKE ''%DRIVE%'' THEN 0 WHEN sku ILIKE ''%BELT%'' THEN 1 ELSE 2 END,\n' ||
            E'                created_at DESC\n' ||
            E'            LIMIT 1;\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        IF v_catalog_item_id IS NOT NULL THEN\n' ||
            E'            RAISE NOTICE ''  ✅ Resolved operating_system_drive to SKU: %'', v_catalog_item_id;\n' ||
            E'            RETURN v_catalog_item_id;\n' ||
            E'        END IF;\n' ||
            E'        \n' ||
            E'        RAISE WARNING ''⚠️ Could not resolve operating_system_drive SKU for variant: %'', p_operating_system_variant;\n' ||
            E'        RETURN NULL;'
        );
    END IF;
    
    -- Execute the modified function
    EXECUTE v_func_sql;
    
    RAISE NOTICE '✅ Updated operating_system_drive resolver with flexible search';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to auto-update function: %', SQLERRM;
        RAISE NOTICE 'Please check if migration 258 was executed successfully.';
        RAISE;
END $$;

COMMIT;


