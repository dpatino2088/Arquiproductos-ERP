-- ====================================================
-- Migration 222: Update Quote Approved Trigger to Use Linear UOM Wrapper
-- ====================================================
-- This migration updates on_quote_approved_create_operational_docs to use
-- apply_engineering_rules_and_convert_linear_uom instead of 
-- apply_engineering_rules_to_bom_instance, ensuring new BOMs from quotes
-- automatically have linear roles converted to meters.
-- ====================================================

BEGIN;

-- Simple approach: Use regexp_replace to update the function body
-- We'll update the specific line that calls apply_engineering_rules_to_bom_instance

DO $$
DECLARE
    v_function_def text;
    v_updated_def text;
BEGIN
    -- Get the function definition
    SELECT pg_get_functiondef(oid) INTO v_function_def
    FROM pg_proc p
    INNER JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
    AND p.proname = 'on_quote_approved_create_operational_docs'
    LIMIT 1;
    
    IF v_function_def IS NULL THEN
        RAISE NOTICE '⏭️  Function on_quote_approved_create_operational_docs does not exist.';
        RETURN;
    END IF;
    
    -- Replace the function call and messages
    v_updated_def := regexp_replace(
        v_function_def,
        'PERFORM public\.apply_engineering_rules_to_bom_instance\(v_bom_instance_id\);',
        'PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);',
        'g'
    );
    
    v_updated_def := regexp_replace(
        v_updated_def,
        'RAISE NOTICE ''✅ Applied engineering rules to BomInstance %'', v_bom_instance_id;',
        'RAISE NOTICE ''✅ Applied engineering rules and converted linear roles for BomInstance %'', v_bom_instance_id;',
        'g'
    );
    
    v_updated_def := regexp_replace(
        v_updated_def,
        'RAISE WARNING ''⚠️ Error applying engineering rules to BomInstance %: %'', v_bom_instance_id, SQLERRM;',
        'RAISE WARNING ''⚠️ Error applying engineering rules/conversion to BomInstance %: %'', v_bom_instance_id, SQLERRM;',
        'g'
    );
    
    -- Execute the updated function
    IF v_updated_def != v_function_def THEN
        EXECUTE v_updated_def;
        RAISE NOTICE '✅ Updated on_quote_approved_create_operational_docs to use wrapper function';
    ELSE
        RAISE NOTICE '⏭️  Function body unchanged (may already be updated)';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '⚠️ Error updating function: %', SQLERRM;
        RAISE NOTICE '   The function may need to be updated manually.';
        RAISE NOTICE '   Change: apply_engineering_rules_to_bom_instance → apply_engineering_rules_and_convert_linear_uom';
END $$;

COMMIT;

