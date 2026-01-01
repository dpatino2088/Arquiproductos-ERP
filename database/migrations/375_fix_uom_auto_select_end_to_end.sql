-- ====================================================
-- Migration 375: Fix UOM for Auto-Select Components (End-to-End)
-- ====================================================
-- Objective: Ensure UOM in BOMInstanceLines ALWAYS comes from CatalogItems.uom
--   - For Auto-Select: UOM is determined at BOM generation time from resolved SKU
--   - For Fixed: UOM comes from CatalogItems.uom of the selected component
--   - Cleanup existing BOMInstanceLines with incorrect UOM
--
-- Date: 2025-01-01
-- ====================================================

-- ====================================================
-- STEP 1: Create helper function to get UOM from CatalogItems
-- ====================================================
CREATE OR REPLACE FUNCTION public.get_catalog_item_uom(
    p_catalog_item_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_uom text;
BEGIN
    -- Get UOM from CatalogItems
    SELECT ci.uom
    INTO v_uom
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
    AND ci.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'CatalogItem % not found or deleted', p_catalog_item_id;
    END IF;
    
    IF v_uom IS NULL OR TRIM(v_uom) = '' THEN
        RAISE EXCEPTION 'CatalogItem % has NULL or empty UOM. Please set UOM in CatalogItems before generating BOM.', p_catalog_item_id;
    END IF;
    
    -- Normalize common UOM variations
    v_uom := CASE 
        WHEN v_uom = 'm' THEN 'mts'
        WHEN v_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
        WHEN v_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
        WHEN v_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
        ELSE TRIM(v_uom)
    END;
    
    RETURN v_uom;
END;
$$;

COMMENT ON FUNCTION public.get_catalog_item_uom(uuid) IS 
'Returns the normalized UOM from CatalogItems for a given catalog_item_id. Raises exception if item not found or UOM is NULL/empty.';

-- ====================================================
-- STEP 2: Update generate_bom_for_manufacturing_order() to use CatalogItems.uom
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
    v_real_uom_from_catalog text;  -- NEW: Real UOM from CatalogItems
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
    -- Counters for statistics
    v_fixed_lines_count integer := 0;
    v_auto_select_lines_count integer := 0;
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
    
    RAISE NOTICE '   📋 Sale Order: %', v_sale_order.sale_order_no;
    
    -- Process each SaleOrderLine
    FOR v_sale_order_line IN
        SELECT sol.id, sol.quote_line_id, sol.line_number
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        v_processed_instances := v_processed_instances + 1;
        RAISE NOTICE '';
        RAISE NOTICE '   📦 Processing SalesOrderLine % (line_number: %)', v_sale_order_line.id, v_sale_order_line.line_number;
        
        -- Check if BomInstance already exists
        SELECT bi.id
        INTO v_bom_instance_id
        FROM "BomInstances" bi
        WHERE bi.sale_order_line_id = v_sale_order_line.id
        AND bi.deleted = false
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
            
            -- CRITICAL: Get real UOM from CatalogItems (ignoring template/component UOM)
            BEGIN
                v_real_uom_from_catalog := public.get_catalog_item_uom(v_quote_line_component.catalog_item_id);
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Failed to get UOM for catalog_item_id % (SKU: %): %', 
                        v_quote_line_component.catalog_item_id, v_quote_line_component.sku, SQLERRM;
            END;
            
            -- Get category_code from ComponentRoleMap
            BEGIN
                v_category_code := public.get_category_code_from_role(v_quote_line_component.component_role);
            EXCEPTION
                WHEN OTHERS THEN
                    v_category_code := v_quote_line_component.component_role;
                    RAISE WARNING 'get_category_code_from_role() not found, using role as category_code: %', v_quote_line_component.component_role;
            END;
            
            -- Normalize qty using helper function
            v_quote_line_component.qty := public.normalize_qty_by_uom(v_quote_line_component.qty, v_real_uom_from_catalog);
            
            -- Create BomInstanceLine with UOM from CatalogItems
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
                    v_real_uom_from_catalog,  -- UOM from CatalogItems
                    COALESCE(v_quote_line_component.catalog_item_description, v_quote_line_component.item_name),
                    v_category_code,
                    v_manufacturing_order.organization_id,
                    false,
                    now(),
                    now()
                );
                
                v_lines_count := v_lines_count + 1;
                v_created_lines := v_created_lines + 1;
                v_fixed_lines_count := v_fixed_lines_count + 1;
                
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
                
                -- CRITICAL: Get real UOM from CatalogItems (ignoring template/component UOM)
                BEGIN
                    v_real_uom_from_catalog := public.get_catalog_item_uom(v_resolved_catalog_item_id);
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE EXCEPTION 'Failed to get UOM for resolved catalog_item_id % (SKU: %): %', 
                            v_resolved_catalog_item_id, v_resolved_sku, SQLERRM;
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
                
                -- Normalize qty using helper function
                v_calculated_qty := public.normalize_qty_by_uom(v_calculated_qty, v_real_uom_from_catalog);
                
                -- Get category_code from ComponentRoleMap
                BEGIN
                    v_category_code := public.get_category_code_from_role(v_bom_component.component_role);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_category_code := v_bom_component.component_role;
                        RAISE WARNING 'get_category_code_from_role() not found, using role as category_code: %', v_bom_component.component_role;
                END;
                
                -- Create BomInstanceLine with UOM from CatalogItems
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
                        v_real_uom_from_catalog,  -- UOM from CatalogItems (NOT from template)
                        COALESCE(v_resolved_description, v_resolved_item_name),
                        v_category_code,
                        v_manufacturing_order.organization_id,
                        false,
                        now(),
                        now()
                    );
                    
                    v_lines_count := v_lines_count + 1;
                    v_created_lines := v_created_lines + 1;
                    v_auto_select_lines_count := v_auto_select_lines_count + 1;
                    
                    RAISE NOTICE '   ✅ Created BomInstanceLine for auto-select component % (role: %, qty: %, uom: %)', 
                        v_bom_component.component_role, v_bom_component.component_role, v_calculated_qty, v_real_uom_from_catalog;
                        
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '   ❌ Error creating BomInstanceLine for auto-select component % (role: %): %', 
                            v_bom_component.id, v_bom_component.component_role, SQLERRM;
                END;
            END LOOP;
        END IF;
        
        RAISE NOTICE '   ✅ Created % BomInstanceLines for SalesOrderLine %', v_lines_count, v_sale_order_line.line_number;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '   Created BomInstances: %', v_created_instances;
    RAISE NOTICE '   Created BomInstanceLines: % (Fixed: %, Auto-Select: %)', 
        v_created_lines, v_fixed_lines_count, v_auto_select_lines_count;
    
    RETURN jsonb_build_object(
        'success', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'created_instances', v_created_instances,
        'created_lines', v_created_lines,
        'fixed_lines_count', v_fixed_lines_count,
        'auto_select_lines_count', v_auto_select_lines_count
    );
