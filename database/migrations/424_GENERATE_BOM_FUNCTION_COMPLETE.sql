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
    v_item_category_code text; -- Raw code from ItemCategories (e.g., 'COMP-BOTTOM-RAIL')
    v_bom_template_id_from_ql uuid;
    v_catalog_item_uom text;
    v_catalog_item_cost numeric(12,4) := 0;
    -- ✅ FIX: Warnings array for return JSON
    v_warnings_array text[] := ARRAY[]::text[];
    -- ✅ FIX: Flag to detect if fabric exists in QuoteLineComponents
    v_has_fabric_in_qlc boolean := false;
    -- ✅ FIX: Selected fabric catalog_item_id from SO/QuoteLine (SO-driven)
    v_selected_fabric_catalog_item_id uuid;
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
    -- ✅ Cost calculation (using only existing columns)
    v_unit_cost_exw numeric(12,4) := 0;
    v_total_cost_exw numeric(12,4) := 0;
    -- MSRP Sale Out calculation
    v_unit_msrp_sale_out numeric(12,4) := 0;
    v_total_msrp_sale_out numeric(12,4) := 0;
    v_msrp_sale_in numeric(12,4) := 0;
    -- Temporary variable for cost with taxes (for MSRP calculation only, not stored)
    v_unit_cost_with_taxes_calc numeric(12,4) := 0;
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
    -- ✅ NEW: Error tracking
    v_errors text[] := ARRAY[]::text[];
    v_warnings text[] := ARRAY[]::text[];
    v_success boolean := true; -- ✅ FIX: Success status for return JSON
    -- ✅ NEW: Formula support
    v_formula_qty numeric;
    v_formula_params jsonb;
    -- ✅ NEW: Assembly support
    v_assembly_line RECORD; -- ✅ FIX: Must be RECORD for FOR ... IN SELECT
    v_child_resolved_catalog_item_id uuid;
    v_child_resolved_sku text;
    v_child_resolved_item_name text;
    v_child_resolved_description text;
    v_child_catalog_item_uom text;
    v_child_catalog_item_cost numeric(12,4) := 0;
    v_child_calculated_qty numeric;
    v_child_unit_cost_exw numeric(12,4) := 0;
    v_child_total_cost_exw numeric(12,4) := 0;
    v_child_unit_msrp_sale_out numeric(12,4) := 0;
    v_child_total_msrp_sale_out numeric(12,4) := 0;
    v_child_category_code text;
    v_parent_is_conceptual boolean := false; -- TRUE if parent SKU is placeholder/conceptual
    v_parent_line_id uuid; -- ID of parent BomInstanceLine (if parent was inserted)
    -- ✅ NEW: Cut dimensions in millimeters
    v_width_mm numeric(10,2) := 0;
    v_height_mm numeric(10,2) := 0;
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
    
    RAISE NOTICE '🚀 Starting BOM generation for ManufacturingOrder: % (Organization: %, SaleOrder: %)', 
        v_manufacturing_order.id, v_manufacturing_order.organization_id, v_manufacturing_order.sale_order_id;
    
    -- ✅ DEBUG: Count SaleOrderLines
    SELECT COUNT(*) INTO v_lines_count
    FROM "SalesOrderLines" sol
    JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    WHERE so.id = v_manufacturing_order.sale_order_id
    AND sol.deleted = false;
    
    RAISE NOTICE '   📋 Found % SaleOrderLines to process', v_lines_count;
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
    
    -- STEP 1: Delete existing BOMs for all SaleOrderLines in this SaleOrder
    -- ✅ FIX: Always regenerate BOM from scratch, don't reuse old data
    RAISE NOTICE '   🗑️  Deleting existing BomInstances and BomInstanceLines for SaleOrder: %', v_sale_order.id;
    
    DELETE FROM "BomInstanceLines" bil
    WHERE bil.bom_instance_id IN (
        SELECT bi.id
        FROM "BomInstances" bi
        JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order.id
        AND bi.deleted = false
    );
    
    DELETE FROM "BomInstances" bi
    WHERE bi.id IN (
        SELECT bi2.id
        FROM "BomInstances" bi2
        JOIN "SalesOrderLines" sol ON sol.id = bi2.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order.id
        AND bi2.deleted = false
    );
    
    RAISE NOTICE '   ✅ Deleted existing BOMs. Starting fresh generation.';
    
    -- STEP 2: Create BomInstances for each SaleOrderLine
    FOR v_sale_order_line IN
        SELECT sol.id, sol.quote_line_id, sol.line_number
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        RAISE NOTICE '   📦 Processing SalesOrderLine: % (line_number: %, quote_line_id: %)', 
            v_sale_order_line.id, v_sale_order_line.line_number, v_sale_order_line.quote_line_id;
        
        -- ✅ FIX: Always create new BomInstance (we deleted old ones above)
        v_bom_instance_id := NULL;
        
        -- ✅ FIX: Use helper function to resolve bom_template_id (comprehensive resolution)
        BEGIN
            v_bom_template_id_from_ql := public.resolve_bom_template_id_for_sale_order_line(v_sale_order_line.id);
            RAISE NOTICE '   ✅ Resolved bom_template_id=% for SalesOrderLine % using helper function', 
                v_bom_template_id_from_ql, v_sale_order_line.id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ⚠️  Could not resolve bom_template_id for SalesOrderLine %: %. Falling back to QuoteLine lookup', 
                    v_sale_order_line.id, SQLERRM;
                -- Fallback to QuoteLine lookup
                SELECT ql.bom_template_id
                INTO v_bom_template_id_from_ql
                FROM "QuoteLines" ql
                WHERE ql.id = v_sale_order_line.quote_line_id
                AND ql.deleted = false
                LIMIT 1;
        END;
        
        IF v_bom_template_id_from_ql IS NOT NULL THEN
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
                v_bom_total_cost := 0; -- ✅ FIX: Initialize for this BomInstance
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error creating BomInstance for SalesOrderLine %: %', v_sale_order_line.id, SQLERRM;
                    v_errors := v_errors || format('Failed to create BomInstance for SalesOrderLine %s: %s', v_sale_order_line.id, SQLERRM);
                    CONTINUE;
            END;
        ELSE
            RAISE NOTICE '   ⏭️  BomInstance % already exists for SalesOrderLine %', v_bom_instance_id, v_sale_order_line.id;
        END IF;
        
        -- ✅ UPDATED: Get QuoteLine fields including hardware_color, drive_type, bom_template_id, collection_id, variant_id
        SELECT 
            ql.width_m, 
            ql.height_m, 
            ql.cassette, 
            ql.side_channel,
            ql.hardware_color,
            ql.drive_type,
            ql.bom_template_id,
            ql.collection_id,
            ql.variant_id,
            ql.collection_name,
            ql.variant_name
        INTO v_quote_line
        FROM "QuoteLines" ql
        WHERE ql.id = v_sale_order_line.quote_line_id
        AND ql.deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            RAISE WARNING '   ⚠️  QuoteLine % not found for SalesOrderLine %', v_sale_order_line.quote_line_id, v_sale_order_line.id;
            v_warnings := v_warnings || format('QuoteLine %s not found', v_sale_order_line.quote_line_id);
            CONTINUE;
        END IF;
        
        v_width_m := COALESCE(v_quote_line.width_m, 0);
        v_height_m := COALESCE(v_quote_line.height_m, 0);
        v_quote_line_hardware_color := v_quote_line.hardware_color;
        v_bom_template_id_from_ql := COALESCE(v_quote_line.bom_template_id, v_bom_template_id_from_ql);
        
        -- ✅ DEBUG: Log QuoteLine data including collection/variant
        RAISE NOTICE '   📋 [STEP 2] QuoteLine data: bom_template_id=%, hardware_color=%, width_m=%, height_m=%, collection_id=%, variant_id=%, collection_name=%, variant_name=%', 
            v_quote_line.bom_template_id, v_quote_line.hardware_color, v_quote_line.width_m, v_quote_line.height_m,
            v_quote_line.collection_id, v_quote_line.variant_id, v_quote_line.collection_name, v_quote_line.variant_name;
        
        -- ✅ FIX: Resolve selected fabric using helper function (SO-driven)
        -- Priority: QuoteLineComponents > ConfiguredProduct > QuoteLine collection/variant match
        BEGIN
            v_selected_fabric_catalog_item_id := public.resolve_selected_fabric_catalog_item_id(v_sale_order_line.id);
            IF v_selected_fabric_catalog_item_id IS NOT NULL THEN
                v_has_fabric_in_qlc := true;
                RAISE NOTICE '   ✅ [STEP 2A] Selected fabric resolved: catalog_item_id=% (SO-driven)', v_selected_fabric_catalog_item_id;
            ELSE
                -- Fallback: Try to match by collection_name/variant_name from QuoteLine
                IF v_quote_line.collection_name IS NOT NULL OR v_quote_line.variant_name IS NOT NULL THEN
                    SELECT ci.id INTO v_selected_fabric_catalog_item_id
                    FROM "CatalogItems" ci
                    INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                    WHERE ci.organization_id = v_manufacturing_order.organization_id
                    AND ci.deleted = false
                    AND ci.active = true
                    AND ic.code = 'FABRIC'
                    AND (
                        (v_quote_line.variant_name IS NOT NULL AND ci.variant_name = v_quote_line.variant_name)
                        OR (v_quote_line.collection_name IS NOT NULL AND ci.collection_name = v_quote_line.collection_name)
                    )
                    ORDER BY 
                        CASE 
                            WHEN v_quote_line.variant_name IS NOT NULL AND ci.variant_name = v_quote_line.variant_name THEN 1
                            WHEN v_quote_line.collection_name IS NOT NULL AND ci.collection_name = v_quote_line.collection_name THEN 2
                            ELSE 3
                        END,
                        COALESCE(ci.selection_priority, 100) ASC,
                        ci.sku ASC
                    LIMIT 1;
                    
                    IF v_selected_fabric_catalog_item_id IS NOT NULL THEN
                        v_has_fabric_in_qlc := true;
                        RAISE NOTICE '   ✅ [STEP 2A] Fabric matched by collection/variant: catalog_item_id=% (collection=%, variant=%)', 
                            v_selected_fabric_catalog_item_id, v_quote_line.collection_name, v_quote_line.variant_name;
                    ELSE
                        v_has_fabric_in_qlc := false;
                        RAISE NOTICE '   ℹ️  [STEP 2A] No fabric match found for collection=% variant=% - will use template/auto-select', 
                            v_quote_line.collection_name, v_quote_line.variant_name;
                    END IF;
                ELSE
                    v_has_fabric_in_qlc := false;
                    RAISE NOTICE '   ℹ️  [STEP 2A] No selected fabric found - will use template/auto-select';
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ⚠️  Error resolving selected fabric: %. Falling back to QuoteLineComponents check', SQLERRM;
                -- Fallback to direct QuoteLineComponents check
                SELECT EXISTS (
                    SELECT 1
                    FROM "QuoteLineComponents" qlc
                    WHERE qlc.quote_line_id = v_sale_order_line.quote_line_id
                    AND qlc.component_role = 'fabric'
                    AND qlc.deleted = false
                    AND qlc.source = 'configured_component'
                ) INTO v_has_fabric_in_qlc;
        END;
        
        -- ✅ DEBUG: Count QuoteLineComponents
        SELECT COUNT(*) INTO v_lines_count
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_sale_order_line.quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        RAISE NOTICE '   📋 [STEP 2A] Found % QuoteLineComponents to process', v_lines_count;
        
        -- STEP 2A: Create BomInstanceLines from QuoteLineComponents (Fixed components from configurator)
        -- ✅ DEBUG: Log QuoteLineComponents count
        RAISE NOTICE '   📋 [STEP 2A] Processing QuoteLineComponents for QuoteLine %', v_sale_order_line.quote_line_id;
        
        FOR v_quote_line_component IN
            SELECT 
                qlc.id,
                qlc.catalog_item_id,
                qlc.component_role,
                qlc.qty,
                qlc.uom
            FROM "QuoteLineComponents" qlc
            WHERE qlc.quote_line_id = v_sale_order_line.quote_line_id
            AND qlc.deleted = false
            AND qlc.source = 'configured_component'
            ORDER BY qlc.component_role
        LOOP
            -- ✅ DEBUG: Log each QuoteLineComponent being processed
            RAISE NOTICE '   📋 [STEP 2A] Processing QLC: role=%, catalog_item_id=%', 
                v_quote_line_component.component_role, v_quote_line_component.catalog_item_id;
            -- Get catalog item details
            SELECT ci.sku, ci.item_name, ci.description, ci.uom, ci.cost_exw, ic.code
            INTO v_resolved_sku, v_resolved_item_name, v_resolved_description, v_catalog_item_uom, v_catalog_item_cost, v_item_category_code
            FROM "CatalogItems" ci
            LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE ci.id = v_quote_line_component.catalog_item_id
            AND ci.deleted = false
            LIMIT 1;
            
            IF NOT FOUND THEN
                RAISE WARNING '   ⚠️  CatalogItem % not found for QuoteLineComponent %', v_quote_line_component.catalog_item_id, v_quote_line_component.id;
                v_warnings := v_warnings || format('CatalogItem %s not found', v_quote_line_component.catalog_item_id);
                CONTINUE;
            END IF;
            
            -- ✅ FIX: Map component_role to valid category_code (must match constraint check_bom_instance_lines_category_code_valid)
            -- Valid values: 'fabric', 'tube', 'motor', 'bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory'
            v_category_code := CASE 
                WHEN v_quote_line_component.component_role = 'fabric' THEN 'fabric'
                WHEN v_quote_line_component.component_role = 'tube' THEN 'tube'
                WHEN v_quote_line_component.component_role = 'motor' THEN 'motor'
                WHEN v_quote_line_component.component_role = 'bracket' THEN 'bracket'
                WHEN v_quote_line_component.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_quote_line_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_quote_line_component.component_role LIKE '%bottom_rail%' 
                     OR v_quote_line_component.component_role LIKE '%bottom_channel%' 
                     OR v_quote_line_component.component_role LIKE '%bottom_bar%' THEN 'bottom_channel'
                ELSE 'accessory'  -- Default for motor_adapter, operating_system_drive, bracket_cover, chain, etc.
            END;
            
            -- ✅ DEBUG: Log cost value from CatalogItem
            RAISE NOTICE '   💰 [QLC] CatalogItem % (SKU: %) cost_exw: % (type: %), role: %, category_code: %', 
                v_quote_line_component.catalog_item_id, v_resolved_sku, v_catalog_item_cost, pg_typeof(v_catalog_item_cost),
                v_quote_line_component.component_role, v_category_code;
            
            -- Validate UOM
            v_validated_uom := public.get_catalog_item_uom(v_quote_line_component.catalog_item_id);
            
            -- ✅ FIX: Convert ft -> m in runtime (defensive conversion)
            IF v_validated_uom = 'ft' THEN
                RAISE NOTICE '   ⚠️  Converting UOM from ft to m for QLC % (SKU: %)', v_quote_line_component.id, v_resolved_sku;
                -- Convert qty: 1 ft = 0.3048 m
                v_quote_line_component.qty := v_quote_line_component.qty * 0.3048;
                v_validated_uom := 'm';
                v_warnings_array := v_warnings_array || format('converted_ft_to_m:qlc_%s', v_quote_line_component.id);
            END IF;
            
            -- Set unit cost from catalog item
            -- ✅ FIX: Ensure cost is never NULL - use 0 if missing, with explicit casting
            v_unit_cost_exw := COALESCE(CAST(v_catalog_item_cost AS numeric(12,4)), 0);
            v_total_cost_exw := v_unit_cost_exw * COALESCE(v_quote_line_component.qty, 0);
            
            -- ✅ DEBUG: Log calculated costs before MSRP calculation
            RAISE NOTICE '   💰 [QLC] Calculated costs: unit_cost_exw=%, total_cost_exw=%, qty=%', 
                v_unit_cost_exw, v_total_cost_exw, v_quote_line_component.qty;
            
            -- Calculate cost with taxes (for MSRP calculation only, not stored in DB)
            -- Only calculate if we have a base cost
            IF v_unit_cost_exw > 0 THEN
                v_unit_cost_with_taxes_calc := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                
                -- Calculate MSRP Sale Out
                v_msrp_sale_in := v_unit_cost_with_taxes_calc / (1 - (v_min_margin_pct / 100.0));
                v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                v_total_msrp_sale_out := v_unit_msrp_sale_out * COALESCE(v_quote_line_component.qty, 0);
                
                -- ✅ DEBUG: Log MSRP calculation
                RAISE NOTICE '   💰 [QLC] MSRP: unit=%, total=%, margin_pct=%, discount_pct=%', 
                    v_unit_msrp_sale_out, v_total_msrp_sale_out, v_min_margin_pct, v_max_discount_pct;
            ELSE
                -- If no cost, set MSRP to 0
                v_unit_cost_with_taxes_calc := 0;
                v_msrp_sale_in := 0;
                v_unit_msrp_sale_out := 0;
                v_total_msrp_sale_out := 0;
                RAISE WARNING '   ⚠️  CatalogItem % (SKU: %) has no cost_exw, setting costs to 0', v_quote_line_component.catalog_item_id, v_resolved_sku;
            END IF;
            
            -- ✅ FIX: Check if BomInstanceLine already exists (using full constraint: bom_instance_id, resolved_part_id, part_role, uom)
            IF EXISTS (
                SELECT 1
                FROM "BomInstanceLines" bil
                WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.resolved_part_id = v_quote_line_component.catalog_item_id
                AND COALESCE(bil.part_role, '') = COALESCE(v_quote_line_component.component_role, '')
                AND bil.uom = v_validated_uom
                AND bil.deleted = false
            ) THEN
                RAISE NOTICE '   ⏭️  Skipping QuoteLineComponent % (role: %, SKU: %) - BomInstanceLine already exists', 
                    v_quote_line_component.id, v_quote_line_component.component_role, v_resolved_sku;
                CONTINUE;
            END IF;
            
            -- Insert BomInstanceLine (using only existing columns)
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
                    v_quote_line_component.catalog_item_id,
                    v_resolved_sku,
                    v_quote_line_component.component_role,
                    -- ✅ FIX: Convert qty when UOM changes (ft->m, etc.)
                    public.convert_qty_by_uom(
                        v_quote_line_component.qty,
                        v_validated_uom,
                        public.normalize_uom_to_canonical(v_validated_uom, v_quote_line_component.component_role, NULL)
                    ),
                    -- ✅ FIX: Normalize UOM to canonical (ft->m, pcs->ea, set->ea)
                    public.normalize_uom_to_canonical(v_validated_uom, v_quote_line_component.component_role, NULL),
                    COALESCE(v_resolved_description, v_resolved_item_name),
                    v_category_code, -- Already validated to match constraint
                    COALESCE(v_unit_cost_exw, 0)::numeric(12,4),
                    COALESCE(v_total_cost_exw, 0)::numeric(12,4),
                    COALESCE(v_unit_msrp_sale_out, 0)::numeric(12,4),
                    COALESCE(v_total_msrp_sale_out, 0)::numeric(12,4),
                    false,
                    now(),
                    now()
                );
                
                v_created_lines := v_created_lines + 1;
                v_bom_total_cost := v_bom_total_cost + v_total_cost_exw;
                
                -- ✅ DEBUG: Log final values being inserted
                RAISE NOTICE '   ✅ Created BomInstanceLine for QLC % (SKU: %, Role: %, Qty: % %, Cost: $%, MSRP: $%)', 
                    v_quote_line_component.id, v_resolved_sku, 
                    v_quote_line_component.component_role, v_quote_line_component.qty, v_validated_uom, v_total_cost_exw, v_total_msrp_sale_out;
                RAISE NOTICE '   📝 [QLC] Insert values: unit_cost_exw=%, total_cost_exw=%, unit_msrp=%, total_msrp=%', 
                    COALESCE(v_unit_cost_exw, 0), COALESCE(v_total_cost_exw, 0), COALESCE(v_unit_msrp_sale_out, 0), COALESCE(v_total_msrp_sale_out, 0);
                
                -- ✅ NEW: Expand assemblies (CatalogItemBOMLines) for QuoteLineComponent
                FOR v_assembly_line IN
                    SELECT 
                        cibl.child_item_id,
                        cibl.qty as child_qty,
                        cibl.uom as child_uom,
                        ci.sku as child_sku,
                        ci.item_name as child_item_name,
                        ci.description as child_description,
                        ci.cost_exw as child_cost_exw,
                        ic.code as child_category_code
                    FROM "CatalogItemBOMLines" cibl
                    INNER JOIN "CatalogItems" ci ON ci.id = cibl.child_item_id
                    LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                    WHERE cibl.parent_item_id = v_quote_line_component.catalog_item_id
                    AND cibl.deleted = false
                    AND ci.deleted = false
                    ORDER BY cibl.created_at
                LOOP
                    -- Calculate child qty (multiply parent qty by child qty per parent)
                    v_child_calculated_qty := COALESCE(v_quote_line_component.qty, 0) * COALESCE(v_assembly_line.child_qty, 1);
                    
                    -- Calculate costs
                    v_child_unit_cost_exw := COALESCE(CAST(v_assembly_line.child_cost_exw AS numeric(12,4)), 0);
                    v_child_total_cost_exw := v_child_unit_cost_exw * v_child_calculated_qty;
                    
                    -- Calculate MSRP
                    IF v_child_unit_cost_exw > 0 THEN
                        v_unit_cost_with_taxes_calc := v_child_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                        v_msrp_sale_in := v_unit_cost_with_taxes_calc / (1 - (v_min_margin_pct / 100.0));
                        v_child_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                        v_child_total_msrp_sale_out := v_child_unit_msrp_sale_out * v_child_calculated_qty;
                    ELSE
                        v_child_unit_msrp_sale_out := 0;
                        v_child_total_msrp_sale_out := 0;
                    END IF;
                    
                    -- Map category_code
                    v_child_category_code := CASE 
                        WHEN v_assembly_line.child_category_code LIKE 'FABRIC%' THEN 'fabric'
                        WHEN v_assembly_line.child_category_code LIKE 'COMP-TUBE%' THEN 'tube'
                        WHEN v_assembly_line.child_category_code LIKE 'COMP-BRACKET%' THEN 'bracket'
                        WHEN v_assembly_line.child_category_code LIKE 'COMP-CASSETTE%' THEN 'cassette'
                        WHEN v_assembly_line.child_category_code LIKE 'COMP-SIDE%' THEN 'side_channel'
                        WHEN v_assembly_line.child_category_code LIKE 'COMP-BOTTOM%' THEN 'bottom_channel'
                        ELSE 'accessory'
                    END;
                    
                    -- Check for duplicates
                    IF EXISTS (
                        SELECT 1
                        FROM "BomInstanceLines" bil
                        WHERE bil.bom_instance_id = v_bom_instance_id
                        AND bil.resolved_part_id = v_assembly_line.child_item_id
                        AND COALESCE(bil.part_role, '') = COALESCE(v_quote_line_component.component_role, '')
                        AND bil.uom = v_assembly_line.child_uom
                        AND bil.deleted = false
                    ) THEN
                        RAISE NOTICE '   ⏭️  Skipping duplicate assembly child: child_item_id=%', v_assembly_line.child_item_id;
                        CONTINUE;
                    END IF;
                    
                        -- ✅ FIX: Insert child BomInstanceLine with source='assembly_child' and parent_part_id
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
                            source,
                            parent_part_id,
                            deleted,
                            created_at,
                            updated_at
                        ) VALUES (
                            v_manufacturing_order.organization_id,
                            v_bom_instance_id,
                            v_assembly_line.child_item_id,
                            v_assembly_line.child_sku,
                            v_quote_line_component.component_role, -- Inherit role from parent
                            COALESCE(v_child_calculated_qty, 0),
                            v_assembly_line.child_uom,
                            COALESCE(v_assembly_line.child_description, v_assembly_line.child_item_name),
                            v_child_category_code,
                            COALESCE(v_child_unit_cost_exw, 0)::numeric(12,4),
                            COALESCE(v_child_total_cost_exw, 0)::numeric(12,4),
                            COALESCE(v_child_unit_msrp_sale_out, 0)::numeric(12,4),
                            COALESCE(v_child_total_msrp_sale_out, 0)::numeric(12,4),
                            'assembly_child', -- ✅ FIX: Mark as assembly child
                            v_quote_line_component.catalog_item_id, -- ✅ FIX: Link to parent CatalogItem
                            false,
                            now(),
                            now()
                        );
                    
                    v_created_lines := v_created_lines + 1;
                    v_bom_total_cost := v_bom_total_cost + v_child_total_cost_exw;
                    
                    RAISE NOTICE '   ✅ [Assembly] Expanded child: SKU=%, qty=%, role=%', 
                        v_assembly_line.child_sku, v_child_calculated_qty, v_quote_line_component.component_role;
                END LOOP;
                    
            EXCEPTION
                WHEN OTHERS THEN
                    -- ✅ FIX: Fail hard instead of silently continuing
                    RAISE EXCEPTION 'BOM generation failed at component % (QLC: %), reason: %', 
                        v_quote_line_component.component_role, v_quote_line_component.id, SQLERRM;
            END;
        END LOOP;
        
        -- STEP 2B: Create BomInstanceLines from BOMComponents (Auto-select components from template)
        -- ✅ FIX: Also process fixed components from template that are NOT in QuoteLineComponents
        IF v_bom_template_id_from_ql IS NOT NULL THEN
            -- ✅ DEBUG: Count BOMComponents
            SELECT COUNT(*) INTO v_lines_count
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_id_from_ql
            AND bc.deleted = false
            AND bc.component_role IS NOT NULL;
            
            RAISE NOTICE '   📋 [STEP 2B] Found % BOMComponents in template %', v_lines_count, v_bom_template_id_from_ql;
            
            -- ✅ DEBUG: Log BOMComponents count
            RAISE NOTICE '   📋 [STEP 2B] Processing BOMComponents for Template %', v_bom_template_id_from_ql;
            
            FOR v_bom_component IN
                SELECT 
                    bc.id,
                    bc.component_role,
                    bc.auto_select,
                    bc.component_item_id,
                    bc.qty_type,
                    bc.qty_value,
                    bc.qty_per_unit,
                    bc.qty_formula_code,
                    bc.qty_formula_params,
                    bc.hardware_color,
                    bc.sku_resolution_rule,
                    bc.block_condition,
                    bc.applies_color,
                    bc.uom
                FROM "BOMComponents" bc
                WHERE bc.bom_template_id = v_bom_template_id_from_ql
                AND bc.deleted = false
                AND bc.component_role IS NOT NULL
                -- ✅ FIX: Skip fabric if it exists in QuoteLineComponents (avoid duplicate)
                AND NOT (
                    bc.component_role = 'fabric' 
                    AND v_has_fabric_in_qlc = true
                )
                -- ✅ FIX: Process ALL components (auto-select AND fixed), but skip fixed ones that are already in QuoteLineComponents
                AND (
                    -- Auto-select components (always process, except fabric if in QLC)
                    (bc.auto_select = true OR bc.component_item_id IS NULL)
                    OR
                    -- Fixed components that are NOT in QuoteLineComponents (process to include template defaults)
                    (bc.component_item_id IS NOT NULL AND NOT EXISTS (
                        SELECT 1 FROM "QuoteLineComponents" qlc
                        WHERE qlc.quote_line_id = v_sale_order_line.quote_line_id
                        AND qlc.component_role = bc.component_role
                        AND qlc.deleted = false
                        AND qlc.source = 'configured_component'
                    ))
                )
            LOOP
                -- ✅ FIX: Double-check fabric skip (defensive)
                IF v_bom_component.component_role = 'fabric' AND v_has_fabric_in_qlc THEN
                    RAISE NOTICE '   ⏭️  Skipping template fabric (component_id: %) - fabric exists in QuoteLineComponents', v_bom_component.id;
                    CONTINUE;
                END IF;
                
                -- ✅ FIX: Validate auto-select components have required fields (ENUM safety)
                IF (v_bom_component.auto_select = true OR v_bom_component.component_item_id IS NULL) THEN
                    -- Validate sku_resolution_rule
                    IF v_bom_component.sku_resolution_rule IS NULL OR TRIM(v_bom_component.sku_resolution_rule) = '' THEN
                        v_errors := v_errors || format('Auto-select BOMComponent %s role=%s missing sku_resolution_rule', 
                            v_bom_component.id, v_bom_component.component_role);
                        RAISE EXCEPTION 'Auto-select BOMComponent % role=% missing sku_resolution_rule', 
                            v_bom_component.id, v_bom_component.component_role;
                    END IF;
                    
                    -- Validate qty_type (must be valid enum value)
                    IF v_bom_component.qty_type IS NULL THEN
                        v_errors := v_errors || format('Auto-select BOMComponent %s role=%s missing qty_type', 
                            v_bom_component.id, v_bom_component.component_role);
                        RAISE EXCEPTION 'Auto-select BOMComponent % role=% missing qty_type', 
                            v_bom_component.id, v_bom_component.component_role;
                    END IF;
                    
                    -- Validate qty_type is a valid enum value (check against enum_range)
                    IF NOT EXISTS (
                        SELECT 1 
                        FROM unnest(enum_range(NULL::bom_qty_type)) AS v(enum_val)
                        WHERE v.enum_val::text = v_bom_component.qty_type::text
                    ) THEN
                        v_errors := v_errors || format('Auto-select BOMComponent %s role=%s has invalid qty_type: %s', 
                            v_bom_component.id, v_bom_component.component_role, v_bom_component.qty_type::text);
                        RAISE EXCEPTION 'Auto-select BOMComponent % role=% has invalid qty_type: %. Valid values from enum: fixed, per_width, per_area', 
                            v_bom_component.id, v_bom_component.component_role, v_bom_component.qty_type::text;
                    END IF;
                    
                    -- Validate uom is NOT NULL
                    IF v_bom_component.uom IS NULL OR TRIM(v_bom_component.uom) = '' THEN
                        v_errors := v_errors || format('Auto-select BOMComponent %s role=%s missing uom', 
                            v_bom_component.id, v_bom_component.component_role);
                        RAISE EXCEPTION 'Auto-select BOMComponent % role=% missing uom', 
                            v_bom_component.id, v_bom_component.component_role;
                    END IF;
                    
                    -- ✅ DEBUG: Log validated component
                    RAISE NOTICE 'AUTO_SELECT OK: component_id=%, role=%, rule=%, qty_type=%, formula_code=%, uom=%', 
                        v_bom_component.id, v_bom_component.component_role, v_bom_component.sku_resolution_rule, 
                        v_bom_component.qty_type, v_bom_component.qty_formula_code, v_bom_component.uom;
                END IF;
                
                -- ✅ DEBUG: Log each BOMComponent being processed
                RAISE NOTICE '   📋 [STEP 2B] Processing BOMComponent: id=%, role=%, auto_select=%, component_item_id=%, uom=%, qty_type=%, qty_value=%', 
                    v_bom_component.id, v_bom_component.component_role, v_bom_component.auto_select, 
                    v_bom_component.component_item_id, v_bom_component.uom, v_bom_component.qty_type, v_bom_component.qty_value;
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
                
                -- ✅ FIX: Skip fabric from template if it already exists in QuoteLineComponents (SO-driven)
                IF v_bom_component.component_role = 'fabric' AND v_has_fabric_in_qlc THEN
                    RAISE NOTICE '   ⏭️  Skipping template fabric component % - fabric already exists in QuoteLineComponents (SO-driven)', 
                        v_bom_component.id;
                    CONTINUE;
                END IF;
                
                -- ✅ FIX: Handle fixed components (component_item_id IS NOT NULL) differently from auto-select
                IF v_bom_component.component_item_id IS NOT NULL AND (v_bom_component.auto_select = false OR v_bom_component.auto_select IS NULL) THEN
                    -- Fixed component: use component_item_id directly
                    v_resolved_catalog_item_id := v_bom_component.component_item_id;
                    
                    -- Get catalog item details including cost
                    SELECT ci.sku, ci.item_name, ci.description, ci.uom, ci.cost_exw, ic.code
                    INTO v_resolved_sku, v_resolved_item_name, v_resolved_description, v_catalog_item_uom, v_catalog_item_cost, v_item_category_code
                    FROM "CatalogItems" ci
                    LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                    WHERE ci.id = v_resolved_catalog_item_id
                    AND ci.deleted = false
                    LIMIT 1;
                    
                    IF NOT FOUND THEN
                        RAISE WARNING '   ⚠️  Fixed component catalog_item_id % not found in CatalogItems', v_resolved_catalog_item_id;
                        v_warnings := v_warnings || format('Fixed component catalog_item_id %s not found', v_resolved_catalog_item_id);
                        CONTINUE;
                    END IF;
                    
                    -- ✅ FIX: Calculate qty based on role and qty_type (coherent calculation)
                    -- Rules:
                    -- - tube / bottom_bar / bottom_rail_profile / chain: qty = width_m (linear)
                    -- - fabric: qty = width_m * height_m (m2)
                    -- - bracket/end_cap/hardware: qty = fixed (qty_value or qty_per_unit) or 2 by default
                    IF v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'chain') THEN
                        -- Linear components: use width_m
                        v_calculated_qty := COALESCE(v_width_m, 0);
                        IF v_calculated_qty = 0 THEN
                            RAISE WARNING '   ⚠️  width_m is 0 for linear component % (role: %)', v_bom_component.id, v_bom_component.component_role;
                        END IF;
                    ELSIF v_bom_component.component_role = 'fabric' THEN
                        -- Fabric: use area (width_m * height_m)
                        v_calculated_qty := COALESCE(v_width_m, 0) * COALESCE(v_height_m, 0);
                        IF v_calculated_qty = 0 THEN
                            RAISE WARNING '   ⚠️  width_m or height_m is 0 for fabric component %', v_bom_component.id;
                        END IF;
                    ELSIF v_bom_component.qty_type = 'per_width' THEN
                        -- Use qty_type if specified
                        v_calculated_qty := COALESCE(v_width_m, 0) * COALESCE(v_bom_component.qty_value, COALESCE(v_bom_component.qty_per_unit, 1));
                    ELSIF v_bom_component.qty_type = 'per_area' THEN
                        v_calculated_qty := COALESCE(v_width_m, 0) * COALESCE(v_height_m, 0) * COALESCE(v_bom_component.qty_value, COALESCE(v_bom_component.qty_per_unit, 1));
                    ELSIF v_bom_component.qty_type = 'fixed' THEN
                        v_calculated_qty := COALESCE(v_bom_component.qty_value, COALESCE(v_bom_component.qty_per_unit, 1));
                    ELSE
                        -- Default: fixed qty (for bracket, end_cap, hardware, etc.)
                        v_calculated_qty := COALESCE(v_bom_component.qty_value, COALESCE(v_bom_component.qty_per_unit, 1));
                        IF v_calculated_qty = 0 THEN
                            -- Default to 2 for brackets/end_caps if not specified
                            IF v_bom_component.component_role IN ('bracket', 'end_cap', 'hardware') THEN
                                v_calculated_qty := 2;
                            ELSE
                                v_calculated_qty := 1;
                            END IF;
                        END IF;
                    END IF;
                    
                    -- ✅ FIX: Convert ft -> m in runtime (defensive conversion)
                    IF v_catalog_item_uom = 'ft' THEN
                        RAISE NOTICE '   ⚠️  Converting UOM from ft to m for fixed component % (SKU: %)', v_bom_component.id, v_resolved_sku;
                        -- Convert qty: 1 ft = 0.3048 m
                        v_calculated_qty := v_calculated_qty * 0.3048;
                        v_catalog_item_uom := 'm';
                        v_warnings_array := v_warnings_array || format('converted_ft_to_m:fixed_%s', v_bom_component.id);
                    END IF;
                    
                    -- Normalize qty by UOM
                    v_calculated_qty := public.normalize_qty_by_uom(v_calculated_qty, v_catalog_item_uom);
                    
                    -- ✅ FIX: Map component_role to valid category_code for fixed components too
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
                    
                    -- ✅ DEBUG: Log fixed component
                    RAISE NOTICE '   ✅ [Fixed Component] Using component_item_id directly: SKU=%, qty=%, role=%, category_code=%', 
                        v_resolved_sku, v_calculated_qty, v_bom_component.component_role, v_category_code;
                    
                    -- ✅ FIX: Check if BomInstanceLine already exists (using full constraint: bom_instance_id, resolved_part_id, part_role, uom)
                    IF EXISTS (
                        SELECT 1
                        FROM "BomInstanceLines" bil
                        WHERE bil.bom_instance_id = v_bom_instance_id
                        AND bil.resolved_part_id = v_resolved_catalog_item_id
                        AND COALESCE(bil.part_role, '') = COALESCE(v_bom_component.component_role, '')
                        AND bil.uom = v_catalog_item_uom
                        AND bil.deleted = false
                    ) THEN
                        RAISE NOTICE '   ⏭️  Skipping fixed BOMComponent % (role: %, SKU: %) - BomInstanceLine already exists', 
                            v_bom_component.id, v_bom_component.component_role, v_resolved_sku;
                        CONTINUE;
                    END IF;
                    
                    -- Set unit cost from catalog item
                    v_unit_cost_exw := COALESCE(CAST(v_catalog_item_cost AS numeric(12,4)), 0);
                    v_total_cost_exw := v_unit_cost_exw * v_calculated_qty;
                    
                    -- Calculate cost with taxes (for MSRP calculation only, not stored in DB)
                    IF v_unit_cost_exw > 0 THEN
                        v_unit_cost_with_taxes_calc := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                        v_msrp_sale_in := v_unit_cost_with_taxes_calc / (1 - (v_min_margin_pct / 100.0));
                        v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                        v_total_msrp_sale_out := v_unit_msrp_sale_out * v_calculated_qty;
                    ELSE
                        v_unit_cost_with_taxes_calc := 0;
                        v_msrp_sale_in := 0;
                        v_unit_msrp_sale_out := 0;
                        v_total_msrp_sale_out := 0;
                    END IF;
                ELSE
                    -- Auto-select component: resolve SKU using rules
                    -- ✅ CRITICAL FIX: Use QuoteLine.hardware_color (user selection) with priority over BOMComponent.hardware_color (fallback)
                    -- Resolve catalog_item_id
                    BEGIN
                        DECLARE
                            v_effective_sku_resolution_rule text;
                        BEGIN
                        -- ✅ FIX: Map legacy/unsupported sku_resolution_rule values to supported ones
                        -- Map unsupported values to supported ones
                        v_effective_sku_resolution_rule := CASE 
                            WHEN v_bom_component.sku_resolution_rule = 'ROLE_FIRST_MATCH' THEN 'ROLE_AND_COLOR'  -- Legacy: map to ROLE_AND_COLOR
                            WHEN v_bom_component.sku_resolution_rule IN ('EXACT_SKU', 'CATEGORY_FIRST_MATCH', 'SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR') THEN v_bom_component.sku_resolution_rule
                            ELSE COALESCE(v_bom_component.sku_resolution_rule, 'ROLE_AND_COLOR')  -- Default fallback
                        END;
                        
                        -- ✅ DEBUG: Log before calling resolve_auto_select_sku (including collection/variant for fabric)
                        RAISE NOTICE '   🔍 [Auto-Select] Calling resolve_auto_select_sku: role=%, rule=% (mapped from %), color_ql=%, color_comp=%, collection_id=%, variant_id=%', 
                            v_bom_component.component_role, 
                            v_effective_sku_resolution_rule,
                            v_bom_component.sku_resolution_rule,
                            v_quote_line_hardware_color,
                            v_bom_component.hardware_color,
                            v_quote_line.collection_id,
                            v_quote_line.variant_id;
                        
                        -- ✅ FIX: For fabric components, use selected fabric (SO-driven) if available
                        IF v_bom_component.component_role = 'fabric' AND v_selected_fabric_catalog_item_id IS NOT NULL THEN
                            -- Use the selected fabric from SO/QuoteLine (highest priority)
                            v_resolved_catalog_item_id := v_selected_fabric_catalog_item_id;
                            RAISE NOTICE '   ✅ [Fabric SO-driven] Using selected fabric catalog_item_id=% (from SO/QuoteLine)', 
                                v_resolved_catalog_item_id;
                        ELSIF v_bom_component.component_role = 'fabric' AND (
                            v_quote_line.collection_name IS NOT NULL 
                            OR v_quote_line.variant_name IS NOT NULL
                            OR v_quote_line.collection_id IS NOT NULL 
                            OR v_quote_line.variant_id IS NOT NULL
                        ) THEN
                            -- Try to resolve fabric using collection_name/variant_name (preferred) or collection_id/variant_id
                            BEGIN
                                -- Try to resolve fabric using collection_name/variant_name (these fields definitely exist)
                                SELECT ci.id INTO v_resolved_catalog_item_id
                                FROM "CatalogItems" ci
                                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                                WHERE ci.organization_id = v_manufacturing_order.organization_id
                                AND ci.deleted = false
                                AND ci.active = true
                                AND ic.code = 'FABRIC'
                                AND (
                                    -- Prefer variant_name match (most specific)
                                    (v_quote_line.variant_name IS NOT NULL AND ci.variant_name IS NOT NULL AND ci.variant_name = v_quote_line.variant_name)
                                    -- Then collection_name match
                                    OR (v_quote_line.collection_name IS NOT NULL AND ci.collection_name IS NOT NULL AND ci.collection_name = v_quote_line.collection_name)
                                )
                                ORDER BY 
                                    -- Prefer most specific match first
                                    CASE 
                                        WHEN v_quote_line.variant_name IS NOT NULL AND ci.variant_name = v_quote_line.variant_name THEN 1
                                        WHEN v_quote_line.collection_name IS NOT NULL AND ci.collection_name = v_quote_line.collection_name THEN 2
                                        ELSE 3
                                    END,
                                    COALESCE(ci.selection_priority, 100) ASC,
                                    ci.sku ASC
                                LIMIT 1;
                                
                                IF v_resolved_catalog_item_id IS NULL THEN
                                    RAISE WARNING '   ⚠️  Could not resolve fabric using collection_name=% or variant_name=%, falling back to standard resolution', 
                                        v_quote_line.collection_name, v_quote_line.variant_name;
                                    -- Fallback to standard resolution (use mapped rule)
                                    v_resolved_catalog_item_id := public.resolve_auto_select_sku(
                                        p_component_role := v_bom_component.component_role,
                                        p_sku_resolution_rule := v_effective_sku_resolution_rule,
                                        p_hardware_color := NULL, -- Fabric doesn't use hardware_color
                                        p_organization_id := v_manufacturing_order.organization_id,
                                        p_bom_template_id := v_bom_template_id_from_ql
                                    );
                                    RAISE WARNING '   ⚠️  Fabric resolved using fallback (%) -> catalog_item_id=%. This may not match the collection!', 
                                        v_effective_sku_resolution_rule, v_resolved_catalog_item_id;
                                ELSE
                                    -- Get the resolved SKU for logging (will be fetched later in the main flow)
                                    RAISE NOTICE '   ✅ Resolved fabric using collection_name=% or variant_name=% -> catalog_item_id=%', 
                                        v_quote_line.collection_name, v_quote_line.variant_name, v_resolved_catalog_item_id;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    RAISE WARNING '   ⚠️  Error resolving fabric with collection_name/variant_name: %, falling back to standard resolution', SQLERRM;
                                    -- Fallback to standard resolution (use mapped rule)
                                    v_resolved_catalog_item_id := public.resolve_auto_select_sku(
                                        p_component_role := v_bom_component.component_role,
                                        p_sku_resolution_rule := v_effective_sku_resolution_rule,
                                        p_hardware_color := NULL,
                                        p_organization_id := v_manufacturing_order.organization_id,
                                        p_bom_template_id := v_bom_template_id_from_ql
                                    );
                            END;
                        ELSE
                            -- Standard resolution for non-fabric components (use mapped rule)
                            v_resolved_catalog_item_id := public.resolve_auto_select_sku(
                                p_component_role := v_bom_component.component_role,
                                p_sku_resolution_rule := v_effective_sku_resolution_rule,
                                p_hardware_color := COALESCE(v_quote_line_hardware_color, v_bom_component.hardware_color),
                                p_organization_id := v_manufacturing_order.organization_id,
                                p_bom_template_id := v_bom_template_id_from_ql
                            );
                        END IF;
                        END; -- End inner DECLARE block for v_effective_sku_resolution_rule
                        
                        RAISE NOTICE '   ✅ Resolved auto-select component % (role: %) -> catalog_item_id: % (hardware_color: %)', 
                                v_bom_component.id, v_bom_component.component_role, v_resolved_catalog_item_id,
                                COALESCE(v_quote_line_hardware_color, v_bom_component.hardware_color, 'none');
                                
                    EXCEPTION
                        WHEN OTHERS THEN
                            -- ✅ DEBUG: Log exception details
                            RAISE NOTICE '   ❌ [Auto-Select] Exception in resolve_auto_select_sku: %', SQLERRM;
                            v_errors := v_errors || format('Failed to resolve auto-select component %s (role: %s, rule: %s): %s', 
                                v_bom_component.id, v_bom_component.component_role, v_bom_component.sku_resolution_rule, SQLERRM);
                            CONTINUE; -- Continue with next component instead of failing entire BOM
                    END; -- End outer BEGIN block for auto-select
                    
                    -- Get catalog item details including cost
                    SELECT ci.sku, ci.item_name, ci.description, ci.uom, ci.cost_exw, ic.code
                    INTO v_resolved_sku, v_resolved_item_name, v_resolved_description, v_catalog_item_uom, v_catalog_item_cost, v_item_category_code
                    FROM "CatalogItems" ci
                    LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                    WHERE ci.id = v_resolved_catalog_item_id
                    AND ci.deleted = false
                    LIMIT 1;
                    
                    IF NOT FOUND THEN
                        RAISE WARNING '   ⚠️  Resolved catalog_item_id % not found in CatalogItems', v_resolved_catalog_item_id;
                        v_warnings := v_warnings || format('Resolved catalog_item_id %s not found', v_resolved_catalog_item_id);
                        CONTINUE;
                    END IF;
                    
                    -- ✅ DEBUG: For fabric, log collection comparison (separate query to get collection info)
                    IF v_bom_component.component_role = 'fabric' THEN
                        PERFORM (
                            SELECT ci.collection_name, ci.variant_name
                            FROM "CatalogItems" ci
                            WHERE ci.id = v_resolved_catalog_item_id
                            LIMIT 1
                        );
                        -- Use a subquery in the RAISE NOTICE to get collection info
                        RAISE NOTICE '   🧵 [Fabric Collection Check] QuoteLine: collection_name=%, variant_name=% | CatalogItem: SKU=%', 
                            v_quote_line.collection_name, v_quote_line.variant_name, v_resolved_sku;
                    END IF;
                    
                    -- ✅ NEW: Calculate qty using formula OR qty_type
                    IF v_bom_component.qty_formula_code IS NOT NULL THEN
                        -- ✅ FIX: Validate formula params
                        IF v_bom_component.qty_formula_code = 'CHAIN_HEIGHT_FACTOR' THEN
                            v_formula_params := v_bom_component.qty_formula_params;
                            
                            -- ✅ HARD VALIDATION: Ensure params exist and are numeric
                            IF v_formula_params IS NULL THEN
                                RAISE EXCEPTION 'qty_formula_code=CHAIN_HEIGHT_FACTOR requires qty_formula_params (component_id: %)', v_bom_component.id;
                            END IF;
                            
                            IF (v_formula_params->>'height_factor') IS NULL OR (v_formula_params->>'mult') IS NULL THEN
                                RAISE EXCEPTION 'qty_formula_params must contain height_factor and mult (component_id: %)', v_bom_component.id;
                            END IF;
                            
                            -- Validate numeric
                            BEGIN
                                IF (v_formula_params->>'height_factor')::numeric IS NULL OR (v_formula_params->>'mult')::numeric IS NULL THEN
                                    RAISE EXCEPTION 'height_factor and mult must be numeric (component_id: %)', v_bom_component.id;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    RAISE EXCEPTION 'Invalid numeric values in qty_formula_params (component_id: %): %', v_bom_component.id, SQLERRM;
                            END;
                            
                            -- Formula: qty_m = height_m * height_factor * mult
                            v_calculated_qty := COALESCE(v_height_m, 0) 
                                * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75)
                                * COALESCE((v_formula_params->>'mult')::numeric, 2);
                            -- ✅ FIX: Use BOMComponent.uom (should be 'm' for chain), fallback to 'm' if NULL
                            -- Don't override v_catalog_item_uom here - use v_bom_component.uom in INSERT
                            RAISE NOTICE '   📐 [Formula] CHAIN_HEIGHT_FACTOR: role=%, height_m=%, params=%, qty_m=%, uom_from_template=%', 
                                v_bom_component.component_role, v_height_m, v_formula_params, v_calculated_qty, v_bom_component.uom;
                        ELSE
                            v_errors := v_errors || format('Unknown formula code: %s for component %s', 
                                v_bom_component.qty_formula_code, v_bom_component.id);
                            RAISE EXCEPTION 'Unknown formula code: % for component %', 
                                v_bom_component.qty_formula_code, v_bom_component.id;
                        END IF;
                    ELSE
                        -- Use qty_type logic (existing)
                        -- - tube / bottom_bar / bottom_rail_profile / chain: qty = width_m (linear)
                        -- - fabric: qty = width_m * height_m (m2)
                        -- - bracket/end_cap/hardware: qty = fixed (qty_value) or 2 by default
                        IF v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'chain') THEN
                            -- Linear components: use width_m (store in meters)
                            v_calculated_qty := COALESCE(v_width_m, 0);
                            -- ✅ FIX: Use BOMComponent.uom (should be 'm'), don't override v_catalog_item_uom
                            IF v_calculated_qty = 0 THEN
                                RAISE WARNING '   ⚠️  width_m is 0 for linear component % (role: %)', v_bom_component.id, v_bom_component.component_role;
                            END IF;
                        ELSIF v_bom_component.component_role = 'fabric' THEN
                            -- Fabric: use area (width_m * height_m)
                            v_calculated_qty := COALESCE(v_width_m, 0) * COALESCE(v_height_m, 0);
                            -- ✅ FIX: Use BOMComponent.uom (should be 'm2'), don't override v_catalog_item_uom
                            IF v_calculated_qty = 0 THEN
                                RAISE WARNING '   ⚠️  width_m or height_m is 0 for fabric component %', v_bom_component.id;
                            END IF;
                        ELSIF v_bom_component.qty_type = 'per_width' THEN
                            -- Use qty_type if specified
                            v_calculated_qty := COALESCE(v_width_m, 0) * COALESCE(v_bom_component.qty_value, 1);
                            -- ✅ FIX: Use BOMComponent.uom (should be 'm'), don't override v_catalog_item_uom
                        ELSIF v_bom_component.qty_type = 'per_area' THEN
                            v_calculated_qty := COALESCE(v_width_m, 0) * COALESCE(v_height_m, 0) * COALESCE(v_bom_component.qty_value, 1);
                            -- ✅ FIX: Use BOMComponent.uom (should be 'm2'), don't override v_catalog_item_uom
                        ELSIF v_bom_component.qty_type = 'fixed' THEN
                            v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
                            -- Keep original uom for fixed
                        ELSE
                            -- Default: fixed qty (for bracket, end_cap, hardware, etc.)
                            v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
                            IF v_calculated_qty = 0 THEN
                                -- Default to 2 for brackets/end_caps if not specified
                                IF v_bom_component.component_role IN ('bracket', 'end_cap', 'hardware') THEN
                                    v_calculated_qty := 2;
                                ELSE
                                    v_calculated_qty := 1;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                    
                    -- ✅ FIX: Convert ft -> m in runtime (defensive conversion)
                    -- Check both BOMComponent.uom and catalog_item_uom for 'ft'
                    IF COALESCE(v_bom_component.uom, v_catalog_item_uom) = 'ft' THEN
                        RAISE NOTICE '   ⚠️  Converting UOM from ft to m for auto-select component % (SKU: %)', v_bom_component.id, v_resolved_sku;
                        -- Convert qty: 1 ft = 0.3048 m
                        v_calculated_qty := v_calculated_qty * 0.3048;
                        -- If BOMComponent.uom is 'ft', we should update it, but we can't modify the template
                        -- So we'll use 'm' as fallback in INSERT
                        v_warnings_array := v_warnings_array || format('converted_ft_to_m:auto_%s', v_bom_component.id);
                    END IF;
                    
                    -- Normalize qty by UOM (use BOMComponent.uom if available, otherwise catalog_item_uom)
                    v_calculated_qty := public.normalize_qty_by_uom(v_calculated_qty, COALESCE(v_bom_component.uom, v_catalog_item_uom));
                    
                    -- ✅ FIX: Check if BomInstanceLine already exists (using full constraint: bom_instance_id, resolved_part_id, part_role, uom)
                    -- Use the same UOM logic as INSERT: COALESCE(v_bom_component.uom, v_catalog_item_uom)
                    IF EXISTS (
                        SELECT 1
                        FROM "BomInstanceLines" bil
                        WHERE bil.bom_instance_id = v_bom_instance_id
                        AND bil.resolved_part_id = v_resolved_catalog_item_id
                        AND COALESCE(bil.part_role, '') = COALESCE(v_bom_component.component_role, '')
                        AND bil.uom = COALESCE(v_bom_component.uom, v_catalog_item_uom)
                        AND bil.deleted = false
                    ) THEN
                        RAISE NOTICE '   ⏭️  Skipping auto-select BOMComponent % (role: %, SKU: %) - BomInstanceLine already exists', 
                            v_bom_component.id, v_bom_component.component_role, v_resolved_sku;
                        CONTINUE;
                    END IF;
                END IF; -- End IF for fixed vs auto-select
                
                -- ✅ FIX: Map component_role to valid category_code (must match constraint check_bom_instance_lines_category_code_valid)
                -- Valid values: 'fabric', 'tube', 'motor', 'bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory'
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
                    ELSE 'accessory'  -- Default for motor_adapter, operating_system_drive, bracket_cover, chain, etc.
                END;
                
                -- ✅ NEW: Calculate cut dimensions in millimeters (for linear components)
                v_width_mm := COALESCE(v_width_m, 0) * 1000.0;
                v_height_mm := COALESCE(v_height_m, 0) * 1000.0;
                
                -- ✅ DEBUG: Log cost value from CatalogItem
                RAISE NOTICE '   💰 [BOMComponent] CatalogItem % (SKU: %) cost_exw: % (type: %), role: %, category_code: %', 
                    v_resolved_catalog_item_id, v_resolved_sku, v_catalog_item_cost, pg_typeof(v_catalog_item_cost),
                    v_bom_component.component_role, v_category_code;
                
                -- Set unit cost from catalog item
                -- ✅ FIX: Ensure cost is never NULL - use 0 if missing, with explicit casting
                v_unit_cost_exw := COALESCE(CAST(v_catalog_item_cost AS numeric(12,4)), 0);
                v_total_cost_exw := v_unit_cost_exw * v_calculated_qty;
                
                -- ✅ DEBUG: Log calculated costs before MSRP calculation
                RAISE NOTICE '   💰 [Auto-Select] Calculated costs: unit_cost_exw=%, total_cost_exw=%, qty=%', 
                    v_unit_cost_exw, v_total_cost_exw, v_calculated_qty;
                
                -- Calculate cost with taxes (for MSRP calculation only, not stored in DB)
                -- Only calculate if we have a base cost
                IF v_unit_cost_exw > 0 THEN
                    v_unit_cost_with_taxes_calc := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                    
                    -- Calculate MSRP Sale Out
                    v_msrp_sale_in := v_unit_cost_with_taxes_calc / (1 - (v_min_margin_pct / 100.0));
                    v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                    v_total_msrp_sale_out := v_unit_msrp_sale_out * v_calculated_qty;
                    
                    -- ✅ DEBUG: Log MSRP calculation
                    RAISE NOTICE '   💰 [Auto-Select] MSRP: unit=%, total=%, margin_pct=%, discount_pct=%', 
                        v_unit_msrp_sale_out, v_total_msrp_sale_out, v_min_margin_pct, v_max_discount_pct;
                ELSE
                    -- If no cost, set MSRP to 0
                    v_unit_cost_with_taxes_calc := 0;
                    v_msrp_sale_in := 0;
                    v_unit_msrp_sale_out := 0;
                    v_total_msrp_sale_out := 0;
                    RAISE WARNING '   ⚠️  CatalogItem % (SKU: %) has no cost_exw, setting costs to 0', v_resolved_catalog_item_id, v_resolved_sku;
                END IF;
                
                -- Insert BomInstanceLine (using only existing columns)
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
                        cut_l_mm,
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_manufacturing_order.organization_id,
                        v_bom_instance_id,
                        v_resolved_catalog_item_id,
                        v_resolved_sku,
                        v_bom_component.component_role,
                        -- ✅ FIX: Convert qty when UOM changes (ft->m, etc.)
                        public.convert_qty_by_uom(
                            v_calculated_qty,
                            COALESCE(v_bom_component.uom, v_catalog_item_uom),
                            public.normalize_uom_to_canonical(COALESCE(v_bom_component.uom, v_catalog_item_uom), v_bom_component.component_role, v_bom_component.qty_type)
                        ),
                        -- ✅ FIX 1: Use BOMComponents.uom instead of CatalogItems.uom, then normalize to canonical
                        public.normalize_uom_to_canonical(COALESCE(v_bom_component.uom, v_catalog_item_uom), v_bom_component.component_role, v_bom_component.qty_type),
                        COALESCE(v_resolved_description, v_resolved_item_name),
                        v_category_code, -- Already validated to match constraint
                        COALESCE(v_unit_cost_exw, 0)::numeric(12,4),
                        COALESCE(v_total_cost_exw, 0)::numeric(12,4),
                        COALESCE(v_unit_msrp_sale_out, 0)::numeric(12,4),
                        COALESCE(v_total_msrp_sale_out, 0)::numeric(12,4),
                        -- ✅ FIX 2: Populate cut_l_mm for linear components
                        CASE 
                            WHEN v_bom_component.qty_type = 'per_width' 
                                 OR v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
                            THEN v_width_mm 
                            ELSE NULL 
                        END,
                        false,
                        now(),
                        now()
                    );
                    
                    v_created_lines := v_created_lines + 1;
                    v_bom_total_cost := v_bom_total_cost + v_total_cost_exw;
                    
                    -- ✅ DEBUG: Log final values being inserted
                    RAISE NOTICE '   ✅ Created BomInstanceLine for auto-select component % (SKU: %, Role: %, Qty: %, UOM: % (from BOMComponent.uom=%), Cost: $%, MSRP: $%, cut_l_mm=%)', 
                        v_bom_component.id, v_resolved_sku, v_bom_component.component_role, v_calculated_qty, 
                        COALESCE(v_bom_component.uom, v_catalog_item_uom), v_bom_component.uom, v_total_cost_exw, v_total_msrp_sale_out,
                        CASE 
                            WHEN v_bom_component.qty_type = 'per_width' 
                                 OR v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
                            THEN v_width_mm 
                            ELSE NULL 
                        END;
                    RAISE NOTICE '   📝 [Auto-Select] Insert values: unit_cost_exw=%, total_cost_exw=%, unit_msrp=%, total_msrp=%, uom_source=BOMComponent.uom=%', 
                        COALESCE(v_unit_cost_exw, 0), COALESCE(v_total_cost_exw, 0), COALESCE(v_unit_msrp_sale_out, 0), COALESCE(v_total_msrp_sale_out, 0), v_bom_component.uom;
                    
                    -- ✅ NEW: Expand assemblies (CatalogItemBOMLines) for resolved component
                    FOR v_assembly_line IN
                        SELECT 
                            cibl.child_item_id,
                            cibl.qty as child_qty,
                            cibl.uom as child_uom,
                            ci.sku as child_sku,
                            ci.item_name as child_item_name,
                            ci.description as child_description,
                            ci.cost_exw as child_cost_exw,
                            ic.code as child_category_code
                        FROM "CatalogItemBOMLines" cibl
                        INNER JOIN "CatalogItems" ci ON ci.id = cibl.child_item_id
                        LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                        WHERE cibl.parent_item_id = v_resolved_catalog_item_id
                        AND cibl.deleted = false
                        AND ci.deleted = false
                        ORDER BY cibl.created_at
                    LOOP
                        -- Calculate child qty (multiply parent qty by child qty per parent)
                        v_child_calculated_qty := COALESCE(v_calculated_qty, 0) * COALESCE(v_assembly_line.child_qty, 1);
                        
                        -- Calculate costs
                        v_child_unit_cost_exw := COALESCE(CAST(v_assembly_line.child_cost_exw AS numeric(12,4)), 0);
                        v_child_total_cost_exw := v_child_unit_cost_exw * v_child_calculated_qty;
                        
                        -- Calculate MSRP
                        IF v_child_unit_cost_exw > 0 THEN
                            v_unit_cost_with_taxes_calc := v_child_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                            v_msrp_sale_in := v_unit_cost_with_taxes_calc / (1 - (v_min_margin_pct / 100.0));
                            v_child_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                            v_child_total_msrp_sale_out := v_child_unit_msrp_sale_out * v_child_calculated_qty;
                        ELSE
                            v_child_unit_msrp_sale_out := 0;
                            v_child_total_msrp_sale_out := 0;
                        END IF;
                        
                        -- Map category_code
                        v_child_category_code := CASE 
                            WHEN v_assembly_line.child_category_code LIKE 'FABRIC%' THEN 'fabric'
                            WHEN v_assembly_line.child_category_code LIKE 'COMP-TUBE%' THEN 'tube'
                            WHEN v_assembly_line.child_category_code LIKE 'COMP-BRACKET%' THEN 'bracket'
                            WHEN v_assembly_line.child_category_code LIKE 'COMP-CASSETTE%' THEN 'cassette'
                            WHEN v_assembly_line.child_category_code LIKE 'COMP-SIDE%' THEN 'side_channel'
                            WHEN v_assembly_line.child_category_code LIKE 'COMP-BOTTOM%' THEN 'bottom_channel'
                            ELSE 'accessory'
                        END;
                        
                        -- Normalize child UOM and check for duplicates
                        DECLARE
                            v_child_uom_canonical text;
                        BEGIN
                            v_child_uom_canonical := public.normalize_uom_to_canonical(
                                v_assembly_line.child_uom, 
                                v_bom_component.component_role, 
                                NULL
                            );
                            
                            -- Check for duplicates (using canonical UOM)
                            IF EXISTS (
                                SELECT 1
                                FROM "BomInstanceLines" bil
                                WHERE bil.bom_instance_id = v_bom_instance_id
                                AND bil.resolved_part_id = v_assembly_line.child_item_id
                                AND COALESCE(bil.part_role, '') = COALESCE(v_bom_component.component_role, '')
                                AND bil.uom = v_child_uom_canonical
                                AND bil.deleted = false
                            ) THEN
                                RAISE NOTICE '   ⏭️  Skipping duplicate assembly child: child_item_id=%', v_assembly_line.child_item_id;
                                CONTINUE;
                            END IF;
                        END;
                        
                        -- ✅ FIX: Insert child BomInstanceLine with source='assembly_child' and parent_part_id
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
                            source,
                            parent_part_id,
                            deleted,
                            created_at,
                            updated_at
                        ) VALUES (
                            v_manufacturing_order.organization_id,
                            v_bom_instance_id,
                            v_assembly_line.child_item_id,
                            v_assembly_line.child_sku,
                            v_bom_component.component_role, -- Inherit role from parent
                            -- ✅ FIX: Convert qty when UOM changes (ft->m, etc.)
                            public.convert_qty_by_uom(
                                COALESCE(v_child_calculated_qty, v_assembly_line.child_qty),
                                v_assembly_line.child_uom,
                                public.normalize_uom_to_canonical(v_assembly_line.child_uom, v_bom_component.component_role, NULL)
                            ),
                            -- ✅ FIX: Normalize UOM to canonical (ft->m, pcs->ea, set->ea)
                            public.normalize_uom_to_canonical(v_assembly_line.child_uom, v_bom_component.component_role, NULL),
                            COALESCE(v_assembly_line.child_description, v_assembly_line.child_item_name),
                            v_child_category_code,
                            COALESCE(v_child_unit_cost_exw, 0)::numeric(12,4),
                            COALESCE(v_child_total_cost_exw, 0)::numeric(12,4),
                            COALESCE(v_child_unit_msrp_sale_out, 0)::numeric(12,4),
                            COALESCE(v_child_total_msrp_sale_out, 0)::numeric(12,4),
                            'assembly_child', -- ✅ FIX: Mark as assembly child
                            v_resolved_catalog_item_id, -- ✅ FIX: Link to parent CatalogItem
                            false,
                            now(),
                            now()
                        );
                        
                        v_created_lines := v_created_lines + 1;
                        v_bom_total_cost := v_bom_total_cost + v_child_total_cost_exw;
                        
                        RAISE NOTICE '   ✅ [Assembly] Expanded child: SKU=%, qty=%, role=%, parent=%', 
                            v_assembly_line.child_sku, v_child_calculated_qty, v_bom_component.component_role, v_resolved_sku;
                    END LOOP;
                        
                EXCEPTION
                    WHEN OTHERS THEN
                        -- ✅ FIX: Fail hard instead of silently continuing
                        RAISE EXCEPTION 'BOM generation failed at component % (auto-select: %), reason: %', 
                            v_bom_component.component_role, v_bom_component.id, SQLERRM;
                END;
            END LOOP;
        END IF;
        
        -- ✅ FIX: Calculate labor cost for this BomInstance (v_bom_total_cost already accumulated during inserts)
        -- No need to SELECT SUM - we already tracked it during inserts
        
        v_bom_labor_cost := v_bom_total_cost * (v_labor_percentage / 100.0);
        v_bom_total_cost_with_labor := v_bom_total_cost + v_bom_labor_cost;
        
        -- Calculate MSRP with labor
        v_bom_msrp_sale_in := v_bom_total_cost_with_labor / (1 - (v_min_margin_pct / 100.0));
        v_bom_msrp_sale_out := v_bom_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
        
        -- Update BomInstance with labor costs
        UPDATE "BomInstances"
        SET 
            labor_cost = v_bom_labor_cost,
            total_cost_with_labor = v_bom_total_cost_with_labor,
            total_msrp_sale_out_with_labor = v_bom_msrp_sale_out,
            updated_at = now()
        WHERE id = v_bom_instance_id;
        
        v_processed_instances := v_processed_instances + 1;
    END LOOP;
    
    -- ✅ NEW: Return JSON with counts and status
    -- ✅ FIX: Only return success if lines were actually created
    IF v_created_lines = 0 THEN
        RAISE EXCEPTION 'BOM generation completed but 0 lines were created. Check component mappings and BOM template configuration.';
    END IF;
    
    -- ✅ FIX: Merge warnings_array (from conversions) with v_warnings (from other issues)
    v_warnings := v_warnings || v_warnings_array;
    
    -- ✅ FIX: Determine ok status (false if there are errors, true otherwise)
    v_success := array_length(v_errors, 1) IS NULL OR array_length(v_errors, 1) = 0;
    
    RETURN jsonb_build_object(
        'ok', v_success,
        'manufacturing_order_id', p_manufacturing_order_id,
        'sale_order_id', v_sale_order.id,
        'created_instances', v_created_instances,
        'created_lines', v_created_lines,
        'instances_processed', v_processed_instances,
        'errors', COALESCE(v_errors, ARRAY[]::text[]),
        'warnings', COALESCE(v_warnings, ARRAY[]::text[]),
        'success', v_success  -- Keep for backward compatibility
    );
END;
$$;
