-- ====================================================
-- Migration 397: Fix BomInstanceLines structure and add cost calculation + MSRP Sale Out
-- ====================================================
-- This migration fixes generate_bom_for_manufacturing_order to:
-- 1. Use correct column names (resolved_part_id, resolved_sku, description, category_code)
-- 2. Add organization_id to all inserts
-- 3. Calculate and store unit_cost_exw and total_cost_exw from CatalogItems (with shipping + import tax)
-- 4. Calculate and store unit_msrp_sale_out and total_msrp_sale_out (PVP - Precio de Venta al Público)
--    Formula: MSRP Sale Out = (Costo Total / (1 - min_margin_pct)) / (1 - descuento_máximo)
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 0: Add MSRP Sale Out columns to BomInstanceLines and Labor columns to BomInstances
-- ====================================================
DO $$
BEGIN
    -- Add unit_msrp_sale_out column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'unit_msrp_sale_out'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN unit_msrp_sale_out numeric(12,4) NULL;
        
        RAISE NOTICE '✅ Added unit_msrp_sale_out column to BomInstanceLines';
    END IF;
    
    -- Add total_msrp_sale_out column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'total_msrp_sale_out'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN total_msrp_sale_out numeric(12,4) NULL;
        
        RAISE NOTICE '✅ Added total_msrp_sale_out column to BomInstanceLines';
    END IF;
    
    -- Add labor_cost column to BomInstances if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'labor_cost'
    ) THEN
        ALTER TABLE "BomInstances" 
        ADD COLUMN labor_cost numeric(12,4) NULL;
        
        RAISE NOTICE '✅ Added labor_cost column to BomInstances';
    END IF;
    
    -- Add total_cost_with_labor column to BomInstances if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'total_cost_with_labor'
    ) THEN
        ALTER TABLE "BomInstances" 
        ADD COLUMN total_cost_with_labor numeric(12,4) NULL;
        
        RAISE NOTICE '✅ Added total_cost_with_labor column to BomInstances';
    END IF;
    
    -- Add total_msrp_sale_out_with_labor column to BomInstances if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'total_msrp_sale_out_with_labor'
    ) THEN
        ALTER TABLE "BomInstances" 
        ADD COLUMN total_msrp_sale_out_with_labor numeric(12,4) NULL;
        
        RAISE NOTICE '✅ Added total_msrp_sale_out_with_labor column to BomInstances';
    END IF;
