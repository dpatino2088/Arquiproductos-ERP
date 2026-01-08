-- ====================================================
-- Migration 438: Fix BOM generation to use manufacturing_order_id
-- ====================================================
-- OBJETIVO: Actualizar generate_bom_for_manufacturing_order para:
-- 1. Insertar BomInstances con manufacturing_order_id (obligatorio)
-- 2. Usar sales_order_line_id (correcto) en lugar de sale_order_line_id (legacy)
-- 3. Procesar todas las ManufacturingOrderLines del MO
-- ====================================================

SET search_path = public;

BEGIN;

-- ====================================================
-- STEP 1: Update generate_bom_for_manufacturing_order
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
    v_mo RECORD;
    v_mo_line RECORD;
    v_sales_order_line RECORD;
    v_bom_instance_id uuid;
    v_bom_template_id uuid;
    v_bom_component RECORD;
    v_catalog_item RECORD;
    v_fabric_count integer := 0;
    v_calculated_qty numeric;
    v_normalized_uom text;
    v_category_code text;
    v_unit_cost_exw numeric(12,4) := 0;
    v_total_cost_exw numeric(12,4) := 0;
    v_unit_msrp_sale_out numeric(12,4) := 0;
    v_total_msrp_sale_out numeric(12,4) := 0;
    v_bom_total_cost numeric(12,4) := 0;
    v_bom_labor_cost numeric(12,4) := 0;
    v_bom_total_cost_with_labor numeric(12,4) := 0;
    v_bom_msrp_sale_out numeric(12,4) := 0;
    v_cost_settings RECORD;
    v_shipping_percentage numeric(8,4) := 0;
    v_import_tax_percentage numeric(8,4) := 0;
    v_min_margin_pct numeric(8,4) := 35.0;
    v_max_discount_pct numeric(8,4) := 65.0;
    v_labor_percentage numeric(8,4) := 0;
    v_created_lines integer := 0;
    v_errors text[] := ARRAY[]::text[];
    v_warnings text[] := ARRAY[]::text[];
    v_formula_params jsonb;
    v_results jsonb := '[]'::jsonb;
    v_line_result jsonb;
    v_total_bom_instances integer := 0;
    v_total_bom_lines integer := 0;
    v_mo_lines_processed integer := 0;
