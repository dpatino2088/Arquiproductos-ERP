-- ====================================================
-- Migration 359: Test Query for Auto-Select BOM Generation
-- ====================================================
-- Test query to verify auto-select BOM generation works correctly
-- ====================================================

-- Test 1: Generate BOM for a specific Manufacturing Order
-- Replace 'MO-000003' with an actual manufacturing_order_no
DO $$
DECLARE
    v_manufacturing_order_id uuid;
    v_result jsonb;
BEGIN
    -- Get manufacturing_order_id (replace with actual MO number)
    SELECT mo.id INTO v_manufacturing_order_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000003'  -- CHANGE THIS TO A VALID MO NUMBER
    AND mo.deleted = false
    LIMIT 1;
    
    IF v_manufacturing_order_id IS NULL THEN
        RAISE NOTICE '❌ Manufacturing Order not found. Please update the MO number in this script.';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Testing auto-select BOM generation for Manufacturing Order: MO-000003';
    RAISE NOTICE '';
    
    -- Call the function
    SELECT public.generate_bom_for_manufacturing_order(v_manufacturing_order_id) INTO v_result;
    
    -- Display results
    RAISE NOTICE '📊 Results:';
    RAISE NOTICE '   Success: %', v_result->>'success';
    RAISE NOTICE '   BomInstances created: %', v_result->>'bom_instances_created';
    RAISE NOTICE '   BomInstanceLines created: %', v_result->>'bom_instance_lines_created';
    
    IF (v_result->>'success')::boolean = false THEN
        RAISE NOTICE '   Error: %', v_result->>'error';
    END IF;
END $$;

-- Test 2: Show BomInstanceLines created for the MO (verify auto-select components were resolved)
SELECT 
    bi.id as bom_instance_id,
    mo.manufacturing_order_no,
    sol.line_number,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.category_code,
    bil.description
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE mo.manufacturing_order_no = 'MO-000003'  -- CHANGE THIS TO MATCH TEST 1
AND bi.deleted = false
AND bil.deleted = false
ORDER BY sol.line_number, bil.part_role;

-- Test 3: Show BOMComponents with auto-select configuration
SELECT 
    bt.id as bom_template_id,
    bt.name as template_name,
    bc.id as component_id,
    bc.component_role,
    bc.auto_select,
    bc.component_item_id,
    bc.qty_type,
    bc.qty_value,
    bc.qty_per_unit,
    bc.hardware_color,
    bc.sku_resolution_rule,
    bc.block_condition,
    bc.applies_color,
    CASE 
        WHEN bc.component_item_id IS NULL THEN 'AUTO-SELECT'
        ELSE 'FIXED'
    END as selection_mode
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
AND bc.deleted = false
AND (bc.auto_select = true OR bc.component_item_id IS NULL)
ORDER BY bt.name, bc.sequence_order;

-- Test 4: Verify resolve_auto_select_sku function works
-- (This is a standalone test - adjust parameters as needed)
DO $$
DECLARE
    v_resolved_id uuid;
    v_test_role text := 'bracket';
    v_test_rule text := 'ROLE_AND_COLOR';
    v_test_color text := 'white';
    v_test_org_id uuid;
BEGIN
    -- Get a test organization_id (replace with actual org)
    SELECT id INTO v_test_org_id
    FROM "Organizations"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_test_org_id IS NULL THEN
        RAISE NOTICE '❌ No organization found for testing.';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Testing resolve_auto_select_sku function';
    RAISE NOTICE '   Parameters:';
    RAISE NOTICE '     component_role: %', v_test_role;
    RAISE NOTICE '     sku_resolution_rule: %', v_test_rule;
    RAISE NOTICE '     hardware_color: %', v_test_color;
    RAISE NOTICE '     organization_id: %', v_test_org_id;
    RAISE NOTICE '';
    
    BEGIN
        v_resolved_id := public.resolve_auto_select_sku(
            p_component_role := v_test_role,
            p_sku_resolution_rule := v_test_rule,
            p_hardware_color := v_test_color,
            p_organization_id := v_test_org_id
        );
        
        RAISE NOTICE '✅ Successfully resolved catalog_item_id: %', v_resolved_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Error resolving SKU: %', SQLERRM;
    END;
END $$;

-- Test 5: Show resolved catalog item details (run after Test 4)
-- This query shows the catalog item that was resolved
-- Adjust the WHERE clause to match the catalog_item_id from Test 4
SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ci.uom,
    ic.category_code,
    ic.name as category_name
FROM "CatalogItems" ci
INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE ci.id = '00000000-0000-0000-0000-000000000000'  -- REPLACE WITH catalog_item_id FROM TEST 4
AND ci.deleted = false;