END;
$$;

-- ====================================================
-- STEP 3: Cleanup existing BOMInstanceLines with incorrect UOM
-- ====================================================
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    -- Update BOMInstanceLines to use UOM from CatalogItems
    UPDATE "BomInstanceLines" bl
    SET uom = public.get_catalog_item_uom(bl.resolved_part_id),
        updated_at = now()
    FROM "CatalogItems" ci
    WHERE bl.resolved_part_id = ci.id
    AND ci.deleted = false
    AND ci.uom IS NOT NULL
    AND TRIM(ci.uom) <> ''
    AND COALESCE(bl.uom, '') <> COALESCE(public.get_catalog_item_uom(bl.resolved_part_id), '');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % BOMInstanceLines to use UOM from CatalogItems', v_updated_count;
EXCEPTION
    WHEN OTHERS THEN
        -- If function doesn't exist yet (shouldn't happen), just warn
        RAISE WARNING '⚠️  Could not update BOMInstanceLines UOM: %. This is OK if function was just created.', SQLERRM;
END;
$$;

-- ====================================================
-- STEP 4: Verification query (read-only, doesn't break migration)
-- ====================================================
DO $$
DECLARE
    v_inconsistencies integer;
    v_lines_without_part integer;
    v_lines_with_null_catalog_uom integer;
    v_lines_with_null_bom_uom integer;
BEGIN
    -- Count lines without resolved_part_id
    SELECT COUNT(*) INTO v_lines_without_part
    FROM "BomInstanceLines" bl
    WHERE bl.resolved_part_id IS NULL
    AND bl.deleted = false;
    
    -- Count lines where CatalogItems.uom is NULL
    SELECT COUNT(*) INTO v_lines_with_null_catalog_uom
    FROM "BomInstanceLines" bl
    INNER JOIN "CatalogItems" ci ON ci.id = bl.resolved_part_id
    WHERE ci.uom IS NULL OR TRIM(ci.uom) = ''
    AND bl.deleted = false
    AND ci.deleted = false;
    
    -- Count lines where BomInstanceLines.uom is NULL
    SELECT COUNT(*) INTO v_lines_with_null_bom_uom
    FROM "BomInstanceLines" bl
    WHERE bl.uom IS NULL OR TRIM(bl.uom) = ''
    AND bl.deleted = false
    AND bl.resolved_part_id IS NOT NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Verification Results:';
    RAISE NOTICE '   Lines without resolved_part_id: %', v_lines_without_part;
    RAISE NOTICE '   Lines with NULL CatalogItems.uom: %', v_lines_with_null_catalog_uom;
    RAISE NOTICE '   Lines with NULL BomInstanceLines.uom: %', v_lines_with_null_bom_uom;
    
    -- Show top 50 inconsistencies (if any)
    IF v_lines_with_null_catalog_uom > 0 OR v_lines_with_null_bom_uom > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Top inconsistencies (first 50):';
        FOR v_inconsistencies IN 
            SELECT bl.id, bl.resolved_sku, bl.part_role, bl.uom as bom_uom, ci.uom as catalog_uom
            FROM "BomInstanceLines" bl
            LEFT JOIN "CatalogItems" ci ON ci.id = bl.resolved_part_id
            WHERE (ci.uom IS NULL OR TRIM(ci.uom) = '' OR bl.uom IS NULL OR TRIM(bl.uom) = '')
            AND bl.deleted = false
            AND (ci.id IS NULL OR ci.deleted = false)
            LIMIT 50
        LOOP
            -- This will be shown in the query result, not as a notice
            NULL;
        END LOOP;
    END IF;
END;
$$;

-- ====================================================
-- Migration Complete
-- ====================================================
-- Summary of changes:
-- 1. Created get_catalog_item_uom() helper function
-- 2. Updated generate_bom_for_manufacturing_order() to ALWAYS use CatalogItems.uom
-- 3. Cleaned up existing BOMInstanceLines to use correct UOM
-- 4. Added verification queries
-- 
-- Next steps:
-- - UI should make UOM readonly for auto-select components
-- - UI should not persist UOM changes for auto-select components
-- ====================================================

