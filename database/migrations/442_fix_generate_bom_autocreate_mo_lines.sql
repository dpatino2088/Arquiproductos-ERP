-- =========================================================
-- Migration 442: Auto-create ManufacturingOrderLines in BOM RPC
-- =========================================================
-- OBJETIVO: Integrar auto-create de ManufacturingOrderLines
-- con la lógica completa de generación de BOM
-- =========================================================

SET search_path = public;

BEGIN;

-- =========================================================
-- Reemplazar función RPC: generate_bom_for_manufacturing_order
-- =========================================================

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
    v_total_bom_instances integer := 0;
    v_total_bom_lines integer := 0;
    v_mo_lines_processed integer := 0;
    
    -- Counts before/after
    v_mo_lines_before integer := 0;
    v_mo_lines_after integer := 0;
    v_created_mo_lines integer := 0;
    v_bom_instances_before integer := 0;
    v_bom_instances_after integer := 0;
    v_bom_lines_before integer := 0;
    v_bom_lines_after integer := 0;
BEGIN
    -- ====================================================
    -- STEP 1: Load ManufacturingOrder
    -- ====================================================
    SELECT *
    INTO v_mo
    FROM public."ManufacturingOrders"
    WHERE id = p_manufacturing_order_id;
    
    IF v_mo.id IS NULL THEN
        v_errors := v_errors || 'MO not found';
        RETURN jsonb_build_object('ok', false, 'errors', v_errors, 'warnings', v_warnings);
    END IF;
    
    IF v_mo.deleted = true THEN
        v_errors := v_errors || 'MO is deleted';
        RETURN jsonb_build_object('ok', false, 'errors', v_errors, 'warnings', v_warnings);
    END IF;
    
    IF v_mo.sales_order_id IS NULL THEN
        v_warnings := v_warnings || 'MO has no sales_order_id; cannot auto-create MO lines from SalesOrderLines.';
    END IF;
    
    RAISE NOTICE '[DEBUG] Starting BOM generation for MO: % (Org: %)', 
        v_mo.id::text, v_mo.organization_id::text;
    
    -- ====================================================
    -- STEP 2: Counts BEFORE
    -- ====================================================
    SELECT COUNT(*)
    INTO v_mo_lines_before
    FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id
        AND deleted = false;
    
    SELECT COUNT(*)
    INTO v_bom_instances_before
    FROM public."BomInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id
        AND deleted = false;
    
    SELECT COUNT(*)
    INTO v_bom_lines_before
    FROM public."BomInstanceLines" bil
    JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
        AND bi.deleted = false
        AND bil.deleted = false;
    
    RAISE NOTICE '[DEBUG] Counts BEFORE - MO Lines: %, BomInstances: %, BomLines: %', 
        v_mo_lines_before, v_bom_instances_before, v_bom_lines_before;
    
    -- ====================================================
    -- STEP 3: AUTO-CREATE ManufacturingOrderLines
    -- ====================================================
    IF v_mo_lines_before = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        RAISE NOTICE '[DEBUG] No ManufacturingOrderLines found, creating from SalesOrderLines...';
        
        INSERT INTO public."ManufacturingOrderLines"(
            manufacturing_order_id, 
            sales_order_line_id, 
            organization_id,
            status
        )
        SELECT
            p_manufacturing_order_id,
            sol.id,
            COALESCE(v_mo.organization_id, sol.organization_id),
            'planned'
        FROM public."SalesOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id
            AND COALESCE(sol.deleted, false) = false
            AND COALESCE(sol.archived, false) = false
        ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;
        
        GET DIAGNOSTICS v_created_mo_lines = ROW_COUNT;
        
        RAISE NOTICE '[DEBUG] Created % ManufacturingOrderLines', v_created_mo_lines;
        
        IF v_created_mo_lines = 0 THEN
            v_warnings := v_warnings || 'No SalesOrderLines available to create ManufacturingOrderLines.';
        END IF;
    END IF;
    
    -- Count MO lines after auto-create
    SELECT COUNT(*)
    INTO v_mo_lines_after
    FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id
        AND deleted = false
        AND archived = false;
    
    -- If still no lines, stop early
    IF v_mo_lines_after = 0 THEN
        v_warnings := v_warnings || 'MO has 0 ManufacturingOrderLines; BOM generation skipped.';
        RETURN jsonb_build_object(
            'ok', true,
            'mo_lines_before', v_mo_lines_before,
            'mo_lines_after', v_mo_lines_after,
            'mo_lines_created', v_created_mo_lines,
            'bom_instances_before', v_bom_instances_before,
            'bom_instances_after', v_bom_instances_before,
            'bom_instances_created', 0,
            'bom_instance_lines_before', v_bom_lines_before,
            'bom_instance_lines_after', v_bom_lines_before,
            'bom_instance_lines_created', 0,
            'warnings', v_warnings,
            'errors', v_errors
        );
    END IF;
    
    -- ====================================================
    -- STEP 4: Load CostSettings
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
        RAISE NOTICE '[DEBUG] Loaded CostSettings (labor_pct: %)', v_labor_percentage;
    ELSE
        RAISE NOTICE '[DEBUG] No CostSettings found, using defaults';
    END IF;
    
    -- ====================================================
    -- STEP 5: Process each ManufacturingOrderLine
    -- ====================================================
    FOR v_mo_line IN
        SELECT mol.sales_order_line_id
        FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
            AND mol.deleted = false
            AND mol.archived = false
        ORDER BY mol.created_at ASC
    LOOP
        v_mo_lines_processed := v_mo_lines_processed + 1;
        
        -- Reset per-line variables
        v_bom_instance_id := NULL;
        v_bom_template_id := NULL;
        v_fabric_count := 0;
        v_bom_total_cost := 0;
        v_created_lines := 0;
        
        RAISE NOTICE '[DEBUG] Processing MO Line % (sales_order_line_id: %)', 
            v_mo_lines_processed, v_mo_line.sales_order_line_id::text;
        
        -- ====================================================
        -- STEP 5a: Load SalesOrderLine
        -- ====================================================
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
            v_warnings := v_warnings || format('SalesOrderLine %s not found', v_mo_line.sales_order_line_id);
            RAISE WARNING 'SalesOrderLine % not found', v_mo_line.sales_order_line_id::text;
            CONTINUE;
        END IF;
        
        -- ====================================================
        -- STEP 5b: Resolve BOMTemplate
        -- ====================================================
        IF v_sales_order_line.product_type IS NULL OR TRIM(v_sales_order_line.product_type) = '' THEN
            v_warnings := v_warnings || format('SalesOrderLine %s has NULL or empty product_type', v_sales_order_line.id);
            RAISE WARNING 'SalesOrderLine % has NULL or empty product_type', v_sales_order_line.id::text;
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
            v_warnings := v_warnings || format('No active BOMTemplate found for product_type: %s (SalesOrderLine: %s)', 
                v_sales_order_line.product_type, v_sales_order_line.id);
            RAISE WARNING 'No active BOMTemplate found for product_type: %', v_sales_order_line.product_type;
            CONTINUE;
        END IF;
        
        RAISE NOTICE '[DEBUG] Resolved BOMTemplate % for product_type: %', 
            v_bom_template_id::text, v_sales_order_line.product_type;
        
        -- ====================================================
        -- STEP 5c: Delete existing BOM for this SalesOrderLine
        -- ====================================================
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
        
        -- ====================================================
        -- STEP 5d: Create BomInstance with manufacturing_order_id
        -- ====================================================
        INSERT INTO "BomInstances" (
            organization_id,
            manufacturing_order_id,
            sales_order_line_id,
            quote_line_id,
            bom_template_id,
            status,
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
            'draft',
            false,
            now(),
            now(),
            now()
        ) RETURNING id INTO v_bom_instance_id;
        
        IF v_bom_instance_id IS NULL THEN
            v_warnings := v_warnings || format('Failed to create BomInstance for SalesOrderLine %s', v_sales_order_line.id);
            RAISE WARNING 'Failed to create BomInstance for SalesOrderLine %', v_sales_order_line.id::text;
            CONTINUE;
        END IF;
        
        v_total_bom_instances := v_total_bom_instances + 1;
        RAISE NOTICE '[DEBUG] Created BomInstance % (manufacturing_order_id: %, sales_order_line_id: %)', 
            v_bom_instance_id::text, p_manufacturing_order_id::text, v_sales_order_line.id::text;
        
        -- ====================================================
        -- STEP 5e: Process BOMComponents and create BomInstanceLines
        -- ====================================================
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
                    v_warnings := v_warnings || format('BOMTemplate %s allows MORE THAN ONE fabric component. Only EXACTLY ONE fabric is allowed. Component ID: %s', 
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
                    v_warnings := v_warnings || format('Fabric CatalogItem %s does NOT match SalesOrderLine collection_name=%s variant_name=%s. SalesOrderLine: %s', 
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
                    v_warnings := v_warnings || format('CatalogItem %s (component_id: %s, role: %s) not found or inactive. SalesOrderLine: %s', 
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
                        v_warnings := v_warnings || format('Invalid qty_formula_params for CHAIN_HEIGHT_FACTOR. Component: %s', v_bom_component.id);
                        CONTINUE;
                    END IF;
                    
                    IF v_sales_order_line.height_m IS NULL THEN
                        v_warnings := v_warnings || format('SalesOrderLine %s has NULL height_m. Cannot calculate CHAIN_HEIGHT_FACTOR. Component: %s', 
                            v_sales_order_line.id, v_bom_component.id);
                        CONTINUE;
                    END IF;
                    
                    v_calculated_qty := v_sales_order_line.height_m 
                        * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75)
                        * COALESCE((v_formula_params->>'mult')::numeric, 2);
                ELSE
                    v_warnings := v_warnings || format('Unknown qty_formula_code: %s for component %s', 
                        v_bom_component.qty_formula_code, v_bom_component.id);
                    CONTINUE;
                END IF;
            ELSIF v_bom_component.qty_type = 'per_width' THEN
                IF v_sales_order_line.width_m IS NULL THEN
                    v_warnings := v_warnings || format('SalesOrderLine %s has NULL width_m. Cannot calculate per_width quantity. Component: %s', 
                        v_sales_order_line.id, v_bom_component.id);
                    CONTINUE;
                END IF;
                v_calculated_qty := v_sales_order_line.width_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'per_area' THEN
                IF v_sales_order_line.width_m IS NULL OR v_sales_order_line.height_m IS NULL THEN
                    v_warnings := v_warnings || format('SalesOrderLine %s has NULL width_m or height_m. Cannot calculate per_area quantity. Component: %s', 
                        v_sales_order_line.id, v_bom_component.id);
                    CONTINUE;
                END IF;
                v_calculated_qty := v_sales_order_line.width_m * v_sales_order_line.height_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'fixed' THEN
                v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
            ELSE
                v_warnings := v_warnings || format('Invalid or missing qty_type for component %s', v_bom_component.id);
                CONTINUE;
            END IF;
            
            IF v_calculated_qty IS NULL OR v_calculated_qty <= 0 THEN
                v_warnings := v_warnings || format('Calculated qty is NULL or <= 0 for component %s', v_bom_component.id);
                CONTINUE;
            END IF;
            
            -- Normalize UOM
            IF v_bom_component.uom IS NULL OR TRIM(v_bom_component.uom) = '' THEN
                v_warnings := v_warnings || format('Component %s has NULL or empty uom', v_bom_component.id);
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
                v_warnings := v_warnings || format('Invalid UOM "%s" for component %s', v_bom_component.uom, v_bom_component.id);
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
            RAISE WARNING 'BomInstance % created but 0 lines generated', v_bom_instance_id::text;
        ELSE
            RAISE NOTICE '[DEBUG] Created % BomInstanceLines for BomInstance %', v_created_lines, v_bom_instance_id::text;
        END IF;
        
        -- ====================================================
        -- STEP 5f: Calculate BOM-level costs and update BomInstance
        -- ====================================================
        v_bom_labor_cost := v_bom_total_cost * (v_labor_percentage / 100.0);
        v_bom_total_cost_with_labor := v_bom_total_cost + v_bom_labor_cost;
        
        DECLARE
            v_bom_msrp_sale_in numeric(12,4);
        BEGIN
            v_bom_msrp_sale_in := v_bom_total_cost_with_labor / (1 - (v_min_margin_pct / 100.0));
            v_bom_msrp_sale_out := v_bom_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
        END;
        
        UPDATE "BomInstances"
        SET 
            labor_cost = v_bom_labor_cost,
            total_cost_with_labor = v_bom_total_cost_with_labor,
            total_msrp_sale_out_with_labor = v_bom_msrp_sale_out,
            updated_at = now()
        WHERE id = v_bom_instance_id;
        
    END LOOP;
    
    -- ====================================================
    -- STEP 6: Counts AFTER
    -- ====================================================
    SELECT COUNT(*)
    INTO v_bom_instances_after
    FROM public."BomInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id
        AND deleted = false;
    
    SELECT COUNT(*)
    INTO v_bom_lines_after
    FROM public."BomInstanceLines" bil
    JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
        AND bi.deleted = false
        AND bil.deleted = false;
    
    RAISE NOTICE '[DEBUG] Counts AFTER - MO Lines: %, BomInstances: %, BomLines: %', 
        v_mo_lines_after, v_bom_instances_after, v_bom_lines_after;
    
    -- ====================================================
    -- STEP 7: Return summary with all counts
    -- ====================================================
    RETURN jsonb_build_object(
        'ok', array_length(v_errors, 1) IS NULL OR array_length(v_errors, 1) = 0,
        'manufacturing_order_id', p_manufacturing_order_id,
        'mo_lines_before', v_mo_lines_before,
        'mo_lines_after', v_mo_lines_after,
        'mo_lines_created', v_created_mo_lines,
        'mo_lines_processed', v_mo_lines_processed,
        'bom_instances_before', v_bom_instances_before,
        'bom_instances_after', v_bom_instances_after,
        'bom_instances_created', v_bom_instances_after - v_bom_instances_before,
        'bom_instance_lines_before', v_bom_lines_before,
        'bom_instance_lines_after', v_bom_lines_after,
        'bom_instance_lines_created', v_bom_lines_after - v_bom_lines_before,
        'warnings', COALESCE(v_warnings, ARRAY[]::text[]),
        'errors', COALESCE(v_errors, ARRAY[]::text[])
    );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'Generates complete BOM for a ManufacturingOrder. Auto-creates ManufacturingOrderLines if missing, then creates BomInstances with manufacturing_order_id (required) and BomInstanceLines from template. Returns detailed counts before/after.';

GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;

COMMIT;

