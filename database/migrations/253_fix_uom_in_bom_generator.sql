-- ====================================================
-- Migration 253: Fix UOM in BOM Generator Function
-- ====================================================
-- Updates generate_configured_bom_for_quote_line() to use 'mts' instead of 'm'
-- to comply with check_quote_line_components_uom_valid constraint
-- ====================================================

-- The constraint only allows: 'mts', 'yd', 'ft', 'und', 'pcs', 'ea', 'set', 'pack', 'm2', 'yd2'
-- But the function was using 'm' which is not in the allowed list

-- We'll use a simple string replacement approach to update the function
DO $$
DECLARE
    v_func_sql text;
BEGIN
    -- Get the complete function definition
    SELECT pg_get_functiondef(oid) INTO v_func_sql
    FROM pg_proc
    WHERE proname = 'generate_configured_bom_for_quote_line'
    AND pronamespace = 'public'::regnamespace;
    
    IF v_func_sql IS NULL THEN
        RAISE EXCEPTION 'Function generate_configured_bom_for_quote_line not found';
    END IF;
    
    -- Replace 'm' with 'mts' in UOM assignments (only in CASE statements)
    v_func_sql := replace(v_func_sql, 'WHEN ''tube'' THEN ''m''', 'WHEN ''tube'' THEN ''mts''');
    v_func_sql := replace(v_func_sql, 'WHEN ''bottom_rail_profile'' THEN ''m''', 'WHEN ''bottom_rail_profile'' THEN ''mts''');
    v_func_sql := replace(v_func_sql, 'WHEN ''side_channel_profile'' THEN ''m''', 'WHEN ''side_channel_profile'' THEN ''mts''');
    
    -- Update condition to also accept 'mts' (keep 'm' for backward compatibility)
    v_func_sql := replace(v_func_sql, 
        'IF v_role_uom IN (''m'', ''linear_m'', ''meter'') THEN',
        'IF v_role_uom IN (''mts'', ''m'', ''linear_m'', ''meter'') THEN');
    
    -- Execute the modified function
    EXECUTE v_func_sql;
    
    RAISE NOTICE '✅ Updated function to use ''mts'' instead of ''m'' for linear UOMs';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to auto-update function: %', SQLERRM;
        RAISE NOTICE 'Please manually update the function to use ''mts'' instead of ''m'' for tube, bottom_rail_profile, and side_channel_profile roles';
        RAISE;
END $$;
