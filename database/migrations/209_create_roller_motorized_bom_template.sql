-- ====================================================
-- Migration: Create BOM Template for Motorized Roller Shade
-- ====================================================
-- Creates a BOM template named 'ROLLER_MOTORIZED_STANDARD' for motorized roller shades
-- Based on ROLLER_MANUAL_STANDARD but with motor components instead of manual drive/chain
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_org_id uuid;
    v_roller_shade_type_id uuid;
    v_template_id uuid;
    v_product_types_table text;
    
    -- Required SKUs list (for verification, not for hard-linking)
    -- Note: Motor components are variable and handled by auto_select, so not listed here
    v_required_skus text[] := ARRAY[
        'RC3006',  -- bracket (white)
        'RC3008',  -- bracket (black)
        'RTU-42',  -- tube option 1
        'RTU-50',  -- tube option 2
        'RCA04',   -- bottom rail (or RCA-04)
        'RCA21'    -- bottom rail end cap (or RCA-21)
    ];
    
    -- Schema introspection flags
    v_has_deleted_column boolean;
    v_has_affects_role_column boolean;
    v_has_cut_axis_column boolean;
    v_has_cut_delta_mm_column boolean;
    v_has_cut_delta_scope_column boolean;
    
    v_seq integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Creating BOM Template: ROLLER_MOTORIZED_STANDARD';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- ====================================================
    -- STEP 1: Schema introspection - Check column existence
    -- ====================================================
    RAISE NOTICE 'STEP 1: Introspecting schema...';
    
    -- Check if BOMComponents has deleted column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'deleted'
    ) INTO v_has_deleted_column;
    
    -- Check if BOMComponents has engineering rules columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'affects_role'
    ) INTO v_has_affects_role_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'cut_axis'
    ) INTO v_has_cut_axis_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'cut_delta_mm'
    ) INTO v_has_cut_delta_mm_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'cut_delta_scope'
    ) INTO v_has_cut_delta_scope_column;
    
    RAISE NOTICE '  Schema check: deleted=% | engineering_rules=%', 
        v_has_deleted_column, 
        (v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column);
    
    -- ====================================================
    -- STEP 2: Determine ProductTypes table name
    -- ====================================================
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ProductTypes') THEN
        v_product_types_table := 'ProductTypes';
    ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'Profiles') THEN
        v_product_types_table := 'Profiles';
    ELSE
        RAISE EXCEPTION 'Neither ProductTypes nor Profiles table found';
    END IF;
    
    RAISE NOTICE 'STEP 2: Using ProductTypes table: %', v_product_types_table;
    
    -- ====================================================
    -- STEP 3: Get organization ID
    -- ====================================================
    SELECT id INTO v_org_id 
    FROM "Organizations" 
    WHERE deleted = false 
    ORDER BY created_at ASC 
    LIMIT 1;
    
    IF v_org_id IS NULL THEN 
        RAISE EXCEPTION 'No active organization found';
    END IF;
    
    RAISE NOTICE 'STEP 3: Organization ID: %', v_org_id;
    
    -- ====================================================
    -- STEP 4: Get Roller Shade ProductType ID
    -- ====================================================
    EXECUTE format('SELECT id FROM "%s" WHERE organization_id = $1 AND deleted = false AND (name ILIKE ''%%roller%%shade%%'' OR name = ''Roller Shade'' OR code ILIKE ''%%ROLLER%%'') LIMIT 1', v_product_types_table) 
    INTO v_roller_shade_type_id 
    USING v_org_id;
    
    IF v_roller_shade_type_id IS NULL THEN
        RAISE EXCEPTION 'Roller Shade ProductType not found. Please create it first.';
    END IF;
    
    RAISE NOTICE 'STEP 4: Roller Shade ProductType ID: %', v_roller_shade_type_id;
    
    -- ====================================================
    -- STEP 5: Create or get BOMTemplate
    -- ====================================================
    RAISE NOTICE 'STEP 5: Creating/updating BOMTemplate...';
    
    -- Try to get existing template first
    SELECT id INTO v_template_id 
    FROM "BOMTemplates" 
    WHERE organization_id = v_org_id 
    AND product_type_id = v_roller_shade_type_id 
    AND name = 'ROLLER_MOTORIZED_STANDARD' 
    AND deleted = false;
    
    IF v_template_id IS NULL THEN
        -- Create new template
        INSERT INTO "BOMTemplates" (organization_id, product_type_id, name, description, active, deleted)
        VALUES (v_org_id, v_roller_shade_type_id, 'ROLLER_MOTORIZED_STANDARD', 'Motorized Roller Shade - Standard Configuration', true, false)
        RETURNING id INTO v_template_id;
        
        RAISE NOTICE '  ✅ Created new BOMTemplate with ID: %', v_template_id;
    ELSE
        RAISE NOTICE '  ℹ️  Template already exists with ID: %. Soft-deleting existing components...', v_template_id;
        
        -- Soft-delete existing components if column exists
        IF v_has_deleted_column THEN
            UPDATE "BOMComponents" 
            SET deleted = true 
            WHERE bom_template_id = v_template_id;
        ELSE
            -- Hard delete if no deleted column
            DELETE FROM "BOMComponents" 
            WHERE bom_template_id = v_template_id;
        END IF;
    END IF;
    
    -- ====================================================
    -- STEP 6: Insert BOMComponents (single line per role, auto_select=true for color/options)
    -- ====================================================
    RAISE NOTICE 'STEP 6: Inserting BOMComponents...';
    
    v_seq := 10;
    
    -- A) Brackets - single line with applies_color=true, auto_select=true
    -- Engineering rule: affects tube length (-10mm per side)
    IF v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column THEN
        INSERT INTO "BOMComponents" (
            bom_template_id, organization_id, component_role, component_item_id, 
            qty_per_unit, uom, sequence_order, 
            applies_color, auto_select, deleted,
            affects_role, cut_axis, cut_delta_mm, cut_delta_scope
        ) VALUES (
            v_template_id, v_org_id, 'bracket', NULL,
            2, 'ea', v_seq,
            true, true, false,
            'tube', 'length', -10, 'per_side'
        );
    ELSE
        INSERT INTO "BOMComponents" (
            bom_template_id, organization_id, component_role, component_item_id, 
            qty_per_unit, uom, sequence_order, 
            applies_color, auto_select, deleted
        ) VALUES (
            v_template_id, v_org_id, 'bracket', NULL,
            2, 'ea', v_seq,
            true, true, false
        );
    END IF;
    RAISE NOTICE '  ✅ Inserted bracket (auto_select=true, applies_color=true) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- B) Tube - single line with auto_select=true (resolver picks RTU-42 or RTU-50 by width)
    INSERT INTO "BOMComponents" (
        bom_template_id, organization_id, component_role, component_item_id, 
        qty_per_unit, uom, sequence_order, 
        applies_color, auto_select, deleted
    ) VALUES (
        v_template_id, v_org_id, 'tube', NULL,
        1, 'm', v_seq,
        false, true, false
    );
    RAISE NOTICE '  ✅ Inserted tube (auto_select=true, qty=width_m) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- C) Fabric - placeholder, resolved from configured product
    INSERT INTO "BOMComponents" (
        bom_template_id, organization_id, component_role, component_item_id, 
        qty_per_unit, uom, sequence_order, 
        applies_color, auto_select, deleted
    ) VALUES (
        v_template_id, v_org_id, 'fabric', NULL,
        1, 'm2', v_seq,
        false, true, false
    );
    RAISE NOTICE '  ✅ Inserted fabric placeholder (auto_select=true, qty=width_m*height_m) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- D) Bottom Rail Profile - single line with applies_color=true, auto_select=true
    -- Engineering rule: affects itself length (-6mm per side)
    -- Note: Using 'bottom_rail_profile' (not 'bottom_rail') to match constraint
    IF v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column THEN
        INSERT INTO "BOMComponents" (
            bom_template_id, organization_id, component_role, component_item_id, 
            qty_per_unit, uom, sequence_order, 
            applies_color, auto_select, deleted,
            affects_role, cut_axis, cut_delta_mm, cut_delta_scope
        ) VALUES (
            v_template_id, v_org_id, 'bottom_rail_profile', NULL,
            1, 'm', v_seq,
            true, true, false,
            'bottom_rail_profile', 'length', -6, 'per_side'
        );
    ELSE
        INSERT INTO "BOMComponents" (
            bom_template_id, organization_id, component_role, component_item_id, 
            qty_per_unit, uom, sequence_order, 
            applies_color, auto_select, deleted
        ) VALUES (
            v_template_id, v_org_id, 'bottom_rail_profile', NULL,
            1, 'm', v_seq,
            true, true, false
        );
    END IF;
    RAISE NOTICE '  ✅ Inserted bottom rail profile (auto_select=true, applies_color=true) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- E) Bottom Rail End Caps - single line with applies_color=true, auto_select=true
    INSERT INTO "BOMComponents" (
        bom_template_id, organization_id, component_role, component_item_id, 
        qty_per_unit, uom, sequence_order, 
        applies_color, auto_select, deleted
    ) VALUES (
        v_template_id, v_org_id, 'bottom_rail_end_cap', NULL,
        2, 'ea', v_seq,
        true, true, false
    );
    RAISE NOTICE '  ✅ Inserted bottom rail end cap (auto_select=true, applies_color=true) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- F) Motor Drive - using 'operating_system_drive' with block_condition for motor
    -- Note: Using 'operating_system_drive' with block_condition to match constraint
    -- The resolver should use block_condition to filter for motor drives
    INSERT INTO "BOMComponents" (
        bom_template_id, organization_id, component_role, component_item_id, 
        qty_per_unit, uom, sequence_order, 
        block_type, block_condition, applies_color, auto_select, deleted
    ) VALUES (
        v_template_id, v_org_id, 'operating_system_drive', NULL,
        1, 'ea', v_seq,
        'drive', '{"drive_type": "motor"}'::jsonb,
        false, true, false
    );
    RAISE NOTICE '  ✅ Inserted operating system drive (motor, auto_select=true) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- G) Motor - using 'motor' role (if in constraint) or 'operating_system_drive' with metadata
    -- Note: 'motor' role should be in constraint based on migration 138/141
    INSERT INTO "BOMComponents" (
        bom_template_id, organization_id, component_role, component_item_id, 
        qty_per_unit, uom, sequence_order, 
        block_type, block_condition, applies_color, auto_select, deleted
    ) VALUES (
        v_template_id, v_org_id, 'motor', NULL,
        1, 'ea', v_seq,
        'drive', '{"drive_type": "motor"}'::jsonb,
        false, true, false
    );
    RAISE NOTICE '  ✅ Inserted motor (auto_select=true) at sequence %', v_seq;
    v_seq := v_seq + 10;
    
    -- H) Motor Adapter - using 'motor_adapter' role (if in constraint)
    INSERT INTO "BOMComponents" (
        bom_template_id, organization_id, component_role, component_item_id, 
        qty_per_unit, uom, sequence_order, 
        block_type, block_condition, applies_color, auto_select, deleted
    ) VALUES (
        v_template_id, v_org_id, 'motor_adapter', NULL,
        1, 'ea', v_seq,
        'drive', '{"drive_type": "motor"}'::jsonb,
        false, true, false
    );
    RAISE NOTICE '  ✅ Inserted motor adapter (auto_select=true) at sequence %', v_seq;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ BOM Template created successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Note: All components use auto_select=true to allow the resolver';
    RAISE NOTICE '      to pick the correct SKU based on hardware_color, width rules, motor type, etc.';
    RAISE NOTICE '';
    
