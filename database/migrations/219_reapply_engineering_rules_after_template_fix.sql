-- ====================================================
-- Migration 219: Reapply engineering rules after fixing bom_template_id
-- ====================================================
-- After fixing bom_template_id in BomInstances, reapply engineering rules
-- to calculate cut dimensions for all affected BomInstanceLines
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_bom_instance RECORD;
    v_processed_count integer := 0;
    v_error_count integer := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Reapplying engineering rules to BomInstances';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Process each BomInstance that now has a bom_template_id
    FOR v_bom_instance IN
        SELECT DISTINCT bi.id, bi.created_at
        FROM "BomInstances" bi
        INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
        WHERE bi.deleted = false
        AND bi.bom_template_id IS NOT NULL
        AND bil.deleted = false
        AND bil.part_role IN ('tube', 'bottom_rail_profile')
        AND bil.cut_length_mm IS NULL
        ORDER BY bi.created_at
    LOOP
        BEGIN
            -- Apply engineering rules
            PERFORM public.apply_engineering_rules_to_bom_instance(v_bom_instance.id);
            v_processed_count := v_processed_count + 1;
            
            IF v_processed_count % 10 = 0 THEN
                RAISE NOTICE 'Processed % BomInstances...', v_processed_count;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING 'Error processing BomInstance %: %', v_bom_instance.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Summary:';
    RAISE NOTICE '  - Processed: %', v_processed_count;
    RAISE NOTICE '  - Errors: %', v_error_count;
    RAISE NOTICE '========================================';
END $$;

-- Verify results
SELECT 
    bil.part_role,
    COUNT(*) as total_lines,
    COUNT(*) FILTER (WHERE bil.cut_length_mm IS NULL) as null_count,
    COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) as calculated_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) / NULLIF(COUNT(*), 0),
        2
    ) as percentage_calculated
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
GROUP BY bil.part_role
ORDER BY bil.part_role;

COMMIT;

