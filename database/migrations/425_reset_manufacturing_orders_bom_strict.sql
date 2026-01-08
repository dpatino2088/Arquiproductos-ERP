-- ====================================================
-- Migration 425: RESET TOTAL Manufacturing Orders + BOM Generation
-- ====================================================
-- CORE PRINCIPLE: SalesOrderLine is the SINGLE SOURCE OF TRUTH
-- 
-- Rules:
-- 1. ManufacturingOrder references EXACTLY ONE SalesOrderLine (one-to-one)
-- 2. BOM generation uses ONLY SalesOrderLine snapshot values
-- 3. NO inference, NO auto-select, NO heuristics
-- 4. Fabric MUST match EXACTLY: collection_name + variant_name
-- 5. If ANY mismatch → FAIL HARD
-- 6. UOM normalization: pcs→ea, set→ea, fabric→m2, tubes→m
-- ====================================================

SET search_path = public;

-- ====================================================
-- PART 1: Ensure ManufacturingOrders.sales_order_line_id exists
-- ====================================================

DO $$
BEGIN
    -- Add sales_order_line_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ManufacturingOrders' 
        AND column_name = 'sales_order_line_id'
    ) THEN
        ALTER TABLE "ManufacturingOrders" 
        ADD COLUMN sales_order_line_id uuid NULL 
        REFERENCES "SalesOrderLines"(id) ON DELETE RESTRICT;
        
        RAISE NOTICE '✅ Added sales_order_line_id column to ManufacturingOrders';
        
        -- Try to backfill from sale_order_id (if possible)
        -- NOTE: This assumes one ManufacturingOrder per SaleOrder
        -- After migration, all NEW ManufacturingOrders MUST have sales_order_line_id
        UPDATE "ManufacturingOrders" mo
        SET sales_order_line_id = (
            SELECT sol.id 
            FROM "SalesOrderLines" sol 
            WHERE sol.sale_order_id = mo.sale_order_id 
            AND sol.deleted = false 
            ORDER BY sol.line_number ASC 
            LIMIT 1
        )
        WHERE mo.sales_order_line_id IS NULL
        AND mo.deleted = false;
        
        RAISE NOTICE '✅ Backfilled sales_order_line_id for existing ManufacturingOrders (if possible)';
    END IF;
    
    -- Make it NOT NULL (after backfill, if all have values)
    -- If some are still NULL, we'll make it NOT NULL in a separate step after manual fix
    -- For now, just add a check constraint to warn
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'ManufacturingOrders' 
        AND constraint_name = 'check_manufacturing_orders_has_sales_order_line_id'
    ) THEN
        ALTER TABLE "ManufacturingOrders"
        ADD CONSTRAINT check_manufacturing_orders_has_sales_order_line_id
        CHECK (
            deleted = true OR sales_order_line_id IS NOT NULL
        );
        
        RAISE NOTICE '✅ Added check constraint: ManufacturingOrders MUST have sales_order_line_id (unless deleted)';
    END IF;
    
    -- Add index for sales_order_line_id lookups
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'ManufacturingOrders' 
        AND indexname = 'idx_manufacturing_orders_sales_order_line_id'
    ) THEN
        CREATE INDEX idx_manufacturing_orders_sales_order_line_id 
        ON "ManufacturingOrders"(sales_order_line_id) 
        WHERE deleted = false;
        
        RAISE NOTICE '✅ Added index on ManufacturingOrders.sales_order_line_id';
    END IF;
END $$;

-- ====================================================
-- PART 2: Completely rewrite generate_bom_for_manufacturing_order
-- ====================================================
-- STRICT RULES:
-- 1. Input: manufacturing_order_id
-- 2. Load ManufacturingOrder → get sales_order_line_id
-- 3. Load EXACTLY ONE SalesOrderLine using sales_order_line_id
-- 4. If sales_order_line_id is NULL → THROW ERROR
-- 5. Resolve BOMTemplate: Match ONLY by sales_order_line.product_type
-- 6. For fabric: MUST match collection_name + variant_name EXACTLY
-- 7. UOM normalization: pcs→ea, set→ea, fabric→m2, tubes→m
-- 8. If ANY mismatch → THROW ERROR
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
    v_sales_order_line RECORD;
    v_bom_instance_id uuid;
    v_bom_template_id uuid;
    v_bom_component RECORD;
    v_catalog_item RECORD;
    v_fabric_catalog_item_id uuid;
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
    v_formula_params jsonb;
