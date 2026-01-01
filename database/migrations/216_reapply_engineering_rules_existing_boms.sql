-- ====================================================
-- Migration 216: Reapply engineering rules to existing BOMs
-- ====================================================
-- This migration re-runs apply_engineering_rules_to_bom_instance
-- for all existing BomInstances that have NULL cut_length_mm
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_bom_instance RECORD;
    v_updated_count integer := 0;
    v_error_count integer := 0;
    v_remaining_null_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Reapplying engineering rules to existing BOMs';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Find all BomInstances that have BomInstanceLines with NULL cut_length_mm
    FOR v_bom_instance IN
        SELECT DISTINCT bi.id, bi.created_at
        FROM "BomInstances" bi
        INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
        WHERE bi.deleted = false
        AND bil.deleted = false
        AND bil.part_role IN ('tube', 'bottom_rail_profile')
        AND bil.cut_length_mm IS NULL
        ORDER BY bi.created_at DESC
    LOOP
        BEGIN
            -- Reapply engineering rules
            PERFORM public.apply_engineering_rules_to_bom_instance(v_bom_instance.id);
            v_updated_count := v_updated_count + 1;
            
            IF v_updated_count % 10 = 0 THEN
                RAISE NOTICE 'Processed % BomInstances...', v_updated_count;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING 'Error applying rules to BomInstance %: %', v_bom_instance.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Reapplication completed';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'BomInstances updated: %', v_updated_count;
    RAISE NOTICE 'Errors: %', v_error_count;
    
    -- Final verification count
    SELECT COUNT(DISTINCT bi.id) INTO v_remaining_null_count
    FROM "BomInstances" bi
    INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
    WHERE bi.deleted = false
    AND bil.deleted = false
    AND bil.part_role IN ('tube', 'bottom_rail_profile')
    AND bil.cut_length_mm IS NULL;
    
    RAISE NOTICE 'Remaining BomInstances with NULL cut_length_mm: %', v_remaining_null_count;
    RAISE NOTICE '';
END $$;

COMMIT;