END $$;

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
    v_catalog_item_cost numeric(12,4) := 0;
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
    -- ✅ Hardware color from QuoteLine (user selection)
    v_quote_line_hardware_color text;
    -- ✅ Cost calculation
    v_unit_cost_exw numeric(12,4) := 0;
    v_total_cost_exw numeric(12,4) := 0;
    v_unit_cost_with_taxes numeric(12,4) := 0;
    v_total_cost_with_taxes numeric(12,4) := 0;
    -- MSRP Sale Out calculation
    v_unit_msrp_sale_out numeric(12,4) := 0;
    v_total_msrp_sale_out numeric(12,4) := 0;
    v_msrp_sale_in numeric(12,4) := 0;
    -- Cost settings for shipping, import tax, and margin
    v_cost_settings RECORD;
    v_shipping_percentage numeric(8,4) := 0;
    v_import_tax_percentage numeric(8,4) := 0;
    v_min_margin_pct numeric(8,4) := 35.0; -- Default 35%
    v_max_discount_pct numeric(8,4) := 65.0; -- Default 65% (Distributor)
    v_labor_percentage numeric(8,4) := 0;
    v_category_import_tax_percentage numeric(8,4) := 0;
    -- Labor calculation at BOM level
    v_bom_total_cost numeric(12,4) := 0;
    v_bom_labor_cost numeric(12,4) := 0;
    v_bom_total_cost_with_labor numeric(12,4) := 0;
    v_bom_msrp_sale_in numeric(12,4) := 0;
    v_bom_msrp_sale_out numeric(12,4) := 0;
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
    
    -- Load CostSettings for shipping, import tax, margin, labor, and maximum discount percentages
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
        -- Distributor has the maximum discount, which defines the minimum selling price (MSRP Sale In)
        v_max_discount_pct := COALESCE(v_cost_settings.discount_distributor_pct, 65.0);
    ELSE
        -- Defaults if no CostSettings found
        v_shipping_percentage := 0;
        v_import_tax_percentage := 0;
        v_min_margin_pct := 35.0;
        v_labor_percentage := 0;
        v_max_discount_pct := 65.0; -- Default 65% for Distributor
    END IF;
    
    RAISE NOTICE '📊 CostSettings loaded: shipping_percentage=%, import_tax_percentage=%, min_margin_pct=%, max_discount_pct=%', 
        v_shipping_percentage, v_import_tax_percentage, v_min_margin_pct, v_max_discount_pct;
    
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
        
        IF NOT FOUND THEN
            RAISE WARNING '   ⚠️  QuoteLine % not found for SalesOrderLine %', v_sale_order_line.quote_line_id, v_sale_order_line.id;
            CONTINUE;
        END IF;
        
        -- ✅ Store hardware_color from QuoteLine (user selection)
        v_quote_line_hardware_color := v_quote_line.hardware_color;
        
        -- ✅ Use bom_template_id from QuoteLine if available (priority over any fallback)
        IF v_quote_line.bom_template_id IS NOT NULL THEN
            v_bom_template_id_from_ql := v_quote_line.bom_template_id;
            RAISE NOTICE '   📋 Using bom_template_id from QuoteLine: %', v_bom_template_id_from_ql;
        ELSE
            RAISE NOTICE '   ⚠️  QuoteLine has no bom_template_id, will only process fixed components';
        END IF;
        
        -- STEP 2A: Create BomInstanceLines from QuoteLineComponents (Fixed components)
        v_lines_count := 0;
        
        RAISE NOTICE '   🔍 Processing QuoteLineComponents for QuoteLine %...', v_sale_order_line.quote_line_id;
        
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
                ci.description as catalog_item_description,
                ci.cost_exw as catalog_item_cost_exw,
                ci.msrp as catalog_item_msrp
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_sale_order_line.quote_line_id
            AND qlc.deleted = false
            AND qlc.source = 'configured_component'
            ORDER BY qlc.component_role
        LOOP
            RAISE NOTICE '   📦 Processing QuoteLineComponent: SKU=%, Role=%, catalog_item_id=%, cost_exw=%', 
                v_quote_line_component.sku, 
                v_quote_line_component.component_role,
                v_quote_line_component.catalog_item_id,
                v_quote_line_component.catalog_item_cost_exw;
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
            
            -- Get category_code from ComponentRoleMap
            BEGIN
                v_category_code := public.get_category_code_from_role(v_quote_line_component.component_role);
            EXCEPTION
                WHEN OTHERS THEN
                    -- Fallback: use role as category_code if function doesn't exist yet
                    v_category_code := v_quote_line_component.component_role;
            END;
            
            -- ✅ Calculate base costs from CatalogItem (use catalog_item_cost_exw from JOIN)
            v_unit_cost_exw := COALESCE(v_quote_line_component.catalog_item_cost_exw::numeric(12,4), 0);
            v_total_cost_exw := v_unit_cost_exw * COALESCE(v_quote_line_component.qty, 0);
            
            -- Log for debugging if cost is 0 (might indicate missing cost_exw)
            IF v_unit_cost_exw = 0 THEN
                RAISE NOTICE '   ⚠️  Warning: cost_exw is 0 for catalog_item_id: %, SKU: %', 
                    v_quote_line_component.catalog_item_id, v_quote_line_component.sku;
            END IF;
            
            -- ✅ Calculate shipping and import tax if percentages are set
            -- Get category-specific import tax if available
            BEGIN
                IF v_category_code IS NOT NULL THEN
                    SELECT import_tax_percentage
                    INTO v_category_import_tax_percentage
                    FROM "ImportTaxRules"
                    WHERE organization_id = v_manufacturing_order.organization_id
                    AND category_id IN (
                        SELECT id FROM "ItemCategories" 
                        WHERE code = v_category_code 
                        AND deleted = false
                        LIMIT 1
                    )
                    AND active = true
                    AND deleted = false
                    LIMIT 1;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_category_import_tax_percentage := 0;
            END;
            
            -- Use category-specific tax if available, otherwise use global default
            IF v_category_import_tax_percentage > 0 THEN
                v_import_tax_percentage := v_category_import_tax_percentage;
            END IF;
            
            -- Calculate total cost with shipping and import tax: cost_exw * (1 + shipping% + import_tax%)
            IF v_shipping_percentage > 0 OR v_import_tax_percentage > 0 THEN
                v_unit_cost_with_taxes := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                v_total_cost_with_taxes := v_unit_cost_with_taxes * COALESCE(v_quote_line_component.qty, 0);
            ELSE
                -- No shipping/import tax, use base cost
                v_unit_cost_with_taxes := v_unit_cost_exw;
                v_total_cost_with_taxes := v_total_cost_exw;
            END IF;
            
            -- ✅ Calculate MSRP Sale Out (PVP - Precio de Venta al Público)
            -- Formula: 
            -- 1. MSRP Sale In (precio mínimo) = Costo Total / (1 - min_margin_pct/100)
            -- 2. MSRP Sale Out (PVP) = MSRP Sale In / (1 - max_discount_pct/100)
            v_msrp_sale_in := v_unit_cost_with_taxes / (1 - (v_min_margin_pct / 100.0));
            v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
            v_total_msrp_sale_out := v_unit_msrp_sale_out * COALESCE(v_quote_line_component.qty, 0);
            
            BEGIN
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
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_manufacturing_order.organization_id,
                    v_bom_instance_id,
                    v_quote_line_component.catalog_item_id,
                    v_quote_line_component.sku,
                    v_quote_line_component.component_role,
                    v_quote_line_component.qty,
                    v_validated_uom,
                    COALESCE(v_quote_line_component.catalog_item_description, v_quote_line_component.item_name),
                    v_category_code,
                    v_unit_cost_with_taxes,  -- Store cost WITH shipping and import tax
                    v_total_cost_with_taxes, -- Store total cost WITH shipping and import tax
                    false,
                    now(),
                    now()
                );
                
                v_lines_count := v_lines_count + 1;
                RAISE NOTICE '   ✅ Created BomInstanceLine for QLC % (SKU: %, Role: %, Qty: % %, Cost: $%)', 
                    v_quote_line_component.id, v_quote_line_component.sku, 
                    v_quote_line_component.component_role, v_quote_line_component.qty, v_validated_uom, v_total_cost_exw;
                    
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
                    -- ✅ DEBUG: Log before calling resolve_auto_select_sku
                    RAISE NOTICE '   🔍 [generate_bom] Calling resolve_auto_select_sku: role=%, rule=%, color_ql=%, color_comp=%', 
                        v_bom_component.component_role, 
                        COALESCE(v_bom_component.sku_resolution_rule, 'ROLE_AND_COLOR'),
                        v_quote_line_hardware_color,
                        v_bom_component.hardware_color;
                    
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
                        -- ✅ DEBUG: Log exception details
                        RAISE NOTICE '   ❌ [generate_bom] Exception in resolve_auto_select_sku: %', SQLERRM;
                        RAISE EXCEPTION 'Failed to resolve auto-select component: bom_template_id=%, component_id=%, role=%, sku_resolution_rule=%, hardware_color (QuoteLine)=%, hardware_color (BOMComponent)=%. Error: %', 
                            v_bom_template_id_from_ql, v_bom_component.id, v_bom_component.component_role, 
                            v_bom_component.sku_resolution_rule, v_quote_line_hardware_color, v_bom_component.hardware_color, SQLERRM;
                END;
                
                -- Get catalog item details including cost
                SELECT ci.sku, ci.item_name, ci.description, ci.uom, ci.cost_exw
                INTO v_resolved_sku, v_resolved_item_name, v_resolved_description, v_catalog_item_uom, v_catalog_item_cost
                FROM "CatalogItems" ci
                WHERE ci.id = v_resolved_catalog_item_id
                AND ci.deleted = false
                LIMIT 1;
                
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Resolved catalog_item_id % not found in CatalogItems', v_resolved_catalog_item_id;
                END IF;
                
                -- Set unit cost from catalog item
                v_unit_cost_exw := COALESCE(v_catalog_item_cost::numeric(12,4), 0);
                
                -- Log warning if cost is 0
                IF v_unit_cost_exw = 0 THEN
                    RAISE NOTICE '   ⚠️  Warning: cost_exw is 0 for resolved catalog_item_id: %, SKU: %', 
                        v_resolved_catalog_item_id, v_resolved_sku;
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
                
                -- Get category_code from ComponentRoleMap
                BEGIN
                    v_category_code := public.get_category_code_from_role(v_bom_component.component_role);
                EXCEPTION
                    WHEN OTHERS THEN
                        -- Fallback: use role as category_code if function doesn't exist yet
                        v_category_code := v_bom_component.component_role;
                END;
                
                -- ✅ Calculate base cost
                v_total_cost_exw := v_unit_cost_exw * v_calculated_qty;
                
                -- ✅ Calculate shipping and import tax for auto-select component
                -- Get category-specific import tax if available
                BEGIN
                    IF v_category_code IS NOT NULL THEN
                        SELECT import_tax_percentage
                        INTO v_category_import_tax_percentage
                        FROM "ImportTaxRules"
                        WHERE organization_id = v_manufacturing_order.organization_id
                        AND category_id IN (
                            SELECT id FROM "ItemCategories" 
                            WHERE code = v_category_code 
                            AND deleted = false
                            LIMIT 1
                        )
                        AND active = true
                        AND deleted = false
                        LIMIT 1;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        v_category_import_tax_percentage := 0;
                END;
                
                -- Use category-specific tax if available, otherwise use global default
                IF v_category_import_tax_percentage > 0 THEN
                    v_import_tax_percentage := v_category_import_tax_percentage;
                END IF;
                
                -- Calculate total cost with shipping and import tax
                IF v_shipping_percentage > 0 OR v_import_tax_percentage > 0 THEN
                    v_unit_cost_with_taxes := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                    v_total_cost_with_taxes := v_unit_cost_with_taxes * v_calculated_qty;
                ELSE
                    -- No shipping/import tax, use base cost
                    v_unit_cost_with_taxes := v_unit_cost_exw;
                    v_total_cost_with_taxes := v_total_cost_exw;
                END IF;
                
                -- ✅ Calculate MSRP Sale Out (PVP - Precio de Venta al Público) for auto-select component
                -- Formula: 
                -- 1. MSRP Sale In (precio mínimo) = Costo Total / (1 - min_margin_pct/100)
                -- 2. MSRP Sale Out (PVP) = MSRP Sale In / (1 - max_discount_pct/100)
                v_msrp_sale_in := v_unit_cost_with_taxes / (1 - (v_min_margin_pct / 100.0));
                v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                v_total_msrp_sale_out := v_unit_msrp_sale_out * v_calculated_qty;
                
                -- Insert BomInstanceLine
                BEGIN
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
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_manufacturing_order.organization_id,
                        v_bom_instance_id,
                        v_resolved_catalog_item_id,
                        v_resolved_sku,
                        v_bom_component.component_role,
                        v_calculated_qty,
                        v_validated_uom,
                        COALESCE(v_resolved_description, v_resolved_item_name),
                        v_category_code,
                        v_unit_cost_with_taxes,  -- Store cost WITH shipping and import tax
                        v_total_cost_with_taxes, -- Store total cost WITH shipping and import tax
                        v_unit_msrp_sale_out,    -- Store MSRP Sale Out (PVP)
                        v_total_msrp_sale_out,   -- Store total MSRP Sale Out (PVP)
                        false,
                        now(),
                        now()
                    );
                    
                    v_lines_count := v_lines_count + 1;
                    RAISE NOTICE '   ✅ Created BomInstanceLine for auto-select component % (SKU: %, Role: %, Qty: % %, Cost: $%)', 
                        v_bom_component.id, v_resolved_sku, v_bom_component.component_role, v_calculated_qty, v_validated_uom, v_total_cost_with_taxes;
                        
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
    
    -- ✅ STEP 3: Calculate Labor and update BomInstances with totals
    -- Labor is calculated on the total cost of all lines in each BomInstance
    FOR v_sale_order_line IN
        SELECT sol.id, sol.quote_line_id, sol.line_number
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Get BomInstance for this SalesOrderLine
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line.id
        AND deleted = false
        LIMIT 1;
        
        IF FOUND THEN
            -- Calculate total cost of all lines in this BOM
            SELECT COALESCE(SUM(total_cost_exw), 0)
            INTO v_bom_total_cost
            FROM "BomInstanceLines"
            WHERE bom_instance_id = v_bom_instance_id
            AND deleted = false;
            
            -- Calculate labor cost: total_cost × labor_percentage
            IF v_labor_percentage > 0 AND v_bom_total_cost > 0 THEN
                v_bom_labor_cost := v_bom_total_cost * (v_labor_percentage / 100.0);
            ELSE
                v_bom_labor_cost := 0;
            END IF;
            
            -- Calculate total cost with labor
            v_bom_total_cost_with_labor := v_bom_total_cost + v_bom_labor_cost;
            
            -- Calculate MSRP Sale Out for the entire BOM (with labor included)
            -- Formula: MSRP Sale In = (Total Cost + Labor) / (1 - min_margin_pct/100)
            --          MSRP Sale Out = MSRP Sale In / (1 - max_discount_pct/100)
            IF v_bom_total_cost_with_labor > 0 THEN
                v_bom_msrp_sale_in := v_bom_total_cost_with_labor / (1 - (v_min_margin_pct / 100.0));
                v_bom_msrp_sale_out := v_bom_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
            ELSE
                v_bom_msrp_sale_in := 0;
                v_bom_msrp_sale_out := 0;
            END IF;
            
            -- Update BomInstance with labor and totals
            UPDATE "BomInstances"
            SET 
                labor_cost = v_bom_labor_cost,
                total_cost_with_labor = v_bom_total_cost_with_labor,
                total_msrp_sale_out_with_labor = v_bom_msrp_sale_out,
                updated_at = now()
            WHERE id = v_bom_instance_id;
            
            RAISE NOTICE '   💼 BOM Instance %: Total Cost=%, Labor=%, Total with Labor=%, MSRP Sale Out=%', 
                v_bom_instance_id, v_bom_total_cost, v_bom_labor_cost, v_bom_total_cost_with_labor, v_bom_msrp_sale_out;
        END IF;
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
    'Generates BOM instances and lines for a Manufacturing Order. Uses QuoteLine.hardware_color (user selection) with priority over BOMComponent.hardware_color (fallback) for auto-select SKU resolution. Calculates and stores costs from CatalogItems.';

-- ====================================================
-- GRANT PERMISSIONS
-- ====================================================
GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;

-- Migration completed

  