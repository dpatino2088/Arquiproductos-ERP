-- ====================================================
-- Migration 396: Fix generate_bom_for_manufacturing_order to use QuoteLine fields
-- ====================================================
-- This migration updates generate_bom_for_manufacturing_order to:
-- 1. Read hardware_color, drive_type, bom_template_id from QuoteLines
-- 2. Use QuoteLine.hardware_color (user selection) with priority over BOMComponent.hardware_color (fallback)
-- 3. Pass drive_type to block_condition evaluation (if needed in the future)
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Update generate_bom_for_manufacturing_order function
-- ====================================================
CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    v_bom_template_id_from_ql uuid;
    v_catalog_item_uom text;
    -- Auto-select support
    v_bom_component RECORD;
    v_quote_line RECORD;
    v_quote_line_component RECORD;
    v_resolved_catalog_item_id uuid;
    v_resolved_sku text;
    v_resolved_item_name text;
    v_resolved_description text;
    v_calculated_qty numeric;
    v_width_m numeric;
    v_height_m numeric;
    v_block_condition_met boolean;
    -- ✅ NEW: Hardware color from QuoteLine (user selection)
    v_quote_line_hardware_color text;
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
            -- ✅ Get bom_template_id from QuoteLine (if available)
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
        
        -- ✅ UPDATED: Get QuoteLine fields including hardware_color, drive_type, bom_template_id
        SELECT 
            ql.width_m, 
            ql.height_m, 
            ql.cassette, 
            ql.side_channel,
            ql.hardware_color,
            ql.drive_type,
            ql.bom_template_id
        INTO v_quote_line
        FROM "QuoteLines" ql
        WHERE ql.id = v_sale_order_line.quote_line_id
        AND ql.deleted = false
        LIMIT 1;
        
        -- ✅ Store hardware_color from QuoteLine (user selection)
        v_quote_line_hardware_color := v_quote_line.hardware_color;
        
        -- ✅ Use bom_template_id from QuoteLine if available (priority over any fallback)
        IF v_quote_line.bom_template_id IS NOT NULL THEN
            v_bom_template_id_from_ql := v_quote_line.bom_template_id;
        END IF;
        
        -- STEP 2A: Create BomInstanceLines from QuoteLineComponents (Fixed components)
        v_lines_count := 0;
        
        FOR v_quote_line_component IN
            SELECT 
                qlc.id,
                qlc.catalog_item_id,
                qlc.component_role,
                qlc.qty,
                qlc.uom as qlc_uom,
                ci.sku,
                ci.item_name,
                ci.uom as catalog_item_uom,
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
                AND bil.part_role = v_quote_line_component.component_role
                AND bil.deleted = false
            ) THEN
                RAISE NOTICE '   ⏭️  Skipping QuoteLineComponent % (SKU: %, Role: %) - BomInstanceLine already exists', 
                    v_quote_line_component.id, v_quote_line_component.sku, v_quote_line_component.component_role;
                CONTINUE;
            END IF;
            
            -- Use catalog_item_uom if available, otherwise use qlc_uom
            v_validated_uom := COALESCE(v_quote_line_component.catalog_item_uom, v_quote_line_component.qlc_uom, 'ea');
            
            -- Normalize UOM
            v_validated_uom := CASE 
                WHEN v_validated_uom = 'm' THEN 'mts'
                WHEN v_validated_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
                WHEN v_validated_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
                WHEN v_validated_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
                ELSE COALESCE(v_validated_uom, 'ea')
            END;
            
            BEGIN
                INSERT INTO "BomInstanceLines" (
                    bom_instance_id,
                    catalog_item_id,
                    part_sku,
                    part_name,
                    part_description,
                    part_role,
                    qty,
                    uom,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_bom_instance_id,
                    v_quote_line_component.catalog_item_id,
                    v_quote_line_component.sku,
                    v_quote_line_component.item_name,
                    v_quote_line_component.catalog_item_description,
                    v_quote_line_component.component_role,
                    v_quote_line_component.qty,
                    v_validated_uom,
                    false,
                    now(),
                    now()
                );
                
                v_lines_count := v_lines_count + 1;
                RAISE NOTICE '   ✅ Created BomInstanceLine for QLC % (SKU: %, Role: %, Qty: % %)', 
                    v_quote_line_component.id, v_quote_line_component.sku, 
                    v_quote_line_component.component_role, v_quote_line_component.qty, v_validated_uom;
                    
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error creating BomInstanceLine for QLC % (SKU: %, Role: %): %', 
                        v_quote_line_component.id, v_quote_line_component.sku, v_quote_line_component.component_role, SQLERRM;
            END;
        END LOOP;
        
        -- STEP 2B: Create BomInstanceLines from BOMComponents (Auto-select components)
        IF v_bom_template_id_from_ql IS NOT NULL THEN
            FOR v_bom_component IN
                SELECT 
                    bc.id,
                    bc.component_role,
                    bc.auto_select,
                    bc.component_item_id,
                    bc.qty_type,
                    bc.qty_value,
                    bc.qty_per_unit,
                    bc.hardware_color,
                    bc.sku_resolution_rule,
                    bc.block_condition,
                    bc.applies_color
                FROM "BOMComponents" bc
                WHERE bc.bom_template_id = v_bom_template_id_from_ql
                AND bc.deleted = false
                AND (bc.auto_select = true OR bc.component_item_id IS NULL)
                AND bc.component_role IS NOT NULL
            LOOP
                -- Check block_condition using helper function
                v_block_condition_met := public.check_block_condition(
                    p_block_condition := v_bom_component.block_condition,
                    p_quote_line_cassette := v_quote_line.cassette,
                    p_quote_line_side_channel := v_quote_line.side_channel
                );
                
                IF NOT v_block_condition_met THEN
                    RAISE NOTICE '   ⏭️  Skipping auto-select component % (role: %) - block_condition not met', 
                        v_bom_component.id, v_bom_component.component_role;
                    CONTINUE;
                END IF;
                
                -- Check if BomInstanceLine already exists for this component_role
                IF EXISTS (
                    SELECT 1
                    FROM "BomInstanceLines" bil
                    WHERE bil.bom_instance_id = v_bom_instance_id
                    AND bil.part_role = v_bom_component.component_role
                    AND bil.deleted = false
                ) THEN
                    RAISE NOTICE '   ⏭️  Skipping auto-select component % (role: %) - BomInstanceLine already exists for this role', 
                        v_bom_component.id, v_bom_component.component_role;
                    CONTINUE;
                END IF;
                
                -- ✅ CRITICAL FIX: Use QuoteLine.hardware_color (user selection) with priority over BOMComponent.hardware_color (fallback)
                -- Resolve catalog_item_id
                BEGIN
                    v_resolved_catalog_item_id := public.resolve_auto_select_sku(
                        p_component_role := v_bom_component.component_role,
                        p_sku_resolution_rule := COALESCE(v_bom_component.sku_resolution_rule, 'ROLE_AND_COLOR'),
                        p_hardware_color := COALESCE(v_quote_line_hardware_color, v_bom_component.hardware_color),
                        p_organization_id := v_manufacturing_order.organization_id,
                        p_bom_template_id := v_bom_template_id_from_ql
                    );
                    
                    RAISE NOTICE '   ✅ Resolved auto-select component % (role: %) -> catalog_item_id: % (hardware_color: %)', 
                        v_bom_component.id, v_bom_component.component_role, v_resolved_catalog_item_id,
                        COALESCE(v_quote_line_hardware_color, v_bom_component.hardware_color, 'none');
                        
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE EXCEPTION 'Failed to resolve auto-select component: bom_template_id=%, component_id=%, role=%, sku_resolution_rule=%, hardware_color (QuoteLine)=%, hardware_color (BOMComponent)=%. Error: %', 
                            v_bom_template_id_from_ql, v_bom_component.id, v_bom_component.component_role, 
                            v_bom_component.sku_resolution_rule, v_quote_line_hardware_color, v_bom_component.hardware_color, SQLERRM;
                END;
                
                -- Get catalog item details
                SELECT ci.sku, ci.item_name, ci.description, ci.uom
                INTO v_resolved_sku, v_resolved_item_name, v_resolved_description, v_catalog_item_uom
                FROM "CatalogItems" ci
                WHERE ci.id = v_resolved_catalog_item_id
                AND ci.deleted = false
                LIMIT 1;
                
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Resolved catalog_item_id % not found in CatalogItems', v_resolved_catalog_item_id;
                END IF;
                
                -- Get UOM from catalog item using helper function
                v_validated_uom := public.get_catalog_item_uom(v_resolved_catalog_item_id);
                
                -- Calculate qty based on qty_type
                IF v_bom_component.qty_type = 'fixed' THEN
                    v_calculated_qty := COALESCE(v_bom_component.qty_value, v_bom_component.qty_per_unit, 1);
                
                ELSIF v_bom_component.qty_type = 'per_width' THEN
                    IF v_quote_line.width_m IS NULL THEN
                        RAISE EXCEPTION 'qty_type=per_width requires QuoteLine.width_m but it is NULL for quote_line_id=%', 
                            v_sale_order_line.quote_line_id;
                    END IF;
                    v_calculated_qty := v_quote_line.width_m * COALESCE(v_bom_component.qty_value, 1);
                
                ELSIF v_bom_component.qty_type = 'per_area' THEN
                    IF v_quote_line.width_m IS NULL OR v_quote_line.height_m IS NULL THEN
                        RAISE EXCEPTION 'qty_type=per_area requires QuoteLine.width_m and height_m but one or both are NULL for quote_line_id=%', 
                            v_sale_order_line.quote_line_id;
                    END IF;
                    v_calculated_qty := (v_quote_line.width_m * v_quote_line.height_m) * COALESCE(v_bom_component.qty_value, 1);
                
                ELSE
                    -- Default to fixed if qty_type is NULL or unsupported
                    v_calculated_qty := COALESCE(v_bom_component.qty_value, v_bom_component.qty_per_unit, 1);
                END IF;
                
                -- Normalize qty by UOM
                v_calculated_qty := public.normalize_qty_by_uom(v_calculated_qty, v_validated_uom);
                
                -- Insert BomInstanceLine
                BEGIN
                    INSERT INTO "BomInstanceLines" (
                        bom_instance_id,
                        catalog_item_id,
                        part_sku,
                        part_name,
                        part_description,
                        part_role,
                        qty,
                        uom,
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_bom_instance_id,
                        v_resolved_catalog_item_id,
                        v_resolved_sku,
                        v_resolved_item_name,
                        v_resolved_description,
                        v_bom_component.component_role,
                        v_calculated_qty,
                        v_validated_uom,
                        false,
                        now(),
                        now()
                    );
                    
                    v_lines_count := v_lines_count + 1;
                    RAISE NOTICE '   ✅ Created BomInstanceLine for auto-select component % (SKU: %, Role: %, Qty: % %)', 
                        v_bom_component.id, v_resolved_sku, v_bom_component.component_role, v_calculated_qty, v_validated_uom;
                        
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '   ❌ Error creating BomInstanceLine for auto-select component % (role: %): %', 
                            v_bom_component.id, v_bom_component.component_role, SQLERRM;
                END;
            END LOOP;
        ELSE
            RAISE NOTICE '   ⏭️  No bom_template_id found for QuoteLine %, skipping auto-select components', v_sale_order_line.quote_line_id;
        END IF;
        
        v_created_lines := v_created_lines + v_lines_count;
        v_processed_instances := v_processed_instances + 1;
        
        RAISE NOTICE '   📊 Created % BomInstanceLine(s) for SalesOrderLine %', v_lines_count, v_sale_order_line.line_number;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM generation completed!';
    RAISE NOTICE '   Created BomInstances: %', v_created_instances;
    RAISE NOTICE '   Created BomInstanceLines: %', v_created_lines;
    RAISE NOTICE '   Processed SalesOrderLines: %', v_processed_instances;
    
    RETURN jsonb_build_object(
        'success', true,
        'created_instances', v_created_instances,
        'created_lines', v_created_lines,
        'processed_instances', v_processed_instances
    );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'Generates BOM instances and lines for a Manufacturing Order. Uses QuoteLine.hardware_color (user selection) with priority over BOMComponent.hardware_color (fallback) for auto-select SKU resolution.';

-- ====================================================
-- GRANT PERMISSIONS
-- ====================================================
GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;

-- Migration completed

