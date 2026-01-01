-- ====================================================
-- Migration 256: Update BOM Generator to Pass Product Type to Resolver
-- ====================================================
-- Updates generate_configured_bom_for_quote_line() to get product_type_name
-- and pass it to resolve_bom_role_to_sku() for filtering
-- ====================================================

-- We'll use a DO block to update the function by reading and modifying it
DO $$
DECLARE
    v_func_sql text;
    v_product_type_name_var text;
BEGIN
    -- Get the function definition
    SELECT pg_get_functiondef(oid) INTO v_func_sql
    FROM pg_proc
    WHERE proname = 'generate_configured_bom_for_quote_line'
    AND pronamespace = 'public'::regnamespace;
    
    IF v_func_sql IS NULL THEN
        RAISE EXCEPTION 'Function generate_configured_bom_for_quote_line not found';
    END IF;
    
    -- Add variable declaration for product_type_name
    -- Find the DECLARE section and add the variable
    IF v_func_sql NOT LIKE '%v_product_type_name%' THEN
        v_func_sql := replace(v_func_sql, 
            'v_missing_roles text[] := ARRAY[]::text[];',
            'v_missing_roles text[] := ARRAY[]::text[];' || E'\n' || '    v_product_type_name text;');
    END IF;
    
    -- Add code to get product_type_name after Step 2 (after finding BOMTemplate)
    -- Find the line after "RAISE NOTICE '  ✅ Found BOMTemplate: %', v_bom_template_record.id;"
    IF v_func_sql NOT LIKE '%Get product type name%' THEN
        v_func_sql := replace(v_func_sql,
            'RAISE NOTICE ''  ✅ Found BOMTemplate: %'', v_bom_template_record.id;',
            'RAISE NOTICE ''  ✅ Found BOMTemplate: %'', v_bom_template_record.id;' || E'\n' || E'\n' ||
            '    -- Get product type name for filtering' || E'\n' ||
            '    SELECT pt.name INTO v_product_type_name' || E'\n' ||
            '    FROM "ProductTypes" pt' || E'\n' ||
            '    WHERE pt.id = p_product_type_id' || E'\n' ||
            '    AND pt.deleted = false' || E'\n' ||
            '    LIMIT 1;' || E'\n' ||
            '    ' || E'\n' ||
            '    IF v_product_type_name IS NOT NULL THEN' || E'\n' ||
            '        RAISE NOTICE ''  📦 Product Type: %'', v_product_type_name;' || E'\n' ||
            '    END IF;');
    END IF;
    
    -- Update the resolver call to include product_type_name
    -- Find the call to resolve_bom_role_to_sku and add the parameter
    v_func_sql := replace(v_func_sql,
        'v_resolved_catalog_item_id := public.resolve_bom_role_to_sku(' || E'\n' ||
        '            v_role,' || E'\n' ||
        '            p_organization_id,' || E'\n' ||
        '            v_quote_line_record.drive_type,' || E'\n' ||
        '            v_quote_line_record.operating_system_variant,' || E'\n' ||
        '            v_quote_line_record.tube_type,' || E'\n' ||
        '            v_quote_line_record.bottom_rail_type,' || E'\n' ||
        '            v_quote_line_record.side_channel,' || E'\n' ||
        '            v_quote_line_record.side_channel_type,' || E'\n' ||
        '            v_quote_line_record.hardware_color,' || E'\n' ||
        '            v_quote_line_record.cassette,' || E'\n' ||
        '            v_quote_line_record.cassette_type' || E'\n' ||
        '        );',
        'v_resolved_catalog_item_id := public.resolve_bom_role_to_sku(' || E'\n' ||
        '            v_role,' || E'\n' ||
        '            p_organization_id,' || E'\n' ||
        '            v_quote_line_record.drive_type,' || E'\n' ||
        '            v_quote_line_record.operating_system_variant,' || E'\n' ||
        '            v_quote_line_record.tube_type,' || E'\n' ||
        '            v_quote_line_record.bottom_rail_type,' || E'\n' ||
        '            v_quote_line_record.side_channel,' || E'\n' ||
        '            v_quote_line_record.side_channel_type,' || E'\n' ||
        '            v_quote_line_record.hardware_color,' || E'\n' ||
        '            v_quote_line_record.cassette,' || E'\n' ||
        '            v_quote_line_record.cassette_type,' || E'\n' ||
        '            v_product_type_name' || E'\n' ||
        '        );');
    
    -- Execute the modified function
    EXECUTE v_func_sql;
    
    RAISE NOTICE '✅ Updated function to pass product_type_name to resolver';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to auto-update function: %', SQLERRM;
        RAISE NOTICE 'Please manually update generate_configured_bom_for_quote_line() to:';
        RAISE NOTICE '1. Add variable: v_product_type_name text;';
        RAISE NOTICE '2. Get product type name: SELECT pt.name INTO v_product_type_name FROM "ProductTypes" pt WHERE pt.id = p_product_type_id;';
        RAISE NOTICE '3. Pass it to resolver: add v_product_type_name as last parameter to resolve_bom_role_to_sku()';
        RAISE;
END $$;