END $$;

-- ====================================================
-- VERIFICATION QUERIES
-- ====================================================

-- 1) Show the created template (using dynamic SQL to avoid referencing non-existent tables)
DO $$
DECLARE
    v_product_types_table text;
    v_template_id uuid;
    v_template_name text;
    v_template_desc text;
    v_template_active boolean;
    v_product_type_name text;
BEGIN
    -- Detect ProductTypes table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ProductTypes') THEN
        v_product_types_table := 'ProductTypes';
    ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'Profiles') THEN
        v_product_types_table := 'Profiles';
    ELSE
        RAISE NOTICE '⚠️  Cannot verify template: ProductTypes/Profiles table not found';
        RETURN;
    END IF;
    
    -- Get template info
    SELECT id, name, description, active INTO v_template_id, v_template_name, v_template_desc, v_template_active
    FROM "BOMTemplates"
    WHERE name = 'ROLLER_MOTORIZED_STANDARD' AND deleted = false
    LIMIT 1;
    
    IF v_template_id IS NULL THEN
        RAISE NOTICE '⚠️  Template ROLLER_MOTORIZED_STANDARD not found';
        RETURN;
    END IF;
    
    -- Get product type name
    EXECUTE format('SELECT name FROM "%s" WHERE id = $1', v_product_types_table)
    INTO v_product_type_name
    USING (SELECT product_type_id FROM "BOMTemplates" WHERE id = v_template_id);
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEMPLATE VERIFICATION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ID: %', v_template_id;
    RAISE NOTICE 'Name: %', v_template_name;
    RAISE NOTICE 'Description: %', v_template_desc;
    RAISE NOTICE 'Active: %', v_template_active;
    RAISE NOTICE 'Product Type: %', v_product_type_name;
    RAISE NOTICE '';