BEGIN
    -- ====================================================
    -- STEP 1: Load ManufacturingOrder
    -- ====================================================
    SELECT *
    INTO v_mo
    FROM public."ManufacturingOrders"
    WHERE id = p_manufacturing_order_id;
    
    IF v_mo.id IS NULL THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    IF v_mo.deleted = true THEN
        RAISE EXCEPTION 'ManufacturingOrder % is deleted', p_manufacturing_order_id;
    END IF;
    
    IF v_mo.sales_order_id IS NULL THEN
        v_warnings := v_warnings || 'MO missing sales_order_id';
        RAISE WARNING 'ManufacturingOrder % has no sales_order_id', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '🚀 Starting BOM generation for ManufacturingOrder: % (Organization: %, SalesOrder: %)', 
        v_mo.id, v_mo.organization_id, v_mo.sales_order_id;
    
    -- ====================================================
    -- STEP 2: Check/auto-create ManufacturingOrderLines
    -- ====================================================
    DECLARE
        v_count_lines integer := 0;
    BEGIN
        SELECT COUNT(*)
        INTO v_count_lines
        FROM public."ManufacturingOrderLines"
        WHERE manufacturing_order_id = p_manufacturing_order_id
            AND deleted = false
            AND archived = false;
        
        IF v_count_lines = 0 THEN
            IF v_mo.sales_order_id IS NULL THEN
                v_warnings := v_warnings || 'No ManufacturingOrderLines and no sales_order_id to create them';
                RAISE WARNING 'ManufacturingOrder % has no sales_order_id and no MO lines', p_manufacturing_order_id;
            ELSE
                -- Check if SalesOrderLines exist
                DECLARE
                    v_sol_count integer := 0;
                BEGIN
                    SELECT COUNT(*)
                    INTO v_sol_count
                    FROM public."SalesOrderLines" sol
                    WHERE sol.sales_order_id = v_mo.sales_order_id
                        AND COALESCE(sol.deleted, false) = false
                        AND COALESCE(sol.archived, false) = false;
                    
                    IF v_sol_count = 0 THEN
                        v_warnings := v_warnings || format('No SalesOrderLines found to create ManufacturingOrderLines (sales_order_id: %)', v_mo.sales_order_id);
                        RAISE WARNING 'No SalesOrderLines found for sales_order_id %', v_mo.sales_order_id;
                    ELSE
                        -- Auto-create lines from SalesOrderLines
                        INSERT INTO public."ManufacturingOrderLines"(
                            manufacturing_order_id, 
                            sales_order_line_id, 
                            organization_id
                        )
                        SELECT
                            v_mo.id,
                            sol.id,
                            COALESCE(v_mo.organization_id, sol.organization_id)
                        FROM public."SalesOrderLines" sol
                        WHERE sol.sales_order_id = v_mo.sales_order_id
                            AND COALESCE(sol.deleted, false) = false
                            AND COALESCE(sol.archived, false) = false
                        ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;
                        
                        SELECT COUNT(*)
                        INTO v_count_lines
                        FROM public."ManufacturingOrderLines"
                        WHERE manufacturing_order_id = p_manufacturing_order_id
                            AND deleted = false
                            AND archived = false;
                        
                        IF v_count_lines = 0 THEN
                            v_warnings := v_warnings || format('0 ManufacturingOrderLines after auto-create attempt (expected % SalesOrderLines)', v_sol_count);
                            RAISE WARNING '0 ManufacturingOrderLines after auto-create';
                        ELSE
                            RAISE NOTICE '✅ Auto-created % ManufacturingOrderLines from SalesOrder', v_count_lines;
                        END IF;
                    END IF;
                END;
            END IF;
        END IF;
    END;
    
    -- ====================================================
    -- STEP 3: Load CostSettings
    -- ====================================================
    SELECT 
        shipping_percentage,
        import_tax_percent,
        min_margin_pct,
        discount_distributor_pct,
        labor_percentage
    INTO v_cost_settings
    FROM "CostSettings"
    WHERE organization_id = v_mo.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        v_shipping_percentage := COALESCE(v_cost_settings.shipping_percentage, 0);
        v_import_tax_percentage := COALESCE(v_cost_settings.import_tax_percent, 0);
        v_min_margin_pct := COALESCE(v_cost_settings.min_margin_pct, 35.0);
        v_labor_percentage := COALESCE(v_cost_settings.labor_percentage, 0);
        v_max_discount_pct := COALESCE(v_cost_settings.discount_distributor_pct, 65.0);
    END IF;
    
    -- ====================================================
    -- STEP 4: Process each ManufacturingOrderLine
    -- ====================================================
    FOR v_mo_line IN
        SELECT mol.sales_order_line_id
        FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
            AND mol.deleted = false
            AND mol.archived = false
        ORDER BY mol.created_at ASC
    LOOP
        -- Reset per-line variables
        v_bom_instance_id := NULL;
        v_bom_template_id := NULL;
        v_fabric_count := 0;
        v_bom_total_cost := 0;
        v_created_lines := 0;
        
        -- Load SalesOrderLine
        SELECT 
            sol.id,
            sol.product_type,
            sol.collection_name,
            sol.variant_name,
            sol.width_m,
            sol.height_m,
            sol.area,
            sol.drive_type,
            sol.cassette,
            sol.cassette_type,
            sol.side_channel,
            sol.side_channel_type,
            sol.hardware_color,
            sol.bottom_rail_type,
            sol.quote_line_id
        INTO v_sales_order_line
        FROM "SalesOrderLines" sol
        WHERE sol.id = v_mo_line.sales_order_line_id
        AND sol.deleted = false;
        
        IF NOT FOUND THEN
            v_errors := v_errors || format('SalesOrderLine %s not found', v_mo_line.sales_order_line_id);
            CONTINUE;
        END IF;
        
        v_mo_lines_processed := v_mo_lines_processed + 1;
        
        -- Resolve BOMTemplate
        IF v_sales_order_line.product_type IS NULL OR TRIM(v_sales_order_line.product_type) = '' THEN
            v_warnings := v_warnings || format('Missing product_type for SalesOrderLine %s (MO Line %s)', 
                v_sales_order_line.id, v_mo_line.sales_order_line_id);
            v_errors := v_errors || format('SalesOrderLine %s has NULL or empty product_type', v_sales_order_line.id);
            CONTINUE;
        END IF;
        
        SELECT bt.id INTO v_bom_template_id
        FROM "BOMTemplates" bt
        INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
        WHERE pt.code = v_sales_order_line.product_type
        AND bt.active = true
        AND bt.deleted = false
        ORDER BY bt.created_at DESC
        LIMIT 1;
        
        IF NOT FOUND THEN
            v_warnings := v_warnings || format('Missing bom_template_id for product_type: %s (SalesOrderLine: %s)', 
                v_sales_order_line.product_type, v_sales_order_line.id);
            v_errors := v_errors || format('No active BOMTemplate found for product_type: %s (SalesOrderLine: %s)', 
                v_sales_order_line.product_type, v_sales_order_line.id);
            CONTINUE;
        END IF;
        
        -- Check if BOMTemplate has components
        DECLARE
            v_component_count integer := 0;
        BEGIN
            SELECT COUNT(*)
            INTO v_component_count
            FROM "BomTemplateComponents" btc
            WHERE btc.bom_template_id = v_bom_template_id
            AND btc.deleted = false
            AND btc.component_item_id IS NOT NULL;
            
            IF v_component_count = 0 THEN
                v_warnings := v_warnings || format('BOM template %s has 0 components (product_type: %s, SalesOrderLine: %s)', 
                    v_bom_template_id, v_sales_order_line.product_type, v_sales_order_line.id);
                RAISE WARNING 'BOM template % has 0 components', v_bom_template_id;
            ELSE
                RAISE NOTICE '✅ BOM template % has % components', v_bom_template_id, v_component_count;
            END IF;
        END;
        
        -- Delete existing BOM for this SalesOrderLine
        UPDATE "BomInstanceLines" bil
        SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id IN (
            SELECT bi.id
            FROM "BomInstances" bi
            WHERE bi.manufacturing_order_id = p_manufacturing_order_id
            AND bi.sales_order_line_id = v_sales_order_line.id
            AND bi.deleted = false
        );
        
        UPDATE "BomInstances" bi
        SET deleted = true, updated_at = now()
        WHERE bi.manufacturing_order_id = p_manufacturing_order_id
        AND bi.sales_order_line_id = v_sales_order_line.id
        AND bi.deleted = false;
        
        -- Create new BomInstance with manufacturing_order_id
        INSERT INTO "BomInstances" (
            organization_id,
            manufacturing_order_id,
            sales_order_line_id,
            quote_line_id,
            bom_template_id,
            deleted,
            created_at,
            updated_at,
            generated_at
        ) VALUES (
            v_mo.organization_id,
            p_manufacturing_order_id,
            v_sales_order_line.id,
            v_sales_order_line.quote_line_id,
            v_bom_template_id,
            false,
            now(),
            now(),
            now()
        ) RETURNING id INTO v_bom_instance_id;
        
        IF v_bom_instance_id IS NULL THEN
            v_warnings := v_warnings || format('Failed to create BomInstance for SalesOrderLine %s', v_sales_order_line.id);
            CONTINUE;
        END IF;
        
        v_total_bom_instances := v_total_bom_instances + 1;
        RAISE NOTICE '✅ Created BomInstance % for SalesOrderLine %', v_bom_instance_id, v_sales_order_line.id;
        
        -- Process BOMComponents
        FOR v_bom_component IN
            SELECT 
                bc.id,
                bc.component_role,
                bc.component_item_id,
                bc.qty_type,
                bc.qty_value,
                bc.qty_formula_code,
                bc.qty_formula_params,
                bc.uom
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_id
            AND bc.deleted = false
            AND bc.component_item_id IS NOT NULL
            ORDER BY bc.created_at
        LOOP
            -- STRICT FABRIC VALIDATION
            IF v_bom_component.component_role = 'fabric' THEN
                v_fabric_count := v_fabric_count + 1;
                
                IF v_fabric_count > 1 THEN
                    v_errors := v_errors || format('BOMTemplate %s allows MORE THAN ONE fabric component. Only EXACTLY ONE fabric is allowed. Component ID: %s', 
                        v_bom_template_id, v_bom_component.id);
                    CONTINUE;
                END IF;
                
                -- Resolve fabric CatalogItem
                SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw
                INTO v_catalog_item
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ci.id = v_bom_component.component_item_id
                AND ci.organization_id = v_mo.organization_id
                AND ci.deleted = false
                AND ci.active = true
                AND ic.code = 'FABRIC'
                AND ci.collection_name = v_sales_order_line.collection_name
                AND (
                    (v_sales_order_line.variant_name IS NULL AND ci.variant_name IS NULL)
                    OR ci.variant_name = v_sales_order_line.variant_name
                );
                
                IF NOT FOUND THEN
                    v_errors := v_errors || format('Fabric CatalogItem %s does NOT match SalesOrderLine collection_name=%s variant_name=%s. SalesOrderLine: %s', 
                        v_bom_component.component_item_id, 
                        v_sales_order_line.collection_name, 
                        v_sales_order_line.variant_name,
                        v_sales_order_line.id);
                    CONTINUE;
                END IF;
            ELSE
                -- Non-fabric component
                SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw
                INTO v_catalog_item
                FROM "CatalogItems" ci
                WHERE ci.id = v_bom_component.component_item_id
                AND ci.organization_id = v_mo.organization_id
                AND ci.deleted = false
                AND ci.active = true;
                
                IF NOT FOUND THEN
                    v_errors := v_errors || format('CatalogItem %s (component_id: %s, role: %s) not found or inactive. SalesOrderLine: %s', 
                        v_bom_component.component_item_id, v_bom_component.id, v_bom_component.component_role,
                        v_sales_order_line.id);
                    CONTINUE;
                END IF;
            END IF;
            
            -- Calculate quantity
            IF v_bom_component.qty_formula_code IS NOT NULL THEN
                IF v_bom_component.qty_formula_code = 'CHAIN_HEIGHT_FACTOR' THEN
                    v_formula_params := v_bom_component.qty_formula_params;
                    
                    IF v_formula_params IS NULL OR 
                       (v_formula_params->>'height_factor') IS NULL OR 
                       (v_formula_params->>'mult') IS NULL THEN
                        v_errors := v_errors || format('Invalid qty_formula_params for CHAIN_HEIGHT_FACTOR. Component: %s', v_bom_component.id);
                        CONTINUE;
                    END IF;
                    
                    IF v_sales_order_line.height_m IS NULL THEN
                        v_errors := v_errors || format('SalesOrderLine %s has NULL height_m. Cannot calculate CHAIN_HEIGHT_FACTOR. Component: %s', 
                            v_sales_order_line.id, v_bom_component.id);
                        CONTINUE;
                    END IF;
                    
                    v_calculated_qty := v_sales_order_line.height_m 
                        * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75)
                        * COALESCE((v_formula_params->>'mult')::numeric, 2);
                ELSE
                    v_errors := v_errors || format('Unknown qty_formula_code: %s for component %s', 
                        v_bom_component.qty_formula_code, v_bom_component.id);
                    CONTINUE;
                END IF;
            ELSIF v_bom_component.qty_type = 'per_width' THEN
                IF v_sales_order_line.width_m IS NULL THEN
                    v_errors := v_errors || format('SalesOrderLine %s has NULL width_m. Cannot calculate per_width quantity. Component: %s', 
                        v_sales_order_line.id, v_bom_component.id);
                    CONTINUE;
                END IF;
                v_calculated_qty := v_sales_order_line.width_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'per_area' THEN
                IF v_sales_order_line.width_m IS NULL OR v_sales_order_line.height_m IS NULL THEN
                    v_errors := v_errors || format('SalesOrderLine %s has NULL width_m or height_m. Cannot calculate per_area quantity. Component: %s', 
                        v_sales_order_line.id, v_bom_component.id);
                    CONTINUE;
                END IF;
                v_calculated_qty := v_sales_order_line.width_m * v_sales_order_line.height_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'fixed' THEN
                v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
            ELSE
                v_errors := v_errors || format('Invalid or missing qty_type for component %s', v_bom_component.id);
                CONTINUE;
            END IF;
            
            IF v_calculated_qty IS NULL OR v_calculated_qty <= 0 THEN
                v_errors := v_errors || format('Calculated qty is NULL or <= 0 for component %s', v_bom_component.id);
                CONTINUE;
            END IF;
            
            -- Normalize UOM
            IF v_bom_component.uom IS NULL OR TRIM(v_bom_component.uom) = '' THEN
                v_errors := v_errors || format('Component %s has NULL or empty uom', v_bom_component.id);
                CONTINUE;
            END IF;
            
            v_normalized_uom := CASE 
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('PCS', 'PIECE', 'PIECES') THEN 'ea'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('SET', 'SETS') THEN 'ea'
                WHEN v_bom_component.component_role = 'fabric' THEN 'm2'
                WHEN v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'chain') THEN 'm'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('FT', 'FEET', 'FOOT', 'MTS', 'M', 'METER', 'METERS') THEN 'm'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('M2', 'SQM', 'SQ_M') THEN 'm2'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('EA', 'EACH') THEN 'ea'
                ELSE NULL
            END;
            
            IF v_normalized_uom IS NULL THEN
                v_errors := v_errors || format('Invalid UOM "%s" for component %s', v_bom_component.uom, v_bom_component.id);
                CONTINUE;
            END IF;
            
            -- Map category_code
            v_category_code := CASE 
                WHEN v_bom_component.component_role = 'fabric' THEN 'fabric'
                WHEN v_bom_component.component_role = 'tube' THEN 'tube'
                WHEN v_bom_component.component_role = 'motor' THEN 'motor'
                WHEN v_bom_component.component_role = 'bracket' THEN 'bracket'
                WHEN v_bom_component.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_bom_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_bom_component.component_role LIKE '%bottom_rail%' 
                     OR v_bom_component.component_role LIKE '%bottom_channel%' 
                     OR v_bom_component.component_role LIKE '%bottom_bar%' THEN 'bottom_channel'
                ELSE 'accessory'
            END;
            
            -- Calculate costs
            v_unit_cost_exw := COALESCE(CAST(v_catalog_item.cost_exw AS numeric(12,4)), 0);
            v_total_cost_exw := v_unit_cost_exw * v_calculated_qty;
            
            IF v_unit_cost_exw > 0 THEN
                DECLARE
                    v_unit_cost_with_taxes numeric(12,4);
                    v_msrp_sale_in numeric(12,4);
                BEGIN
                    v_unit_cost_with_taxes := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                    v_msrp_sale_in := v_unit_cost_with_taxes / (1 - (v_min_margin_pct / 100.0));
                    v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                    v_total_msrp_sale_out := v_unit_msrp_sale_out * v_calculated_qty;
                END;
            ELSE
                v_unit_msrp_sale_out := 0;
                v_total_msrp_sale_out := 0;
            END IF;
            
            v_bom_total_cost := v_bom_total_cost + v_total_cost_exw;
            
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
                category_code,
                unit_cost_exw,
                total_cost_exw,
                unit_msrp_sale_out,
                total_msrp_sale_out,
                cut_l_mm,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_mo.organization_id,
                v_bom_instance_id,
                v_catalog_item.id,
                v_catalog_item.sku,
                v_bom_component.component_role,
                v_calculated_qty,
                v_normalized_uom,
                COALESCE(v_catalog_item.description, v_catalog_item.item_name),
                v_category_code,
                COALESCE(v_unit_cost_exw, 0)::numeric(12,4),
                COALESCE(v_total_cost_exw, 0)::numeric(12,4),
                COALESCE(v_unit_msrp_sale_out, 0)::numeric(12,4),
                COALESCE(v_total_msrp_sale_out, 0)::numeric(12,4),
                CASE 
                    WHEN v_bom_component.qty_type = 'per_width' 
                         OR v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
                    THEN COALESCE(v_sales_order_line.width_m, 0) * 1000.0
                    ELSE NULL 
                END,
                false,
                now(),
                now()
            );
            
            v_created_lines := v_created_lines + 1;
            v_total_bom_lines := v_total_bom_lines + 1;
        END LOOP;
        
        IF v_created_lines = 0 THEN
            v_warnings := v_warnings || format('BomInstance % created but 0 BomInstanceLines generated (template: %, SalesOrderLine: %)', 
                v_bom_instance_id, v_bom_template_id, v_sales_order_line.id);
            RAISE WARNING 'BomInstance % created but 0 lines generated', v_bom_instance_id;
        ELSE
            RAISE NOTICE '✅ Created % BomInstanceLines for BomInstance %', v_created_lines, v_bom_instance_id;
        END IF;
        
        -- Calculate BOM-level costs
        v_bom_labor_cost := v_bom_total_cost * (v_labor_percentage / 100.0);
        v_bom_total_cost_with_labor := v_bom_total_cost + v_bom_labor_cost;
        
        DECLARE
            v_bom_msrp_sale_in numeric(12,4);
        BEGIN
            v_bom_msrp_sale_in := v_bom_total_cost_with_labor / (1 - (v_min_margin_pct / 100.0));
            v_bom_msrp_sale_out := v_bom_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
        END;
        
        -- Update BomInstance with totals
        UPDATE "BomInstances"
        SET 
            labor_cost = v_bom_labor_cost,
            total_cost_with_labor = v_bom_total_cost_with_labor,
            total_msrp_sale_out_with_labor = v_bom_msrp_sale_out,
            updated_at = now()
        WHERE id = v_bom_instance_id;
        
        -- Build result for this line
        v_line_result := jsonb_build_object(
            'sales_order_line_id', v_sales_order_line.id,
            'bom_instance_id', v_bom_instance_id,
            'created_lines', v_created_lines,
            'total_cost', v_bom_total_cost_with_labor,
            'total_msrp_sale_out', v_bom_msrp_sale_out
        );
        
        v_results := v_results || jsonb_build_array(v_line_result);
    END LOOP;
    
    -- Return summary with counts and warnings
    RETURN jsonb_build_object(
        'ok', array_length(v_errors, 1) IS NULL OR array_length(v_errors, 1) = 0,
        'manufacturing_order_id', p_manufacturing_order_id,
        'mo_lines_processed', v_mo_lines_processed,
        'bom_instances_created', v_total_bom_instances,
        'bom_instance_lines_created', v_total_bom_lines,
        'warnings', COALESCE(v_warnings, ARRAY[]::text[]),
        'errors', COALESCE(v_errors, ARRAY[]::text[]),
        'results', v_results
    );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'Generates BOM for a ManufacturingOrder by processing all ManufacturingOrderLines. Creates BomInstances with manufacturing_order_id (required) and sales_order_line_id (correct naming).';

GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;

-- ====================================================
-- STEP 2: Fix permissions for vw_bom_instances_safe
-- ====================================================

GRANT SELECT ON public.vw_bom_instances_safe TO anon;
GRANT SELECT ON public.vw_bom_instances_safe TO authenticated;

COMMIT;

