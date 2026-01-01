-- ====================================================
-- Migration 358: Add Auto-Select Support to BOM Generation
-- ====================================================
-- This migration updates generate_bom_for_manufacturing_order to support
-- auto-select components (when component_item_id IS NULL in BOMComponents)
-- 
-- Features:
-- 1. Resolves SKU for auto-select components using sku_resolution_rule + hardware_color
-- 2. Filters by block_condition (cassette, side_channel, etc.)
-- 3. Calculates qty based on qty_type (fixed, per_width, per_area)
-- 4. Uses CatalogItems.uom as primary source
-- ====================================================

-- Helper function to resolve SKU for auto-select components
CREATE OR REPLACE FUNCTION public.resolve_auto_select_sku(
    p_component_role text,
    p_sku_resolution_rule text,
    p_hardware_color text,
    p_organization_id uuid,
    p_bom_template_id uuid DEFAULT NULL
)
RETURNS uuid  -- Returns catalog_item_id
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_resolved_catalog_item_id uuid;
    v_category_code text;
    v_catalog_item RECORD;
BEGIN
    -- Map component_role to category_code (matching the logic in generate_bom_for_manufacturing_order)
    v_category_code := CASE 
        WHEN p_component_role = 'fabric' THEN 'fabric'
        WHEN p_component_role = 'tube' THEN 'tube'
        WHEN p_component_role = 'motor' THEN 'motor'
        WHEN p_component_role = 'bracket' THEN 'bracket'
        WHEN p_component_role LIKE '%cassette%' THEN 'cassette'
        WHEN p_component_role LIKE '%side_channel%' THEN 'side_channel'
        WHEN p_component_role LIKE '%bottom_rail%' OR p_component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
        ELSE 'accessory'
    END;
    
        -- Resolve SKU based on sku_resolution_rule
    IF p_sku_resolution_rule = 'EXACT_SKU' THEN
        -- This shouldn't happen for auto-select, but handle gracefully
        RAISE EXCEPTION 'EXACT_SKU resolution not supported for auto-select components. Use component_item_id for fixed selection.';
    
    ELSIF p_sku_resolution_rule IN ('SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR') OR p_sku_resolution_rule IS NULL THEN
        -- Search by category_code (derived from component_role) and hardware_color
        -- Note: This is a simplified implementation. In a real system, you might need
        -- additional logic based on manufacturer, product family, etc.
        
        -- For now, we'll search CatalogItems by:
        -- 1. Category code matches (via ItemCategories.category_code)
        -- 2. Hardware color matches (if provided)
        -- 3. Organization matches
        
        -- Note: This assumes that CatalogItems have a way to match hardware_color
        -- If hardware_color is stored in CatalogItems directly, use it
        -- Otherwise, it might be in SKU suffix or metadata
        
        SELECT ci.id INTO v_resolved_catalog_item_id
        FROM "CatalogItems" ci
        INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
        WHERE ci.organization_id = p_organization_id
        AND ci.deleted = false
        AND ic.category_code = v_category_code
        AND (p_hardware_color IS NULL OR 
             -- Try to match hardware_color (could be in SKU suffix, metadata, or a dedicated field)
             -- For now, we'll check if SKU contains color code (e.g., -W, -GR, -BLK)
             CASE 
                 WHEN p_hardware_color = 'white' THEN ci.sku LIKE '%-W%' OR ci.sku LIKE '%WHITE%' OR ci.sku LIKE '%WHT%'
                 WHEN p_hardware_color = 'black' THEN ci.sku LIKE '%-BLK%' OR ci.sku LIKE '%BLACK%' OR ci.sku LIKE '%BLK%'
                 WHEN p_hardware_color = 'grey' OR p_hardware_color = 'gray' THEN ci.sku LIKE '%-GR%' OR ci.sku LIKE '%GREY%' OR ci.sku LIKE '%GRAY%'
                 WHEN p_hardware_color = 'silver' THEN ci.sku LIKE '%-SV%' OR ci.sku LIKE '%SILVER%'
                 WHEN p_hardware_color = 'bronze' THEN ci.sku LIKE '%-BZ%' OR ci.sku LIKE '%BRONZE%'
                 ELSE true  -- No color filter if hardware_color not recognized
             END
        )
        ORDER BY 
            -- Prefer items that match color exactly (if color specified)
            CASE WHEN p_hardware_color IS NOT NULL THEN 0 ELSE 1 END,
            ci.created_at DESC  -- Prefer newer items as tiebreaker
        LIMIT 1;
        
        IF v_resolved_catalog_item_id IS NULL THEN
            RAISE EXCEPTION 'Could not resolve catalog_item_id for auto-select component: role=%, sku_resolution_rule=%, hardware_color=%, category_code=%, organization_id=%', 
                p_component_role, p_sku_resolution_rule, p_hardware_color, v_category_code, p_organization_id;
        END IF;
        
        RETURN v_resolved_catalog_item_id;
    
    ELSE
        RAISE EXCEPTION 'Unsupported sku_resolution_rule for auto-select: %. Supported values: EXACT_SKU, SKU_SUFFIX_COLOR, ROLE_AND_COLOR', 
            p_sku_resolution_rule;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.resolve_auto_select_sku IS 
    'Resolves catalog_item_id for auto-select BOM components based on component_role, sku_resolution_rule, and hardware_color. Returns catalog_item_id or raises exception if not found.';