BEGIN
    -- ====================================================
    -- STEP 1: Load ManufacturingOrder
    -- ====================================================
    SELECT *
    INTO v_mo
    FROM "ManufacturingOrders"
    WHERE id = p_manufacturing_order_id;
    
    IF v_mo.id IS NULL THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    IF v_mo.sales_order_line_id IS NULL THEN
        RAISE EXCEPTION 'ManufacturingOrder % has no sales_order_line_id', p_manufacturing_order_id;
    END IF;
    
    IF v_mo.deleted = true THEN
        RAISE EXCEPTION 'ManufacturingOrder % is deleted', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '🚀 Starting STRICT BOM generation for ManufacturingOrder: % (Organization: %)', 
        v_mo.id, v_mo.organization_id;
    
    -- ====================================================
    -- STEP 3: Load EXACTLY ONE SalesOrderLine (SINGLE SOURCE OF TRUTH)
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
    WHERE sol.id = v_manufacturing_order.sales_order_line_id
    AND sol.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrderLine % not found for ManufacturingOrder %. This is MANDATORY.', 
            v_manufacturing_order.sales_order_line_id, p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '✅ Loaded SalesOrderLine % (product_type: %, collection: %, variant: %)', 
        v_sales_order_line.id, v_sales_order_line.product_type, 
        v_sales_order_line.collection_name, v_sales_order_line.variant_name;
    
    -- ====================================================
    -- STEP 4: Resolve BOMTemplate (ONLY by product_type)
    -- ====================================================
    IF v_sales_order_line.product_type IS NULL OR TRIM(v_sales_order_line.product_type) = '' THEN
        RAISE EXCEPTION 'SalesOrderLine % has NULL or empty product_type. Cannot resolve BOMTemplate.', 
            v_sales_order_line.id;
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
        RAISE EXCEPTION 'No active BOMTemplate found for product_type: %. SalesOrderLine: %', 
            v_sales_order_line.product_type, v_sales_order_line.id;
    END IF;
    
    RAISE NOTICE '✅ Resolved BOMTemplate % for product_type: %', 
        v_bom_template_id, v_sales_order_line.product_type;
    
    -- ====================================================
    -- STEP 5: Delete existing BOM (start fresh)
    -- ====================================================
    -- Soft-delete existing BomInstances and BomInstanceLines
    UPDATE "BomInstanceLines" bil
    SET deleted = true, updated_at = now()
    WHERE bil.bom_instance_id IN (
        SELECT bi.id
        FROM "BomInstances" bi
        WHERE bi.sale_order_line_id = v_sales_order_line.id
        AND bi.deleted = false
    );
    
    UPDATE "BomInstances" bi
    SET deleted = true, updated_at = now()
    WHERE bi.sale_order_line_id = v_sales_order_line.id
    AND bi.deleted = false;
    
    -- ====================================================
    -- STEP 6: Create new BomInstance
    -- ====================================================
    INSERT INTO "BomInstances" (
        organization_id,
        sale_order_line_id,
        quote_line_id,
        bom_template_id,
        deleted,
        created_at,
        updated_at,
        generated_at
    ) VALUES (
        v_manufacturing_order.organization_id,
        v_sales_order_line.id,
        v_sales_order_line.quote_line_id,
        v_bom_template_id,
        false,
        now(),
        now(),
        now()
    ) RETURNING id INTO v_bom_instance_id;
    
    RAISE NOTICE '✅ Created BomInstance % for SalesOrderLine %', 
        v_bom_instance_id, v_sales_order_line.id;
    
    -- ====================================================
    -- STEP 7: Load CostSettings
    -- ====================================================
    SELECT 
        shipping_percentage,
        import_tax_percent,
        min_margin_pct,
        discount_distributor_pct,
        labor_percentage
    INTO v_cost_settings
    FROM "CostSettings"
    WHERE organization_id = v_manufacturing_order.organization_id
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
    -- STEP 8: Process BOMComponents (STRICT: NO auto-select, NO inference)
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
        AND bc.component_item_id IS NOT NULL  -- ONLY fixed components (NO auto-select)
        ORDER BY bc.created_at
    LOOP
        RAISE NOTICE '📦 Processing BOMComponent % (role: %, item_id: %)', 
            v_bom_component.id, v_bom_component.component_role, v_bom_component.component_item_id;
        
        -- ====================================================
        -- STEP 8A: STRICT FABRIC VALIDATION
        -- ====================================================
        IF v_bom_component.component_role = 'fabric' THEN
            v_fabric_count := v_fabric_count + 1;
            
            IF v_fabric_count > 1 THEN
                RAISE EXCEPTION 'BOMTemplate % allows MORE THAN ONE fabric component. Only EXACTLY ONE fabric is allowed. Component IDs: %', 
                    v_bom_template_id, v_bom_component.id;
            END IF;
            
            -- STRICT MATCH: collection_name + variant_name MUST match EXACTLY
            IF v_sales_order_line.collection_name IS NULL OR TRIM(v_sales_order_line.collection_name) = '' THEN
                RAISE EXCEPTION 'SalesOrderLine % has NULL or empty collection_name. Cannot resolve fabric.', 
                    v_sales_order_line.id;
            END IF;
            
            -- Resolve fabric CatalogItem (EXACT match required)
            SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw
            INTO v_catalog_item
            FROM "CatalogItems" ci
            INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE ci.id = v_bom_component.component_item_id
            AND ci.organization_id = v_manufacturing_order.organization_id
            AND ci.deleted = false
            AND ci.active = true
            AND ic.code = 'FABRIC'
            AND ci.collection_name = v_sales_order_line.collection_name
            AND (
                (v_sales_order_line.variant_name IS NULL AND ci.variant_name IS NULL)
                OR ci.variant_name = v_sales_order_line.variant_name
            );
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Fabric CatalogItem % does NOT match SalesOrderLine collection_name=% variant_name=%. EXACT match required. SalesOrderLine: %', 
                    v_bom_component.component_item_id, 
                    v_sales_order_line.collection_name, 
                    v_sales_order_line.variant_name,
                    v_sales_order_line.id;
            END IF;
            
            v_fabric_catalog_item_id := v_catalog_item.id;
            
            RAISE NOTICE '✅ Fabric MATCH: CatalogItem % (SKU: %) matches collection=% variant=%', 
                v_catalog_item.id, v_catalog_item.sku, 
                v_sales_order_line.collection_name, v_sales_order_line.variant_name;
        ELSE
            -- Non-fabric component: use component_item_id directly
            SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw
            INTO v_catalog_item
            FROM "CatalogItems" ci
            WHERE ci.id = v_bom_component.component_item_id
            AND ci.organization_id = v_manufacturing_order.organization_id
            AND ci.deleted = false
            AND ci.active = true;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'CatalogItem % (component_id: %, role: %) not found or inactive. SalesOrderLine: %', 
                    v_bom_component.component_item_id, v_bom_component.id, v_bom_component.component_role,
                    v_sales_order_line.id;
            END IF;
        END IF;
        
        -- ====================================================
        -- STEP 8B: Calculate quantity (using ONLY SalesOrderLine dimensions)
        -- ====================================================
        IF v_bom_component.qty_formula_code IS NOT NULL THEN
            -- Formula-based calculation
            IF v_bom_component.qty_formula_code = 'CHAIN_HEIGHT_FACTOR' THEN
                v_formula_params := v_bom_component.qty_formula_params;
                
                IF v_formula_params IS NULL OR 
                   (v_formula_params->>'height_factor') IS NULL OR 
                   (v_formula_params->>'mult') IS NULL THEN
                    RAISE EXCEPTION 'Invalid qty_formula_params for CHAIN_HEIGHT_FACTOR. Component: %', 
                        v_bom_component.id;
                END IF;
                
                IF v_sales_order_line.height_m IS NULL THEN
                    RAISE EXCEPTION 'SalesOrderLine % has NULL height_m. Cannot calculate CHAIN_HEIGHT_FACTOR. Component: %', 
                        v_sales_order_line.id, v_bom_component.id;
                END IF;
                
                v_calculated_qty := v_sales_order_line.height_m 
                    * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75)
                    * COALESCE((v_formula_params->>'mult')::numeric, 2);
            ELSE
                RAISE EXCEPTION 'Unknown qty_formula_code: % for component %', 
                    v_bom_component.qty_formula_code, v_bom_component.id;
            END IF;
        ELSIF v_bom_component.qty_type = 'per_width' THEN
            IF v_sales_order_line.width_m IS NULL THEN
                RAISE EXCEPTION 'SalesOrderLine % has NULL width_m. Cannot calculate per_width quantity. Component: %', 
                    v_sales_order_line.id, v_bom_component.id;
            END IF;
            v_calculated_qty := v_sales_order_line.width_m * COALESCE(v_bom_component.qty_value, 1);
        ELSIF v_bom_component.qty_type = 'per_area' THEN
            IF v_sales_order_line.width_m IS NULL OR v_sales_order_line.height_m IS NULL THEN
                RAISE EXCEPTION 'SalesOrderLine % has NULL width_m or height_m. Cannot calculate per_area quantity. Component: %', 
                    v_sales_order_line.id, v_bom_component.id;
            END IF;
            v_calculated_qty := v_sales_order_line.width_m * v_sales_order_line.height_m * COALESCE(v_bom_component.qty_value, 1);
        ELSIF v_bom_component.qty_type = 'fixed' THEN
            v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
        ELSE
            RAISE EXCEPTION 'Invalid or missing qty_type for component %. Must be: fixed, per_width, per_area, or have qty_formula_code.', 
                v_bom_component.id;
        END IF;
        
        IF v_calculated_qty IS NULL OR v_calculated_qty <= 0 THEN
            RAISE EXCEPTION 'Calculated qty is NULL or <= 0 for component %. Component: %, qty_type: %, qty_value: %', 
                v_calculated_qty, v_bom_component.id, v_bom_component.qty_type, v_bom_component.qty_value;
        END IF;
        
        -- ====================================================
        -- STEP 8C: Normalize UOM (MANDATORY)
        -- ====================================================
        IF v_bom_component.uom IS NULL OR TRIM(v_bom_component.uom) = '' THEN
            RAISE EXCEPTION 'Component % has NULL or empty uom. UOM is MANDATORY.', 
                v_bom_component.id;
        END IF;
        
        -- Normalize UOM: pcs→ea, set→ea, fabric→m2, tubes→m
        v_normalized_uom := CASE 
            WHEN UPPER(TRIM(v_bom_component.uom)) IN ('PCS', 'PIECE', 'PIECES') THEN 'ea'
            WHEN UPPER(TRIM(v_bom_component.uom)) IN ('SET', 'SETS') THEN 'ea'
            WHEN v_bom_component.component_role = 'fabric' THEN 'm2'  -- Fabric ALWAYS m2
            WHEN v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'chain') THEN 'm'  -- Linear ALWAYS m
            WHEN UPPER(TRIM(v_bom_component.uom)) IN ('FT', 'FEET', 'FOOT', 'MTS', 'M', 'METER', 'METERS') THEN 'm'
            WHEN UPPER(TRIM(v_bom_component.uom)) IN ('M2', 'SQM', 'SQ_M') THEN 'm2'
            WHEN UPPER(TRIM(v_bom_component.uom)) IN ('EA', 'EACH') THEN 'ea'
            ELSE NULL  -- Will validate below
        END;
        
        -- Validate UOM normalization (FAIL HARD if invalid)
        IF v_normalized_uom IS NULL THEN
            RAISE EXCEPTION 'Invalid UOM "%" for component % (role: %). Allowed: m, m2, ea (or normalized: pcs→ea, set→ea, ft→m)', 
                v_bom_component.uom, v_bom_component.id, v_bom_component.component_role;
        END IF;
        
        -- ====================================================
        -- STEP 8D: Map category_code
        -- ====================================================
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
        
        -- ====================================================
        -- STEP 8E: Calculate costs
        -- ====================================================
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
        
        -- ====================================================
        -- STEP 8F: Insert BomInstanceLine
        -- ====================================================
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
            v_manufacturing_order.organization_id,
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
                THEN COALESCE(v_sales_order_line.width_m, 0) * 1000.0  -- Convert m to mm
                ELSE NULL 
            END,
            false,
            now(),
            now()
        );
        
        v_created_lines := v_created_lines + 1;
        
        RAISE NOTICE '✅ Created BomInstanceLine: SKU=%, role=%, qty=%, uom=%', 
            v_catalog_item.sku, v_bom_component.component_role, v_calculated_qty, v_normalized_uom;
    END LOOP;
    
    -- ====================================================
    -- STEP 9: Validate fabric count (EXACTLY ONE)
    -- ====================================================
    IF v_fabric_count = 0 THEN
        RAISE WARNING '⚠️ No fabric component found in BOMTemplate %. This may be intentional for non-fabric products.', 
            v_bom_template_id;
    ELSIF v_fabric_count > 1 THEN
        RAISE EXCEPTION 'BOMTemplate % has % fabric components. Only EXACTLY ONE fabric is allowed.', 
            v_bom_template_id, v_fabric_count;
    END IF;
    
    -- ====================================================
    -- STEP 10: Calculate BOM-level costs (with labor)
    -- ====================================================
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
    
    -- ====================================================
    -- STEP 11: Final validation (FAIL HARD if no lines created)
    -- ====================================================
    IF v_created_lines = 0 THEN
        RAISE EXCEPTION 'BOM generation completed but 0 lines were created. ManufacturingOrder: %, SalesOrderLine: %, BOMTemplate: %', 
            p_manufacturing_order_id, v_sales_order_line.id, v_bom_template_id;
    END IF;
    
    RAISE NOTICE '✅ BOM generation completed: % lines created, total_cost=%, msrp_sale_out=%', 
        v_created_lines, v_bom_total_cost_with_labor, v_bom_msrp_sale_out;
    
    -- Return success
    RETURN jsonb_build_object(
        'ok', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'sales_order_line_id', v_sales_order_line.id,
        'bom_instance_id', v_bom_instance_id,
        'bom_template_id', v_bom_template_id,
        'created_lines', v_created_lines,
        'fabric_count', v_fabric_count,
        'total_cost', v_bom_total_cost_with_labor,
        'total_msrp_sale_out', v_bom_msrp_sale_out,
        'errors', COALESCE(v_errors, ARRAY[]::text[])
    );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'STRICT BOM generation: SalesOrderLine is the SINGLE SOURCE OF TRUTH. NO inference, NO auto-select, NO heuristics. Fabric MUST match collection_name + variant_name EXACTLY. If ANY mismatch → FAIL HARD.';

GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;

-- ====================================================
-- STEP 12: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 425 completed successfully!';
    RAISE NOTICE '📋 Changes:';
    RAISE NOTICE '   - Added sales_order_line_id to ManufacturingOrders (one-to-one relationship)';
    RAISE NOTICE '   - Completely rewrote generate_bom_for_manufacturing_order (STRICT rules)';
    RAISE NOTICE '   - Fabric matching: EXACT collection_name + variant_name';
    RAISE NOTICE '   - UOM normalization: pcs→ea, set→ea, fabric→m2, tubes→m';
    RAISE NOTICE '   - FAIL HARD on ANY mismatch or missing data';
END $$;

