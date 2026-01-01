-- ====================================================
-- Migration 358 (REVISED): Add Auto-Select Support to BOM Generation
-- ====================================================
-- This migration updates generate_bom_for_manufacturing_order to support
-- auto-select components (when component_item_id IS NULL in BOMComponents)
-- 
-- IMPROVEMENTS IN THIS REVISION:
-- 1. Deterministic selection (selection_priority, sku) - NO "most recent"
-- 2. Hardware color: Prefer HardwareColorMapping table, regex SKU as fallback
-- 3. Block conditions: Centralized helper function
-- 4. Qty/UOM normalization: Helper function
-- 5. Performance indexes
-- 6. SQL hygiene: SET search_path
-- ====================================================

-- Set search_path for this migration
SET search_path = public;

-- ====================================================
-- STEP 1: Add selection_priority to CatalogItems if it doesn't exist
-- ====================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'selection_priority'
    ) THEN
        ALTER TABLE public."CatalogItems" 
        ADD COLUMN selection_priority integer NOT NULL DEFAULT 100;
        
        COMMENT ON COLUMN public."CatalogItems".selection_priority IS 
            'Lower values = higher priority for auto-select resolution. Default 100.';
        
        RAISE NOTICE '  ✅ Added selection_priority column to CatalogItems';
    ELSE
        RAISE NOTICE '  ℹ️  selection_priority column already exists in CatalogItems';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Helper function for block_condition checking
