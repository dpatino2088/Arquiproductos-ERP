-- ====================================================
-- TEST: Ejecutar engineering rules en un solo BomInstance
-- ====================================================
-- Este script prueba la función en un BomInstance específico con logging detallado
-- ====================================================

DO $$
DECLARE
    v_test_bom_instance_id uuid;
    v_bom_instance RECORD;
    v_sale_order_line RECORD;
    v_template RECORD;
    v_quote_line RECORD;
    v_bom_line RECORD;
    v_width_m numeric;
    v_height_m numeric;
    v_rules_count integer;
    v_bom_lines_count integer;
BEGIN
    -- Get first BomInstance with bom_template_id that has null cut_length_mm
    SELECT bi.id INTO v_test_bom_instance_id
    FROM "BomInstances" bi
    INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
    WHERE bi.deleted = false
    AND bi.bom_template_id IS NOT NULL
    AND bil.deleted = false
    AND bil.part_role IN ('tube', 'bottom_rail_profile')
    AND bil.cut_length_mm IS NULL
    LIMIT 1;
    
    IF v_test_bom_instance_id IS NULL THEN
        RAISE NOTICE '❌ No BomInstance found to test';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Testing BomInstance: %', v_test_bom_instance_id;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Get BomInstance details
    SELECT * INTO v_bom_instance
    FROM "BomInstances"
    WHERE id = v_test_bom_instance_id;
    
    RAISE NOTICE 'BomInstance Details:';
    RAISE NOTICE '  - bom_template_id: %', v_bom_instance.bom_template_id;
    RAISE NOTICE '  - sale_order_line_id: %', v_bom_instance.sale_order_line_id;
    RAISE NOTICE '  - organization_id: %', v_bom_instance.organization_id;
    RAISE NOTICE '';
    
    -- Get SaleOrderLine
    SELECT * INTO v_sale_order_line
    FROM "SalesOrderLines"
    WHERE id = v_bom_instance.sale_order_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ SaleOrderLine not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'SaleOrderLine Details:';
    RAISE NOTICE '  - product_type_id: %', v_sale_order_line.product_type_id;
    RAISE NOTICE '  - width_m: %', v_sale_order_line.width_m;
    RAISE NOTICE '  - height_m: %', v_sale_order_line.height_m;
    RAISE NOTICE '  - quote_line_id: %', v_sale_order_line.quote_line_id;
    RAISE NOTICE '';
    
    -- Get QuoteLine for dimensions
    SELECT * INTO v_quote_line
    FROM "QuoteLines"
    WHERE id = v_sale_order_line.quote_line_id
    AND deleted = false;
    
    IF FOUND THEN
        v_width_m := COALESCE(v_quote_line.width_m, v_sale_order_line.width_m);
        v_height_m := COALESCE(v_quote_line.height_m, v_sale_order_line.height_m);
        RAISE NOTICE 'QuoteLine Dimensions:';
        RAISE NOTICE '  - width_m: %', v_width_m;
        RAISE NOTICE '  - height_m: %', v_height_m;
    ELSE
        v_width_m := v_sale_order_line.width_m;
        v_height_m := v_sale_order_line.height_m;
        RAISE NOTICE '⚠️  QuoteLine not found, using SaleOrderLine dimensions';
        RAISE NOTICE '  - width_m: %', v_width_m;
        RAISE NOTICE '  - height_m: %', v_height_m;
    END IF;
    
    RAISE NOTICE '';
    
    -- Get Template details
    SELECT * INTO v_template
    FROM "BOMTemplates"
    WHERE id = v_bom_instance.bom_template_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ BOM Template not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'BOM Template Details:';
    RAISE NOTICE '  - name: %', v_template.name;
    RAISE NOTICE '  - product_type_id: %', v_template.product_type_id;
    RAISE NOTICE '  - active: %', v_template.active;
    RAISE NOTICE '';
    
    -- Count engineering rules
    SELECT COUNT(*) INTO v_rules_count
    FROM "BOMComponents" bc
    WHERE bc.bom_template_id = v_bom_instance.bom_template_id
    AND bc.deleted = false
    AND bc.affects_role IS NOT NULL
    AND bc.cut_axis IS NOT NULL
    AND bc.cut_axis != 'none'
    AND bc.cut_delta_mm IS NOT NULL;
    
    RAISE NOTICE 'Engineering Rules:';
    RAISE NOTICE '  - Count: %', v_rules_count;
    RAISE NOTICE '';
    
    -- Count BomInstanceLines that need calculation
    SELECT COUNT(*) INTO v_bom_lines_count
    FROM "BomInstanceLines" bil
    WHERE bil.bom_instance_id = v_test_bom_instance_id
    AND bil.deleted = false
    AND bil.part_role IN ('tube', 'bottom_rail_profile')
    AND bil.cut_length_mm IS NULL;
    
    RAISE NOTICE 'BomInstanceLines to process:';
    RAISE NOTICE '  - Count: %', v_bom_lines_count;
    RAISE NOTICE '';
    
    -- Show current state BEFORE
    RAISE NOTICE 'Current state (BEFORE):';
    FOR v_bom_line IN
        SELECT bil.id, bil.part_role, bil.cut_length_mm
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = v_test_bom_instance_id
        AND bil.deleted = false
        AND bil.part_role IN ('tube', 'bottom_rail_profile')
        LIMIT 10
    LOOP
        RAISE NOTICE '  - Line ID: %, part_role: %, cut_length_mm: %', 
            v_bom_line.id,
            v_bom_line.part_role,
            v_bom_line.cut_length_mm;
    END LOOP;
    
    -- Try to execute the function
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Executing apply_engineering_rules_to_bom_instance...';
    RAISE NOTICE '========================================';
    
    BEGIN
        PERFORM public.apply_engineering_rules_to_bom_instance(v_test_bom_instance_id);
        RAISE NOTICE '✅ Function executed without errors';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error executing function: %', SQLERRM;
            RAISE WARNING 'Error detail: %', SQLSTATE;
    END;
    
    -- Show state AFTER
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Current state (AFTER):';
    RAISE NOTICE '========================================';
    FOR v_bom_line IN
        SELECT bil.id, bil.part_role, bil.cut_length_mm, bil.calc_notes
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = v_test_bom_instance_id
        AND bil.deleted = false
        AND bil.part_role IN ('tube', 'bottom_rail_profile')
        LIMIT 10
    LOOP
        RAISE NOTICE '  - Line ID: %, part_role: %, cut_length_mm: %, calc_notes: %', 
            v_bom_line.id,
            v_bom_line.part_role,
            v_bom_line.cut_length_mm,
            v_bom_line.calc_notes;
    END LOOP;
    
END $$;