END $$;

-- 2) Show all components for the template
SELECT 
    bc.sequence_order,
    bc.component_role,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom,
    bc.applies_color,
    bc.auto_select,
    bc.block_type,
    bc.block_condition,
    bc.affects_role,
    bc.cut_axis,
    bc.cut_delta_mm,
    bc.cut_delta_scope
FROM "BOMComponents" bc
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
WHERE bt.name = 'ROLLER_MOTORIZED_STANDARD' 
AND bt.deleted = false 
AND bc.deleted = false
ORDER BY bc.sequence_order;

-- 3) Missing SKUs report (simplified - motor SKUs are variable, so we only check common ones)
WITH required_skus AS (
    SELECT unnest(ARRAY[
        'RC3006',  -- bracket
        'RC3008',  -- bracket
        'RTU-42',  -- tube
        'RTU-50',  -- tube
        'RCA04',   -- bottom rail (base SKU, may have variants like RCA-04, RCA04-W, etc.)
        'RCA21'    -- bottom rail end cap (base SKU, may have variants like RCA-21, RCA21-W, etc.)
        -- Motor SKUs are variable and handled by auto_select, so not listing specific motor SKUs here
    ]) as sku
),
org_id AS (
    SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
SELECT DISTINCT
    rs.sku as required_sku,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM "CatalogItems" ci, org_id oid
            WHERE ci.organization_id = oid.id
            AND ci.deleted = false
            AND ci.sku IS NOT NULL
            AND (
                -- Exact match
                ci.sku = rs.sku 
                -- Match with suffix (e.g., RCA04-W, RCA04-BK)
                OR ci.sku LIKE rs.sku || '-%' 
                OR ci.sku LIKE rs.sku || '_%'
                -- Match with prefix hyphen (e.g., RCA-04 matches RCA04)
                OR ci.sku = REPLACE(rs.sku, 'RCA', 'RCA-') 
                OR ci.sku = REPLACE(rs.sku, 'RCA-', 'RCA')
                -- Match with hyphen variants (e.g., RCA-04-W matches RCA04)
                OR REPLACE(ci.sku, '-', '') = REPLACE(rs.sku, '-', '')
                OR REPLACE(ci.sku, '-', '') LIKE REPLACE(rs.sku, '-', '') || '%'
                -- General pattern match (fallback)
                OR ci.sku ILIKE '%' || REPLACE(rs.sku, '-', '') || '%'
            )
        ) THEN '✅ Found'
        ELSE '❌ Missing'
    END as status,
    CASE 
        WHEN rs.sku IN ('RC3006', 'RC3008') THEN 'bracket'
        WHEN rs.sku IN ('RTU-42', 'RTU-50') THEN 'tube'
        WHEN rs.sku IN ('RCA04', 'RCA-04') THEN 'bottom rail'
        WHEN rs.sku IN ('RCA21', 'RCA-21') THEN 'bottom rail end cap'
        ELSE 'unknown'
    END as component_type
FROM required_skus rs
ORDER BY rs.sku;

COMMIT;


