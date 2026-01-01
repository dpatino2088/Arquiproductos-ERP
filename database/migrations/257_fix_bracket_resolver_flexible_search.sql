-- ====================================================
-- Migration 257: Fix Bracket Resolver with Flexible Search
-- ====================================================
-- Updates resolve_bom_role_to_sku() to use flexible search for brackets
-- (try specific pattern first, then fallback to more general patterns)
-- ====================================================

BEGIN;

-- Drop and recreate function with flexible bracket search
-- We'll use a simpler approach: replace the entire function
DROP FUNCTION IF EXISTS public.resolve_bom_role_to_sku CASCADE;

-- Get the current function source and modify just the bracket section
DO $$
DECLARE
    v_func_sql text;
    v_old_bracket text;
    v_new_bracket text;
BEGIN
    -- Get function definition
    SELECT pg_get_functiondef(oid) INTO v_func_sql
    FROM pg_proc
    WHERE proname = 'resolve_bom_role_to_sku'
    AND pronamespace = 'public'::regnamespace;
    
    -- If function doesn't exist, we need to recreate it from migration 255
    IF v_func_sql IS NULL THEN
        RAISE EXCEPTION 'Function resolve_bom_role_to_sku not found. Please run migration 255 first.';
    END IF;
    
    -- Define the old bracket section (what we want to replace)
    v_old_bracket := E'    IF v_normalized_role = ''bracket'' THEN\n' ||
        E'        v_sku_pattern := ''%BRACKET%'';\n' ||
        E'        \n' ||
        E'        IF p_tube_type IS NOT NULL THEN\n' ||
        E'            IF p_tube_type ILIKE ''%42%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%42%'';\n' ||
        E'            ELSIF p_tube_type ILIKE ''%65%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%65%'';\n' ||
        E'            ELSIF p_tube_type ILIKE ''%80%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%80%'';\n' ||
        E'            END IF;\n' ||
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
        E'            -- Exclude other product types\n' ||
        E'            AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'        ORDER BY \n' ||
        E'            CASE WHEN sku ILIKE ''%BRACKET%'' THEN 0 ELSE 1 END,\n' ||
        E'            created_at DESC\n' ||
        E'        LIMIT 1;\n' ||
        E'        \n' ||
        E'        IF v_catalog_item_id IS NOT NULL THEN\n' ||
        E'            RAISE NOTICE ''  ✅ Resolved bracket to SKU: %'', v_catalog_item_id;\n' ||
        E'            RETURN v_catalog_item_id;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        RAISE WARNING ''⚠️ Could not resolve bracket SKU'';\n' ||
        E'        RETURN NULL;\n' ||
        E'    END IF;';
    
    -- Define the new bracket section with flexible search
    v_new_bracket := E'    IF v_normalized_role = ''bracket'' THEN\n' ||
        E'        -- Try 1: Specific pattern with tube_type and color\n' ||
        E'        IF p_tube_type IS NOT NULL AND p_hardware_color IS NOT NULL THEN\n' ||
        E'            IF p_tube_type ILIKE ''%42%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%42%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            ELSIF p_tube_type ILIKE ''%65%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%65%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            ELSIF p_tube_type ILIKE ''%80%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%80%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            END IF;\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%BRACKET%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        -- Try 2: With tube_type but without color\n' ||
        E'        IF v_catalog_item_id IS NULL AND p_tube_type IS NOT NULL THEN\n' ||
        E'            IF p_tube_type ILIKE ''%42%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%42%'';\n' ||
        E'            ELSIF p_tube_type ILIKE ''%65%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%65%'';\n' ||
        E'            ELSIF p_tube_type ILIKE ''%80%'' THEN\n' ||
        E'                v_sku_pattern := ''%BRACKET%80%'';\n' ||
        E'            END IF;\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%BRACKET%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        -- Try 3: With color but without tube_type\n' ||
        E'        IF v_catalog_item_id IS NULL AND p_hardware_color IS NOT NULL THEN\n' ||
        E'            v_sku_pattern := ''%BRACKET%'' || UPPER(p_hardware_color) || ''%'';\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%BRACKET%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        -- Try 4: Generic bracket search\n' ||
        E'        IF v_catalog_item_id IS NULL THEN\n' ||
        E'            v_sku_pattern := ''%BRACKET%'';\n' ||
        E'            \n' ||
        E'            SELECT id INTO v_catalog_item_id\n' ||
        E'            FROM "CatalogItems"\n' ||
        E'            WHERE organization_id = p_organization_id\n' ||
        E'                AND deleted = false\n' ||
        E'                AND (sku ILIKE v_sku_pattern OR item_name ILIKE v_sku_pattern)\n' ||
        E'                AND NOT (sku ILIKE ANY(v_exclude_patterns) OR item_name ILIKE ANY(v_exclude_patterns))\n' ||
        E'            ORDER BY \n' ||
        E'                CASE WHEN sku ILIKE ''%BRACKET%'' THEN 0 ELSE 1 END,\n' ||
        E'                created_at DESC\n' ||
        E'            LIMIT 1;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        IF v_catalog_item_id IS NOT NULL THEN\n' ||
        E'            RAISE NOTICE ''  ✅ Resolved bracket to SKU: %'', v_catalog_item_id;\n' ||
        E'            RETURN v_catalog_item_id;\n' ||
        E'        END IF;\n' ||
        E'        \n' ||
        E'        RAISE WARNING ''⚠️ Could not resolve bracket SKU'';\n' ||
        E'        RETURN NULL;\n' ||
        E'    END IF;';
    
    -- Replace the old bracket section with the new one
    v_func_sql := replace(v_func_sql, v_old_bracket, v_new_bracket);
    
    -- Execute the modified function
    EXECUTE v_func_sql;
    
    RAISE NOTICE '✅ Updated bracket resolver with flexible search';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to auto-update function: %', SQLERRM;
        RAISE NOTICE 'Please check if migration 255 was executed successfully.';
        RAISE;
END $$;

COMMIT;