-- Main function update
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
    v_bom_template_id_from_ql uuid;
    v_catalog_item_uom text;
    -- Auto-select support
    v_bom_component RECORD;
    v_quote_line RECORD;
    v_resolved_catalog_item_id uuid;
    v_resolved_sku text;
    v_resolved_item_name text;
    v_resolved_description text;
    v_calculated_qty numeric;
    v_width_m numeric;
    v_height_m numeric;
    v_block_condition_met boolean;
    v_block_condition_json jsonb;
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
        
        -- Get QuoteLine for width/height and cassette/side_channel flags
        SELECT ql.width_m, ql.height_m, ql.cassette, ql.side_channel
        INTO v_quote_line
        FROM "QuoteLines" ql
        WHERE ql.id = v_sale_order_line.quote_line_id
        AND ql.deleted = false
        LIMIT 1;
        
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
                AND COALESCE(bil.part_role, '') = COALESCE(v_quote_line_component.component_role, '')
                AND bil.deleted = false
            ) THEN
                CONTINUE;
            END IF;
            
            -- Use CatalogItems.uom as primary source
            v_catalog_item_uom := COALESCE(v_quote_line_component.catalog_item_uom, v_quote_line_component.qlc_uom, 'ea');
            
            -- Normalize UOM
            v_validated_uom := CASE 
                WHEN v_catalog_item_uom = 'm' THEN 'mts'
                WHEN v_catalog_item_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
                WHEN v_catalog_item_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
                WHEN v_catalog_item_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
                ELSE v_catalog_item_uom
            END;
            
            -- Calculate category_code from component_role
            v_category_code := CASE 
                WHEN v_quote_line_component.component_role = 'fabric' THEN 'fabric'
                WHEN v_quote_line_component.component_role = 'tube' THEN 'tube'
                WHEN v_quote_line_component.component_role = 'motor' THEN 'motor'
                WHEN v_quote_line_component.component_role = 'bracket' THEN 'bracket'
                WHEN v_quote_line_component.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_quote_line_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_quote_line_component.component_role LIKE '%bottom_rail%' OR v_quote_line_component.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
                ELSE 'accessory'
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
                -- Check block_condition
                v_block_condition_met := true;
                v_block_condition_json := v_bom_component.block_condition;
                
                IF v_block_condition_json IS NOT NULL THEN
                    -- Check cassette condition
                    IF (v_block_condition_json->>'cassette')::boolean = true THEN
                        IF COALESCE(v_quote_line.cassette, false) = false THEN
                            RAISE NOTICE '   ⏭️  Skipping auto-select component % (role: %) - block_condition requires cassette but QuoteLine does not have it', 
                                v_bom_component.id, v_bom_component.component_role;
                            v_block_condition_met := false;
                        END IF;
                    END IF;
                    
                    -- Check side_channel condition
                    IF (v_block_condition_json->>'side_channel')::boolean = true THEN
                        IF COALESCE(v_quote_line.side_channel, false) = false THEN
                            RAISE NOTICE '   ⏭️  Skipping auto-select component % (role: %) - block_condition requires side_channel but QuoteLine does not have it', 
                                v_bom_component.id, v_bom_component.component_role;
                            v_block_condition_met := false;
                        END IF;
                    END IF;
                END IF;
                
                IF NOT v_block_condition_met THEN
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
                
                -- Resolve catalog_item_id
                BEGIN
                    v_resolved_catalog_item_id := public.resolve_auto_select_sku(
                        p_component_role := v_bom_component.component_role,
                        p_sku_resolution_rule := COALESCE(v_bom_component.sku_resolution_rule, 'ROLE_AND_COLOR'),
                        p_hardware_color := v_bom_component.hardware_color,
                        p_organization_id := v_manufacturing_order.organization_id,
                        p_bom_template_id := v_bom_template_id_from_ql
                    );
                    
                    RAISE NOTICE '   ✅ Resolved auto-select component % (role: %) -> catalog_item_id: %', 
                        v_bom_component.id, v_bom_component.component_role, v_resolved_catalog_item_id;
                        
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE EXCEPTION 'Failed to resolve auto-select component: bom_template_id=%, component_id=%, role=%, sku_resolution_rule=%, hardware_color=%. Error: %', 
                            v_bom_template_id_from_ql, v_bom_component.id, v_bom_component.component_role, 
                            v_bom_component.sku_resolution_rule, v_bom_component.hardware_color, SQLERRM;
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
                
                -- Normalize UOM
                v_validated_uom := CASE 
                    WHEN v_catalog_item_uom = 'm' THEN 'mts'
                    WHEN v_catalog_item_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
                    WHEN v_catalog_item_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
                    WHEN v_catalog_item_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
                    ELSE COALESCE(v_catalog_item_uom, 'ea')
                END;
                
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
                    RAISE NOTICE '   ⚠️  Unsupported qty_type "%" for component % (role: %), using fixed qty=%', 
                        v_bom_component.qty_type, v_bom_component.id, v_bom_component.component_role, v_calculated_qty;
                END IF;
                
                -- Round qty based on UOM
                IF v_validated_uom IN ('pcs', 'ea', 'piece', 'pieces') THEN
                    v_calculated_qty := CEIL(v_calculated_qty);
                ELSE
                    -- Keep 2-3 decimal places for meters, square meters, etc.
                    v_calculated_qty := ROUND(v_calculated_qty, 3);
                END IF;
                
                -- Calculate category_code from component_role
                v_category_code := CASE 
                    WHEN v_bom_component.component_role = 'fabric' THEN 'fabric'
                    WHEN v_bom_component.component_role = 'tube' THEN 'tube'
                    WHEN v_bom_component.component_role = 'motor' THEN 'motor'
                    WHEN v_bom_component.component_role = 'bracket' THEN 'bracket'
                    WHEN v_bom_component.component_role LIKE '%cassette%' THEN 'cassette'
                    WHEN v_bom_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                    WHEN v_bom_component.component_role LIKE '%bottom_rail%' OR v_bom_component.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
                    ELSE 'accessory'
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
                        v_resolved_catalog_item_id,
                        v_resolved_sku,
                        v_bom_component.component_role,
                        v_calculated_qty,
                        v_validated_uom,
                        COALESCE(v_resolved_description, v_resolved_item_name),
                        v_category_code,
                        v_manufacturing_order.organization_id,
                        false,
                        now(),
                        now()
                    );
                    
                    v_lines_count := v_lines_count + 1;
                    v_created_lines := v_created_lines + 1;
                    
                    RAISE NOTICE '   ✅ Created BomInstanceLine for auto-select component % (role: %, qty: %, uom: %)', 
                        v_bom_component.component_role, v_bom_component.component_role, v_calculated_qty, v_validated_uom;
                        
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '   ❌ Error creating BomInstanceLine for auto-select component % (role: %): %', 
                            v_bom_component.id, v_bom_component.component_role, SQLERRM;
                END;
            END LOOP;
        END IF;
        
        IF v_lines_count > 0 THEN
            RAISE NOTICE '   ✅ Created % BomInstanceLine(s) for BomInstance %', v_lines_count, v_bom_instance_id;
        ELSE
            RAISE WARNING '   ⚠️ No BomInstanceLine(s) created for BomInstance %', v_bom_instance_id;
        END IF;
        
        v_processed_instances := v_processed_instances + 1;
    END LOOP;
    
    -- STEP 3: Apply engineering rules to all BomInstances
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
    'Generates/updates BOM for a Manufacturing Order: (1) creates BomInstances and BomInstanceLines from QuoteLineComponents (fixed) and BOMComponents (auto-select), (2) applies engineering rules, (3) uses CatalogItems.uom as primary source. Auto-select components are resolved using resolve_auto_select_sku() based on component_role, sku_resolution_rule, and hardware_color.';

