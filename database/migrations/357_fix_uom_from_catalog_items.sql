-- ====================================================
-- Migration 357: Fix UOM to Use CatalogItems.uom Instead of QuoteLineComponents.uom
-- ====================================================
-- Updates generate_bom_for_manufacturing_order to use CatalogItems.uom
-- instead of QuoteLineComponents.uom when creating BomInstanceLines
-- ====================================================

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_manufacturing_order RECORD;
    v_sale_order RECORD;
    v_sale_order_line RECORD;
    v_bom_instance_id uuid;
    v_created_instances integer := 0;
    v_created_lines integer := 0;
    v_processed_instances integer := 0;
    v_lines_count integer := 0;
    v_validated_uom text;
    v_category_code text;
    v_quote_line_component RECORD;
    v_bom_template_id_from_ql uuid;
    v_catalog_item_uom text;
BEGIN
    -- Get Manufacturing Order
    SELECT mo.id, mo.sale_order_id, mo.organization_id, mo.manufacturing_order_no
    INTO v_manufacturing_order
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Generating BOM for Manufacturing Order: %', v_manufacturing_order.manufacturing_order_no;
    
    -- Get Sale Order
    SELECT so.id, so.sale_order_no
    INTO v_sale_order
    FROM "SalesOrders" so
    WHERE so.id = v_manufacturing_order.sale_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_manufacturing_order.sale_order_id, p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '   Sale Order: %', v_sale_order.sale_order_no;
    
    -- STEP 1: Create BomInstances if they don't exist
    FOR v_sale_order_line IN
        SELECT sol.id, sol.quote_line_id, sol.line_number
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Check if BomInstance already exists
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get bom_template_id from QuoteLine (if available)
            SELECT ql.bom_template_id
            INTO v_bom_template_id_from_ql
            FROM "QuoteLines" ql
            WHERE ql.id = v_sale_order_line.quote_line_id
            AND ql.deleted = false
            LIMIT 1;
            
            -- Create BomInstance
            BEGIN
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_manufacturing_order.organization_id,
                    v_sale_order_line.id,
                    v_sale_order_line.quote_line_id,
                    v_bom_template_id_from_ql,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '   ✅ Created BomInstance % for SalesOrderLine % (line_number: %)', 
                    v_bom_instance_id, v_sale_order_line.id, v_sale_order_line.line_number;
                v_created_instances := v_created_instances + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error creating BomInstance for SalesOrderLine %: %', v_sale_order_line.id, SQLERRM;
                    CONTINUE;
            END;
        ELSE
            RAISE NOTICE '   ⏭️  BomInstance % already exists for SalesOrderLine %', v_bom_instance_id, v_sale_order_line.id;
        END IF;
        
        -- STEP 2: Create BomInstanceLines from QuoteLineComponents
        v_lines_count := 0; -- Reset counter for this BomInstance
        
        FOR v_quote_line_component IN
            SELECT 
                qlc.id,
                qlc.catalog_item_id,
                qlc.component_role,
                qlc.qty,
                qlc.uom as qlc_uom,  -- Keep for fallback
                ci.sku,
                ci.item_name,
                ci.uom as catalog_item_uom,  -- Use CatalogItems.uom as primary source
                ci.description as catalog_item_description
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_sale_order_line.quote_line_id
            AND qlc.deleted = false
            AND qlc.source = 'configured_component'
            ORDER BY qlc.component_role
        LOOP
            -- Check if BomInstanceLine already exists
            IF EXISTS (
                SELECT 1
                FROM "BomInstanceLines" bil
                WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.resolved_part_id = v_quote_line_component.catalog_item_id
                AND COALESCE(bil.part_role, '') = COALESCE(v_quote_line_component.component_role, '')
                AND bil.deleted = false
            ) THEN
                CONTINUE; -- Skip if already exists
            END IF;
            
            -- Use CatalogItems.uom as primary source, fallback to QuoteLineComponents.uom
            v_catalog_item_uom := COALESCE(v_quote_line_component.catalog_item_uom, v_quote_line_component.qlc_uom, 'ea');
            
            -- Normalize UOM (m -> mts, ensure canonical forms)
            v_validated_uom := CASE 
                WHEN v_catalog_item_uom = 'm' THEN 'mts'
                WHEN v_catalog_item_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
                WHEN v_catalog_item_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
                WHEN v_catalog_item_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
                ELSE v_catalog_item_uom
            END;
            
            -- Calculate category_code from component_role (must match constraint check_bom_instance_lines_category_code_valid)
            v_category_code := CASE 
                WHEN v_quote_line_component.component_role = 'fabric' THEN 'fabric'
                WHEN v_quote_line_component.component_role = 'tube' THEN 'tube'
                WHEN v_quote_line_component.component_role = 'motor' THEN 'motor'
                WHEN v_quote_line_component.component_role = 'bracket' THEN 'bracket'
                WHEN v_quote_line_component.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_quote_line_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_quote_line_component.component_role LIKE '%bottom_rail%' OR v_quote_line_component.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
                ELSE 'accessory'  -- Default for motor_adapter, operating_system_drive, bracket_cover, chain, etc.
            END;
            
            -- Create BomInstanceLine
            BEGIN
                INSERT INTO "BomInstanceLines" (
                    bom_instance_id,
                    resolved_part_id,
                    resolved_sku,
                    part_role,
                    qty,
                    uom,
                    description,
                    category_code,
                    organization_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_bom_instance_id,
                    v_quote_line_component.catalog_item_id,
                    v_quote_line_component.sku,
                    v_quote_line_component.component_role,
                    v_quote_line_component.qty,
                    v_validated_uom,
                    COALESCE(v_quote_line_component.catalog_item_description, v_quote_line_component.item_name),
                    v_category_code,
                    v_manufacturing_order.organization_id,
                    false,
                    now(),
                    now()
                );
                
                v_lines_count := v_lines_count + 1;
                v_created_lines := v_created_lines + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error creating BomInstanceLine for QLC % (SKU: %, Role: %): %', 
                        v_quote_line_component.id, v_quote_line_component.sku, v_quote_line_component.component_role, SQLERRM;
            END;
        END LOOP;
        
        IF v_lines_count > 0 THEN
            RAISE NOTICE '   ✅ Created % BomInstanceLine(s) for BomInstance %', v_lines_count, v_bom_instance_id;
        ELSE
            RAISE WARNING '   ⚠️ No BomInstanceLine(s) created for BomInstance % (QuoteLineComponents missing or errors occurred)', v_bom_instance_id;
        END IF;
        
        v_processed_instances := v_processed_instances + 1;
    END LOOP;
    
    -- STEP 3: Apply engineering rules to all BomInstances (newly created and existing)
    RAISE NOTICE '🔧 Applying engineering rules to all BomInstances for MO %...', v_manufacturing_order.manufacturing_order_no;
    FOR v_bom_instance_id IN
        SELECT bi.id
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order.id
        AND bi.deleted = false
        AND sol.deleted = false
    LOOP
        BEGIN
            PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
            RAISE NOTICE '   ✅ Applied engineering rules and converted linear roles for BomInstance %', v_bom_instance_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error applying engineering rules/conversion to BomInstance %: %', v_bom_instance_id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ BOM generation completed for MO %: % BomInstance(s) created, % BomInstanceLine(s) created.', 
        v_manufacturing_order.manufacturing_order_no, v_created_instances, v_created_lines;
    
    RETURN jsonb_build_object(
        'success', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'bom_instances_created', v_created_instances,
        'bom_instance_lines_created', v_created_lines
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Critical error in generate_bom_for_manufacturing_order for MO %: %', p_manufacturing_order_id, SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'Generates/updates BOM for a Manufacturing Order by: (1) creating BomInstances and BomInstanceLines from QuoteLineComponents if they don''t exist (using CatalogItems.uom as primary UOM source), (2) applying engineering rules, (3) fixing NULL part_roles, (4) converting linear roles to meters.';


