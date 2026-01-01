-- ====================================================
-- DIAGNÓSTICO: Por qué cut_length_mm sigue siendo NULL
-- ====================================================
-- Este script ayuda a identificar por qué la función no calcula
-- ====================================================

-- 1. Verificar que la función existe y su definición
SELECT 
  p.proname,
  length(pg_get_functiondef(p.oid)::text) as definition_length
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'apply_engineering_rules_to_bom_instance'
AND n.nspname = 'public';

-- 2. Verificar un BomInstance específico y sus datos
-- Reemplaza <BOM_INSTANCE_ID> con un ID real
SELECT 
    bi.id as bom_instance_id,
    bi.bom_template_id,
    bi.sale_order_line_id,
    bi.status,
    bi.created_at
FROM "BomInstances" bi
WHERE bi.deleted = false
LIMIT 5;

-- 3. Para un BomInstance específico, verificar:
-- a) Si tiene bom_template_id
-- b) Si el template tiene engineering rules
-- c) Si tiene SaleOrderLine con dimensions
-- d) Si tiene QuoteLine con dimensions
-- (Reemplaza el bom_instance_id con uno real)
DO $$
DECLARE
    v_test_bom_instance_id uuid;
    v_bom_template_id uuid;
    v_sale_order_line_id uuid;
    v_quote_line_id uuid;
    v_has_template boolean := false;
    v_has_rules boolean := false;
    v_has_sol_dimensions boolean := false;
    v_has_ql_dimensions boolean := false;
    v_width_m numeric;
    v_height_m numeric;
BEGIN
    -- Get first BomInstance
    SELECT id, bom_template_id, sale_order_line_id INTO 
        v_test_bom_instance_id, v_bom_template_id, v_sale_order_line_id
    FROM "BomInstances"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_test_bom_instance_id IS NULL THEN
        RAISE NOTICE '❌ No BomInstances found';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Diagnóstico para BomInstance: %', v_test_bom_instance_id;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Check bom_template_id
    IF v_bom_template_id IS NOT NULL THEN
        v_has_template := true;
        RAISE NOTICE '✅ BomInstance tiene bom_template_id: %', v_bom_template_id;
        
        -- Check if template has engineering rules
        SELECT EXISTS (
            SELECT 1 FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_id
            AND bc.deleted = false
            AND bc.affects_role IS NOT NULL
            AND bc.cut_axis IS NOT NULL
            AND bc.cut_axis <> 'none'
            AND bc.cut_delta_mm IS NOT NULL
        ) INTO v_has_rules;
        
        IF v_has_rules THEN
            RAISE NOTICE '✅ Template tiene engineering rules';
        ELSE
            RAISE NOTICE '❌ Template NO tiene engineering rules';
        END IF;
    ELSE
        RAISE NOTICE '❌ BomInstance NO tiene bom_template_id';
    END IF;
    
    -- Check SaleOrderLine dimensions
    IF v_sale_order_line_id IS NOT NULL THEN
        SELECT 
            ql.id,
            COALESCE(sol.width_m, ql.width_m) as width_m,
            COALESCE(sol.height_m, ql.height_m) as height_m
        INTO v_quote_line_id, v_width_m, v_height_m
        FROM "SalesOrderLines" sol
        LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
        WHERE sol.id = v_sale_order_line_id
        AND sol.deleted = false
        LIMIT 1;
        
        IF v_width_m IS NOT NULL AND v_width_m > 0 THEN
            v_has_sol_dimensions := true;
            RAISE NOTICE '✅ SaleOrderLine tiene dimensions: width=%, height=%', v_width_m, v_height_m;
        ELSE
            RAISE NOTICE '❌ SaleOrderLine NO tiene dimensions válidas';
        END IF;
    ELSE
        RAISE NOTICE '❌ BomInstance NO tiene sale_order_line_id';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Resumen:';
    RAISE NOTICE '  - Tiene template: %', v_has_template;
    RAISE NOTICE '  - Template tiene rules: %', v_has_rules;
    RAISE NOTICE '  - Tiene dimensions: %', v_has_sol_dimensions;
    RAISE NOTICE '';
    
    -- Try to run the function manually on this instance
    IF v_has_template AND v_has_sol_dimensions THEN
        RAISE NOTICE 'Intentando ejecutar apply_engineering_rules_to_bom_instance...';
        BEGIN
            PERFORM public.apply_engineering_rules_to_bom_instance(v_test_bom_instance_id);
            RAISE NOTICE '✅ Función ejecutada sin errores';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error al ejecutar función: %', SQLERRM;
        END;
    END IF;
    
END $$;

-- 4. Verificar algunos BomInstanceLines específicos ANTES de correr la función
SELECT 
    bi.id as bom_instance_id,
    bil.id as bom_line_id,
    bil.part_role,
    bil.cut_length_mm as cut_length_before,
    bi.bom_template_id,
    bi.sale_order_line_id
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
LIMIT 5;




