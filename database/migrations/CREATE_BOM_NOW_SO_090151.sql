-- ====================================================
-- Create BOM for SO-090151 NOW
-- ====================================================
-- Execute this to manually create BomInstances and BomInstanceLines
-- ====================================================

-- Step 1: Create BomInstances
DO $$
DECLARE
    v_sol RECORD;
    v_bom_template_id uuid;
    v_bom_instance_id uuid;
    v_org_id uuid;
BEGIN
    -- Get organization_id from SalesOrder
    SELECT organization_id INTO v_org_id
    FROM "SalesOrders"
    WHERE sale_order_no = 'SO-090151'
    AND deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'SalesOrder SO-090151 not found';
    END IF;
    
    RAISE NOTICE 'Creating BOM for organization: %', v_org_id;
    
    -- For each SalesOrderLine
    FOR v_sol IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.product_type_id,
            sol.quote_line_id,
            so.organization_id
        FROM "SalesOrderLines" sol
        JOIN "SalesOrders" so ON so.id = sol.sale_order_id
        WHERE so.sale_order_no = 'SO-090151'
        AND so.deleted = false
        AND sol.deleted = false
    LOOP
        -- Check if BomInstance already exists
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sol.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NULL THEN
            -- Get BOMTemplate
            SELECT id INTO v_bom_template_id
            FROM "BOMTemplates"
            WHERE product_type_id = v_sol.product_type_id
            AND deleted = false
            AND active = true
            ORDER BY 
                CASE WHEN organization_id = v_org_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_bom_template_id IS NOT NULL THEN
                -- Create BomInstance
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_org_id,
                    v_sol.sale_order_line_id,
                    v_sol.quote_line_id,
                    v_bom_template_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '✅ Created BomInstance % for SalesOrderLine %', v_bom_instance_id, v_sol.sale_order_line_id;
            ELSE
                RAISE WARNING '⚠️ No BOMTemplate found for product_type_id %', v_sol.product_type_id;
            END IF;
        ELSE
            RAISE NOTICE '⏭️  BomInstance already exists: %', v_bom_instance_id;
        END IF;
    END LOOP;
END $$;

-- Step 2: Create BomInstanceLines from QuoteLineComponents
DO $$
DECLARE
    v_qlc RECORD;
    v_bom_instance_id uuid;
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_total_cost_exw numeric(12,4);
    v_category_code text;
    v_org_id uuid;
    v_sku text;
    v_item_name text;
BEGIN
    -- Get organization_id
    SELECT organization_id INTO v_org_id
    FROM "SalesOrders"
    WHERE sale_order_no = 'SO-090151'
    AND deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'SalesOrder SO-090151 not found';
    END IF;
    
    RAISE NOTICE 'Creating BomInstanceLines for organization: %', v_org_id;
    
    -- For each QuoteLineComponent
    FOR v_qlc IN
        SELECT 
            qlc.*,
            ql.id as quote_line_id,
            sol.id as sale_order_line_id,
            ci.sku,
            ci.item_name
        FROM "QuoteLineComponents" qlc
        JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
        JOIN "Quotes" q ON q.id = ql.quote_id
        JOIN "SalesOrders" so ON so.quote_id = q.id
        JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE so.sale_order_no = 'SO-090151'
        AND qlc.source = 'configured_component'
        AND qlc.deleted = false
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND sol.deleted = false
    LOOP
        -- Get BomInstance for this SalesOrderLine
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_qlc.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NOT NULL THEN
            -- Get SKU and item_name
            v_sku := COALESCE(v_qlc.sku, 'N/A');
            v_item_name := COALESCE(v_qlc.item_name, v_sku);
            
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_qlc.uom);
            
            -- Compute unit_cost_exw
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_qlc.catalog_item_id,
                v_canonical_uom,
                v_org_id
            );
            
            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                v_unit_cost_exw := COALESCE(v_qlc.unit_cost_exw, 0);
            END IF;
            
            v_total_cost_exw := v_qlc.qty * v_unit_cost_exw;
            v_category_code := public.derive_category_code_from_role(v_qlc.component_role);
            
            -- Insert BomInstanceLine
            INSERT INTO "BomInstanceLines" (
                organization_id,
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                description,
                unit_cost_exw,
                total_cost_exw,
                category_code,
                created_at,
                updated_at,
                deleted
            ) VALUES (
                v_org_id,
                v_bom_instance_id,
                v_qlc.catalog_item_id,
                v_sku,
                v_qlc.component_role,
                v_qlc.qty,
                v_canonical_uom,
                v_item_name,
                v_unit_cost_exw,
                v_total_cost_exw,
                v_category_code,
                now(),
                now(),
                false
            )
            ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
            WHERE deleted = false
            DO NOTHING;
            
            RAISE NOTICE '✅ Created BomInstanceLine for % (role: %, qty: %, uom: %)', 
                v_sku, v_qlc.component_role, v_qlc.qty, v_canonical_uom;
        ELSE
            RAISE WARNING '⚠️ No BomInstance found for SalesOrderLine %', v_qlc.sale_order_line_id;
        END IF;
    END LOOP;
END $$;

-- Step 3: Apply engineering rules and convert linear UOM
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
            PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
            RAISE NOTICE '✅ Applied engineering rules for BomInstance %', v_bom_instance_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error applying engineering rules for BomInstance %: %', v_bom_instance_id, SQLERRM;
        END;
    END LOOP;
END $$;

-- Step 4: Verify the results
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

