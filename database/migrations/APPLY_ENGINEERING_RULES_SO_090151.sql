-- ====================================================
-- Apply Engineering Rules for SO-090151
-- ====================================================
-- This will calculate cut_length_mm and convert linear materials to meters
-- ====================================================

-- 1. Check current state before applying rules
SELECT 
    bil.id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.calc_notes
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bi.deleted = false
AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;

-- 2. Apply engineering rules and convert linear UOM
DO $$
DECLARE
    v_bom_instance_id uuid;
BEGIN
    FOR v_bom_instance_id IN
        SELECT bi.id
        FROM "BomInstances" bi
        JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        JOIN "SalesOrders" so ON so.id = sol.sale_order_id
        WHERE so.sale_order_no = 'SO-090151'
        AND so.deleted = false
        AND sol.deleted = false
        AND bi.deleted = false
    LOOP
        BEGIN
            RAISE NOTICE 'Applying engineering rules for BomInstance %', v_bom_instance_id;
            PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
            RAISE NOTICE '✅ Applied engineering rules for BomInstance %', v_bom_instance_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error applying engineering rules for BomInstance %: %', v_bom_instance_id, SQLERRM;
        END;
    END LOOP;
END $$;

-- 3. Check state after applying rules
SELECT 
    bil.id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.calc_notes
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bi.deleted = false
AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;

-- 4. Final summary
SELECT 
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(bil.id) as bom_lines_count,
    COUNT(bil.id) FILTER (WHERE bil.cut_length_mm IS NOT NULL) as lines_with_cut_length,
    COUNT(bil.id) FILTER (WHERE bil.part_role IN ('tube', 'bottom_rail_profile') AND bil.uom = 'm') as linear_in_meters
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND bi.deleted = false;