-- ====================================================
CREATE OR REPLACE FUNCTION public.check_block_condition(
    p_block_condition jsonb,
    p_quote_line_cassette boolean,
    p_quote_line_side_channel boolean
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_condition_met boolean := true;
BEGIN
    -- If no block_condition, component is always included
    IF p_block_condition IS NULL THEN
        RETURN true;
    END IF;
    
    -- Check cassette condition
    IF (p_block_condition->>'cassette')::boolean = true THEN
        IF COALESCE(p_quote_line_cassette, false) = false THEN
            RETURN false;
        END IF;
    END IF;
    
    -- Check side_channel condition
    IF (p_block_condition->>'side_channel')::boolean = true THEN
        IF COALESCE(p_quote_line_side_channel, false) = false THEN
            RETURN false;
        END IF;
    END IF;
    
    -- Add more condition checks here as needed in the future
    
    RETURN v_condition_met;
END;
$$;

COMMENT ON FUNCTION public.check_block_condition IS 
    'Centralized function to check if block_condition is met based on QuoteLine configuration. Returns true if component should be included, false otherwise.';

-- ====================================================
-- STEP 3: Helper function for qty normalization by UOM
-- ====================================================
CREATE OR REPLACE FUNCTION public.normalize_qty_by_uom(
    p_qty numeric,
    p_uom text
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_normalized_uom text;
    v_normalized_qty numeric;
BEGIN
    -- Normalize UOM first
    v_normalized_uom := CASE 
        WHEN p_uom = 'm' THEN 'mts'
        WHEN p_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
        WHEN p_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
        WHEN p_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
        ELSE COALESCE(p_uom, 'ea')
    END;
    
    -- Round qty based on UOM
    IF v_normalized_uom IN ('pcs', 'ea', 'piece', 'pieces') THEN
        -- For discrete units, use CEIL
        v_normalized_qty := CEIL(p_qty);
    ELSIF v_normalized_uom IN ('mts', 'm', 'm2', 'sqm', 'yd', 'yd2', 'ft', 'ft2') THEN
        -- For continuous units, keep 3 decimal places
        v_normalized_qty := ROUND(p_qty, 3);
    ELSE
        -- Default: keep original precision
        v_normalized_qty := p_qty;
    END IF;
    
    RETURN v_normalized_qty;
END;
$$;

COMMENT ON FUNCTION public.normalize_qty_by_uom IS 
    'Normalizes quantity based on UOM: pcs/ea => CEIL, m/sqm => ROUND to 3 decimals. Returns normalized quantity.';

-- ====================================================
-- STEP 4: Helper function to resolve hardware color from SKU (fallback)
-- ====================================================
CREATE OR REPLACE FUNCTION public.match_hardware_color_from_sku(
    p_sku text,
    p_hardware_color text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_sku IS NULL OR p_hardware_color IS NULL THEN
        RETURN true; -- No filter if either is NULL
    END IF;
    
    RETURN CASE 
        WHEN p_hardware_color = 'white' THEN 
            p_sku LIKE '%-W%' OR p_sku LIKE '%WHITE%' OR p_sku LIKE '%WHT%' OR p_sku ILIKE '%WH%'
        WHEN p_hardware_color = 'black' THEN 
            p_sku LIKE '%-BLK%' OR p_sku LIKE '%BLACK%' OR p_sku LIKE '%BLK%' OR p_sku ILIKE '%BK%'
        WHEN p_hardware_color IN ('grey', 'gray') THEN 
            p_sku LIKE '%-GR%' OR p_sku LIKE '%GREY%' OR p_sku LIKE '%GRAY%' OR p_sku ILIKE '%GR%'
        WHEN p_hardware_color = 'silver' THEN 
            p_sku LIKE '%-SV%' OR p_sku LIKE '%SILVER%' OR p_sku ILIKE '%SLV%'
        WHEN p_hardware_color = 'bronze' THEN 
            p_sku LIKE '%-BZ%' OR p_sku LIKE '%BRONZE%' OR p_sku ILIKE '%BRZ%'
        ELSE 
            true  -- No filter if hardware_color not recognized
    END;
END;
$$;

COMMENT ON FUNCTION public.match_hardware_color_from_sku IS 
    'Fallback function to match hardware_color from SKU using regex patterns. Used when HardwareColorMapping table does not have the mapping.';

-- ====================================================
-- STEP 5: Improved resolve_auto_select_sku with deterministic selection
-- ====================================================
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
SET search_path = public
AS $$
DECLARE
    v_resolved_catalog_item_id uuid;
    v_category_code text;
    v_candidate_count integer;
    v_base_part_id uuid;
BEGIN
    -- Map component_role to category_code
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
        RAISE EXCEPTION 'EXACT_SKU resolution not supported for auto-select components. Use component_item_id for fixed selection.';
    
    ELSIF p_sku_resolution_rule IN ('SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR') OR p_sku_resolution_rule IS NULL THEN
        -- Strategy: First try HardwareColorMapping if hardware_color is provided
        -- Otherwise, search by category_code + hardware_color pattern
        
        IF p_hardware_color IS NOT NULL THEN
            -- Strategy: Search for items in category_code that match hardware_color
            -- Prefer items that are mapped entries in HardwareColorMapping (mapped_part_id)
            -- Fallback to SKU pattern matching
            
            -- First, try to find items that are mapped_part_id in HardwareColorMapping
            SELECT hcm.mapped_part_id INTO v_resolved_catalog_item_id
            FROM "HardwareColorMapping" hcm
            INNER JOIN "CatalogItems" ci ON ci.id = hcm.base_part_id
            INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE hcm.organization_id = p_organization_id
            AND hcm.hardware_color = p_hardware_color
            AND hcm.deleted = false
            AND ci.deleted = false
            AND ic.code = v_category_code
            ORDER BY 
                COALESCE(ci.selection_priority, 100) ASC,
                ci.sku ASC
            LIMIT 1;
            
            -- If no mapping found, fallback to SKU pattern matching
            IF v_resolved_catalog_item_id IS NULL THEN
                SELECT ci.id INTO v_resolved_catalog_item_id
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND ic.code = v_category_code
                AND public.match_hardware_color_from_sku(ci.sku, p_hardware_color)
                ORDER BY 
                    COALESCE(ci.selection_priority, 100) ASC,
                    ci.sku ASC
                LIMIT 1;
            END IF;
        ELSE
            -- No hardware_color specified - search by category_code only
            SELECT ci.id INTO v_resolved_catalog_item_id
            FROM "CatalogItems" ci
            INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE ci.organization_id = p_organization_id
            AND ci.deleted = false
            AND ic.code = v_category_code
            ORDER BY 
                COALESCE(ci.selection_priority, 100) ASC,
                ci.sku ASC
            LIMIT 1;
        END IF;
        
        -- Note: Ambiguity detection removed for performance
        -- The deterministic ordering (selection_priority, sku) ensures consistent results
        -- If multiple items have same priority, the first one by sku ASC is chosen
        
        IF v_resolved_catalog_item_id IS NULL THEN
            RAISE EXCEPTION 'Could not resolve catalog_item_id for auto-select component: role=%, sku_resolution_rule=%, hardware_color=%, category_code=%, organization_id=%', 
                p_component_role, COALESCE(p_sku_resolution_rule, 'NULL'), p_hardware_color, v_category_code, p_organization_id;
        END IF;
        
        RETURN v_resolved_catalog_item_id;
    
    ELSE
        RAISE EXCEPTION 'Unsupported sku_resolution_rule for auto-select: %. Supported values: EXACT_SKU, SKU_SUFFIX_COLOR, ROLE_AND_COLOR', 
            p_sku_resolution_rule;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.resolve_auto_select_sku IS 
    'Resolves catalog_item_id for auto-select BOM components using deterministic selection: selection_priority ASC, sku ASC. Prefers HardwareColorMapping table, falls back to SKU pattern matching.';

-- ====================================================
-- STEP 6: Performance indexes
-- ====================================================
-- Index for resolve_auto_select_sku queries
CREATE INDEX IF NOT EXISTS idx_catalogitems_org_category_priority 
    ON public."CatalogItems"(organization_id, deleted)
    INCLUDE (id, sku, selection_priority, item_category_id)
    WHERE deleted = false;

-- Index for ItemCategories.code lookup
CREATE INDEX IF NOT EXISTS idx_itemcategories_code 
    ON public."ItemCategories"(code, deleted)
    WHERE deleted = false AND code IS NOT NULL;

-- Index for HardwareColorMapping lookups
CREATE INDEX IF NOT EXISTS idx_hardwarecolormapping_org_color_mapped 
    ON public."HardwareColorMapping"(organization_id, hardware_color, mapped_part_id, deleted)
    WHERE deleted = false;

-- Composite index for BOMComponents auto-select queries
CREATE INDEX IF NOT EXISTS idx_bomcomponents_template_auto_select 
    ON public."BOMComponents"(bom_template_id, auto_select, deleted, component_role)
    WHERE deleted = false AND (auto_select = true OR component_item_id IS NULL);

-- ====================================================
-- STEP 7: Main function update
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
                COALESCE(ci.item_name, ci.name) as item_name,
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
            
            -- Normalize UOM using helper function
            v_validated_uom := CASE 
                WHEN v_catalog_item_uom = 'm' THEN 'mts'
                WHEN v_catalog_item_uom IN ('meter', 'meters', 'metre', 'metres') THEN 'mts'
                WHEN v_catalog_item_uom IN ('m2', 'sqm', 'square_meter') THEN 'm2'
                WHEN v_catalog_item_uom IN ('pcs', 'piece', 'pieces', 'ea', 'each') THEN 'ea'
                ELSE v_catalog_item_uom
            END;
            
            -- Get category_code from ComponentRoleMap
            -- Note: This assumes migration 369 has been run to create get_category_code_from_role()
            -- If not available, this will use the role as-is (fallback)
            BEGIN
                v_category_code := public.get_category_code_from_role(v_quote_line_component.component_role);
            EXCEPTION
                WHEN OTHERS THEN
                    -- Fallback: use role as category_code if function doesn't exist yet
                    v_category_code := v_quote_line_component.component_role;
                    RAISE WARNING 'get_category_code_from_role() not found, using role as category_code: %', v_quote_line_component.component_role;
            END;
            
            -- Normalize qty using helper function
            v_quote_line_component.qty := public.normalize_qty_by_uom(v_quote_line_component.qty, v_validated_uom);
            
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
                SELECT ci.sku, COALESCE(ci.item_name, ci.name) as item_name, ci.description, ci.uom
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
                
                -- Normalize qty using helper function
                v_calculated_qty := public.normalize_qty_by_uom(v_calculated_qty, v_validated_uom);
                
                -- Get category_code from ComponentRoleMap
                -- Note: This assumes migration 369 has been run to create get_category_code_from_role()
                -- If not available, this will use the role as-is (fallback)
                BEGIN
                    v_category_code := public.get_category_code_from_role(v_bom_component.component_role);
                EXCEPTION
                    WHEN OTHERS THEN
                        -- Fallback: use role as category_code if function doesn't exist yet
                        v_category_code := v_bom_component.component_role;
                        RAISE WARNING 'get_category_code_from_role() not found, using role as category_code: %', v_bom_component.component_role;
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
    'Generates/updates BOM for a Manufacturing Order: (1) creates BomInstances and BomInstanceLines from QuoteLineComponents (fixed) and BOMComponents (auto-select), (2) applies engineering rules, (3) uses CatalogItems.uom as primary source. Auto-select components use deterministic selection (selection_priority, sku) and prefer HardwareColorMapping table.';

-- ====================================================
-- STEP 8: EXPLAIN queries for performance analysis
-- ====================================================
-- Note: These are documentation queries, not executed in migration
-- Run these manually to verify index usage:
--
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT ci.id
-- FROM "CatalogItems" ci
-- INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
-- LEFT JOIN "HardwareColorMapping" hcm ON hcm.mapped_part_id = ci.id 
--     AND hcm.hardware_color = 'white' 
--     AND hcm.organization_id = '...' 
--     AND hcm.deleted = false
-- WHERE ci.organization_id = '...'
-- AND ci.deleted = false
-- AND ic.code = 'bracket'
-- ORDER BY 
--     CASE WHEN hcm.id IS NOT NULL THEN 0 ELSE 1 END,
--     COALESCE(ci.selection_priority, 100) ASC,
--     ci.sku ASC
-- LIMIT 1;
--
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT bc.id, bc.component_role, bc.auto_select, bc.hardware_color, bc.block_condition
-- FROM "BOMComponents" bc
-- WHERE bc.bom_template_id = '...'
-- AND bc.deleted = false
-- AND (bc.auto_select = true OR bc.component_item_id IS NULL)
-- AND bc.component_role IS NOT NULL;

