-- ====================================================
-- Migration: Update ROLLER_MANUAL_STANDARD with Idle End Components
-- ====================================================
-- Adds idle end components (RC3085 vs RC3005+RC2003) to ROLLER_MANUAL_STANDARD template
-- with conditional logic: if RC3085 exists, use it; otherwise use RC3005 + RC2003
-- Includes engineering rules that affect tube length
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_org_id uuid;
    v_template_id uuid;
    
    -- CatalogItem IDs (resolved by SKU)
    v_rc3085_id uuid;
    v_rc3005_id uuid;
    v_rc2003_id uuid;
    v_rc2004_id uuid;
    
    -- Schema introspection flags
    v_has_deleted_column boolean;
    v_has_affects_role_column boolean;
    v_has_cut_axis_column boolean;
    v_has_cut_delta_mm_column boolean;
    v_has_cut_delta_scope_column boolean;
    v_has_calc_notes_column boolean;
    
    -- Sequence tracking
    v_seq_bracket integer;
    v_seq_idle integer;
    v_seq_tube integer;
    v_idle_cut_delta_mm numeric := -12;  -- Placeholder: -12mm cut for idle end (configurable, document in calc_notes)
    
    -- Component IDs for soft-delete
    v_existing_rc3085_id uuid;
    v_existing_rc3005_id uuid;
    v_existing_rc2003_id uuid;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Updating ROLLER_MANUAL_STANDARD: Adding Idle End Components';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- ====================================================
    -- STEP 1: Schema introspection
    -- ====================================================
    RAISE NOTICE 'STEP 1: Introspecting schema...';
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'deleted'
    ) INTO v_has_deleted_column;
    
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
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMComponents' 
        AND column_name = 'calc_notes'
    ) INTO v_has_calc_notes_column;
    
    RAISE NOTICE '  Schema check: deleted=% | engineering_rules=% | calc_notes=%', 
        v_has_deleted_column, 
        (v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column),
        v_has_calc_notes_column;
    
    -- ====================================================
    -- STEP 2: Get organization ID
    -- ====================================================
    SELECT id INTO v_org_id 
    FROM "Organizations" 
    WHERE deleted = false 
    ORDER BY created_at ASC 
    LIMIT 1;
    
    IF v_org_id IS NULL THEN 
        RAISE EXCEPTION 'No active organization found';
    END IF;
    
    RAISE NOTICE 'STEP 2: Organization ID: %', v_org_id;
    
    -- ====================================================
    -- STEP 3: Get BOMTemplate ID
    -- ====================================================
    SELECT id INTO v_template_id 
    FROM "BOMTemplates" 
    WHERE organization_id = v_org_id 
    AND name = 'ROLLER_MANUAL_STANDARD' 
    AND deleted = false;
    
    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'ROLLER_MANUAL_STANDARD template not found. Please run migration 208 first.';
    END IF;
    
    RAISE NOTICE 'STEP 3: Template ID: %', v_template_id;
    
    -- ====================================================
    -- STEP 4: Resolve CatalogItems by SKU
    -- ====================================================
    RAISE NOTICE 'STEP 4: Resolving CatalogItems by SKU...';
    
    -- RC3085: Heavy Duty Idle End (replaces RC3005 + RC2003)
    SELECT id INTO v_rc3085_id
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND (
        sku = 'RC3085'
        OR sku LIKE 'RC3085-%'
        OR sku LIKE 'RC3085_%'
        OR sku ILIKE '%RC3085%'
    )
    LIMIT 1;
    
    -- RC3005: Standard Idle End
    SELECT id INTO v_rc3005_id
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND (
        sku = 'RC3005'
        OR sku LIKE 'RC3005-%'
        OR sku LIKE 'RC3005_%'
        OR sku ILIKE '%RC3005%'
    )
    LIMIT 1;
    
    -- RC2003: Pin (between idle end and bracket)
    SELECT id INTO v_rc2003_id
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND (
        sku = 'RC2003'
        OR sku LIKE 'RC2003-%'
        OR sku LIKE 'RC2003_%'
        OR sku ILIKE '%RC2003%'
    )
    LIMIT 1;
    
    -- RC2004: Alternative pin SKU (check if exists)
    SELECT id INTO v_rc2004_id
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND (
        sku = 'RC2004'
        OR sku LIKE 'RC2004-%'
        OR sku LIKE 'RC2004_%'
        OR sku ILIKE '%RC2004%'
    )
    LIMIT 1;
    
    -- If RC2003 not found but RC2004 exists, use RC2004
    IF v_rc2003_id IS NULL AND v_rc2004_id IS NOT NULL THEN
        v_rc2003_id := v_rc2004_id;
        RAISE NOTICE '  ℹ️  Using RC2004 instead of RC2003 for pin';
    END IF;
    
    RAISE NOTICE '  RC3085 (Heavy Duty Idle End): %', COALESCE(v_rc3085_id::text, 'NOT FOUND');
    RAISE NOTICE '  RC3005 (Standard Idle End): %', COALESCE(v_rc3005_id::text, 'NOT FOUND');
    RAISE NOTICE '  RC2003/RC2004 (Pin): %', COALESCE(v_rc2003_id::text, 'NOT FOUND');
    
    -- ====================================================
    -- STEP 5: Get sequence orders for positioning
    -- ====================================================
    -- Find bracket sequence (idle_end should go after bracket, before tube)
    SELECT sequence_order INTO v_seq_bracket
    FROM "BOMComponents"
    WHERE bom_template_id = v_template_id
    AND component_role = 'bracket'
    AND deleted = false
    LIMIT 1;
    
    SELECT sequence_order INTO v_seq_tube
    FROM "BOMComponents"
    WHERE bom_template_id = v_template_id
    AND component_role = 'tube'
    AND deleted = false
    LIMIT 1;
    
    -- Position idle_end components between bracket and tube
    -- If bracket is at 10 and tube at 20, idle_end goes at 15
    IF v_seq_bracket IS NOT NULL AND v_seq_tube IS NOT NULL THEN
        v_seq_idle := v_seq_bracket + 5;
    ELSIF v_seq_bracket IS NOT NULL THEN
        v_seq_idle := v_seq_bracket + 10;
    ELSE
        v_seq_idle := 15;  -- Default position
    END IF;
    
    RAISE NOTICE 'STEP 5: Positioning idle_end components at sequence: % (between bracket=% and tube=%)', 
        v_seq_idle, v_seq_bracket, v_seq_tube;
    
    -- ====================================================
    -- STEP 6: Find and soft-delete existing idle_end components
    -- ====================================================
    RAISE NOTICE 'STEP 6: Removing existing idle_end components...';
    
    -- Find existing components
    SELECT id INTO v_existing_rc3085_id
    FROM "BOMComponents"
    WHERE bom_template_id = v_template_id
    AND (
        (component_item_id = v_rc3085_id AND v_rc3085_id IS NOT NULL)
        OR component_role = 'idle_end'
    )
    AND deleted = false
    LIMIT 1;
    
    SELECT id INTO v_existing_rc3005_id
    FROM "BOMComponents"
    WHERE bom_template_id = v_template_id
    AND (
        (component_item_id = v_rc3005_id AND v_rc3005_id IS NOT NULL)
        OR (component_role = 'idle_end' AND component_item_id != COALESCE(v_rc3085_id, '00000000-0000-0000-0000-000000000000'::uuid))
    )
    AND deleted = false
    LIMIT 1;
    
    SELECT id INTO v_existing_rc2003_id
    FROM "BOMComponents"
    WHERE bom_template_id = v_template_id
    AND (
        (component_item_id = v_rc2003_id AND v_rc2003_id IS NOT NULL)
        OR component_role = 'pin'
    )
    AND deleted = false
    LIMIT 1;
    
    -- Soft-delete existing components
    IF v_has_deleted_column THEN
        IF v_existing_rc3085_id IS NOT NULL THEN
            UPDATE "BOMComponents" SET deleted = true WHERE id = v_existing_rc3085_id;
            RAISE NOTICE '  ✅ Soft-deleted existing RC3085 component';
        END IF;
        
        IF v_existing_rc3005_id IS NOT NULL THEN
            UPDATE "BOMComponents" SET deleted = true WHERE id = v_existing_rc3005_id;
            RAISE NOTICE '  ✅ Soft-deleted existing RC3005 component';
        END IF;
        
        IF v_existing_rc2003_id IS NOT NULL THEN
            UPDATE "BOMComponents" SET deleted = true WHERE id = v_existing_rc2003_id;
            RAISE NOTICE '  ✅ Soft-deleted existing RC2003/RC2004 component';
        END IF;
        
        -- Also soft-delete any other idle_end or pin components
        UPDATE "BOMComponents"
        SET deleted = true
        WHERE bom_template_id = v_template_id
        AND component_role IN ('idle_end', 'pin')
        AND deleted = false;
        
        RAISE NOTICE '  ✅ Soft-deleted all existing idle_end and pin components';
    ELSE
        -- Hard delete if no deleted column
        DELETE FROM "BOMComponents"
        WHERE bom_template_id = v_template_id
        AND (
            component_item_id IN (v_rc3085_id, v_rc3005_id, v_rc2003_id)
            OR component_role IN ('idle_end', 'pin')
        );
        
        RAISE NOTICE '  ✅ Hard-deleted all existing idle_end and pin components';
    END IF;
    
    -- ====================================================
    -- STEP 7: Insert new components based on logic
    -- ====================================================
    RAISE NOTICE 'STEP 7: Inserting new idle_end components...';
    
    IF v_rc3085_id IS NOT NULL THEN
        -- CASE 1: RC3085 exists → Use RC3085 only (replaces RC3005 + RC2003)
        RAISE NOTICE '  ✅ RC3085 found → Using RC3085 (Heavy Duty Idle End)';
        
        IF v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column THEN
            -- Insert with engineering rule
            IF v_has_calc_notes_column THEN
                INSERT INTO "BOMComponents" (
                    bom_template_id, organization_id, component_role, component_item_id, 
                    qty_per_unit, uom, sequence_order, 
                    applies_color, auto_select, deleted,
                    affects_role, cut_axis, cut_delta_mm, cut_delta_scope,
                    calc_notes
                ) VALUES (
                    v_template_id, v_org_id, 'idle_end', v_rc3085_id,
                    1, 'ea', v_seq_idle,
                    true, false, false,  -- applies_color=true, auto_select=false (specific SKU)
                    'tube', 'length', v_idle_cut_delta_mm, 'per_item',
                    'RC3085 Heavy Duty Idle End replaces RC3005 + RC2003. Cuts tube length by ' || ABS(v_idle_cut_delta_mm) || 'mm on idle side. cut_delta_scope=per_item means one_side (idle side only).'
                );
            ELSE
                INSERT INTO "BOMComponents" (
                    bom_template_id, organization_id, component_role, component_item_id, 
                    qty_per_unit, uom, sequence_order, 
                    applies_color, auto_select, deleted,
                    affects_role, cut_axis, cut_delta_mm, cut_delta_scope
                ) VALUES (
                    v_template_id, v_org_id, 'idle_end', v_rc3085_id,
                    1, 'ea', v_seq_idle,
                    true, false, false,
                    'tube', 'length', v_idle_cut_delta_mm, 'per_item'
                );
            END IF;
        ELSE
            -- Insert without engineering rules
            INSERT INTO "BOMComponents" (
                bom_template_id, organization_id, component_role, component_item_id, 
                qty_per_unit, uom, sequence_order, 
                applies_color, auto_select, deleted
            ) VALUES (
                v_template_id, v_org_id, 'idle_end', v_rc3085_id,
                1, 'ea', v_seq_idle,
                true, false, false
            );
        END IF;
        
        RAISE NOTICE '    ✅ Inserted RC3085 with engineering rule (affects tube length by %mm)', ABS(v_idle_cut_delta_mm);
        
    ELSIF v_rc3005_id IS NOT NULL THEN
        -- CASE 2: RC3085 NOT exists, but RC3005 exists → Use RC3005 + RC2003 (if RC2003 exists)
        RAISE NOTICE '  ✅ RC3085 NOT found, RC3005 found → Using RC3005 + RC2003';
        
        -- Insert RC3005
        IF v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column THEN
            IF v_has_calc_notes_column THEN
                INSERT INTO "BOMComponents" (
                    bom_template_id, organization_id, component_role, component_item_id, 
                    qty_per_unit, uom, sequence_order, 
                    applies_color, auto_select, deleted,
                    affects_role, cut_axis, cut_delta_mm, cut_delta_scope,
                    calc_notes
                ) VALUES (
                    v_template_id, v_org_id, 'idle_end', v_rc3005_id,
                    1, 'ea', v_seq_idle,
                    true, false, false,
                    'tube', 'length', v_idle_cut_delta_mm, 'per_item',
                    'RC3005 Standard Idle End. Cuts tube length by ' || ABS(v_idle_cut_delta_mm) || 'mm on idle side. cut_delta_scope=per_item means one_side (idle side only).'
                );
            ELSE
                INSERT INTO "BOMComponents" (
                    bom_template_id, organization_id, component_role, component_item_id, 
                    qty_per_unit, uom, sequence_order, 
                    applies_color, auto_select, deleted,
                    affects_role, cut_axis, cut_delta_mm, cut_delta_scope
                ) VALUES (
                    v_template_id, v_org_id, 'idle_end', v_rc3005_id,
                    1, 'ea', v_seq_idle,
                    true, false, false,
                    'tube', 'length', v_idle_cut_delta_mm, 'per_item'
                );
            END IF;
        ELSE
            INSERT INTO "BOMComponents" (
                bom_template_id, organization_id, component_role, component_item_id, 
                qty_per_unit, uom, sequence_order, 
                applies_color, auto_select, deleted
            ) VALUES (
                v_template_id, v_org_id, 'idle_end', v_rc3005_id,
                1, 'ea', v_seq_idle,
                true, false, false
            );
        END IF;
        
        RAISE NOTICE '    ✅ Inserted RC3005 with engineering rule (affects tube length by %mm)', ABS(v_idle_cut_delta_mm);
        
        -- Insert RC2003 (pin) if it exists
        IF v_rc2003_id IS NOT NULL THEN
            INSERT INTO "BOMComponents" (
                bom_template_id, organization_id, component_role, component_item_id, 
                qty_per_unit, uom, sequence_order, 
                applies_color, auto_select, deleted
            ) VALUES (
                v_template_id, v_org_id, 'pin', v_rc2003_id,
                1, 'ea', v_seq_idle + 1,
                true, false, false
            );
            
            RAISE NOTICE '    ✅ Inserted RC2003/RC2004 (pin)';
        ELSE
            RAISE NOTICE '    ⚠️  RC2003/RC2004 (pin) not found in catalog - skipping';
        END IF;
        
    ELSE
        -- CASE 3: Neither RC3085 nor RC3005 exists → Create placeholder with auto_select=true
        RAISE NOTICE '  ⚠️  Neither RC3085 nor RC3005 found → Creating placeholder with auto_select=true';
        
        IF v_has_affects_role_column AND v_has_cut_axis_column AND v_has_cut_delta_mm_column AND v_has_cut_delta_scope_column THEN
            IF v_has_calc_notes_column THEN
                INSERT INTO "BOMComponents" (
                    bom_template_id, organization_id, component_role, component_item_id, 
                    qty_per_unit, uom, sequence_order, 
                    applies_color, auto_select, deleted,
                    affects_role, cut_axis, cut_delta_mm, cut_delta_scope,
                    calc_notes
                ) VALUES (
                    v_template_id, v_org_id, 'idle_end', NULL,
                    1, 'ea', v_seq_idle,
                    true, true, false,  -- auto_select=true to let resolver pick SKU
                    'tube', 'length', v_idle_cut_delta_mm, 'per_item',
                    'MISSING SKU: RC3085 (preferred) or RC3005. Resolver should pick based on tube size/weight. Cuts tube length by ' || ABS(v_idle_cut_delta_mm) || 'mm on idle side. cut_delta_scope=per_item means one_side (idle side only).'
                );
            ELSE
                INSERT INTO "BOMComponents" (
                    bom_template_id, organization_id, component_role, component_item_id, 
                    qty_per_unit, uom, sequence_order, 
                    applies_color, auto_select, deleted,
                    affects_role, cut_axis, cut_delta_mm, cut_delta_scope
                ) VALUES (
                    v_template_id, v_org_id, 'idle_end', NULL,
                    1, 'ea', v_seq_idle,
                    true, true, false,
                    'tube', 'length', v_idle_cut_delta_mm, 'per_item'
                );
            END IF;
        ELSE
            INSERT INTO "BOMComponents" (
                bom_template_id, organization_id, component_role, component_item_id, 
                qty_per_unit, uom, sequence_order, 
                applies_color, auto_select, deleted
            ) VALUES (
                v_template_id, v_org_id, 'idle_end', NULL,
                1, 'ea', v_seq_idle,
                true, true, false
            );
        END IF;
        
        RAISE NOTICE '    ✅ Inserted placeholder idle_end (auto_select=true, SKU missing)';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Idle End components updated successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Logic applied:';
    IF v_rc3085_id IS NOT NULL THEN
        RAISE NOTICE '  → RC3085 found → Using RC3085 only (replaces RC3005 + RC2003)';
    ELSIF v_rc3005_id IS NOT NULL THEN
        RAISE NOTICE '  → RC3005 found → Using RC3005 + RC2003 (if RC2003 exists)';
    ELSE
        RAISE NOTICE '  → Placeholder created (auto_select=true, SKU missing)';
    END IF;
    RAISE NOTICE '';
    
END $$;

-- ====================================================
-- VERIFICATION QUERIES
-- ====================================================

-- 1) Verify that RC3085 and RC3005 never coexist in the template
SELECT 
    'VALIDATION: RC3085 vs RC3005 coexistence' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            INNER JOIN "CatalogItems" ci1 ON ci1.id = bc.component_item_id
            WHERE bt.name = 'ROLLER_MANUAL_STANDARD' 
            AND bt.deleted = false 
            AND bc.deleted = false
            AND ci1.sku LIKE 'RC3085%'
        ) AND EXISTS (
            SELECT 1 
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            INNER JOIN "CatalogItems" ci2 ON ci2.id = bc.component_item_id
            WHERE bt.name = 'ROLLER_MANUAL_STANDARD' 
            AND bt.deleted = false 
            AND bc.deleted = false
            AND (ci2.sku LIKE 'RC3005%' OR ci2.sku LIKE 'RC2003%' OR ci2.sku LIKE 'RC2004%')
        ) THEN '❌ ERROR: RC3085 and RC3005/RC2003 coexist (should not)'
        ELSE '✅ OK: RC3085 and RC3005/RC2003 do not coexist'
    END as status;

-- 2) Verify that idle_end component has engineering rule affecting tube
SELECT 
    'VALIDATION: Idle end engineering rule' as check_name,
    bc.component_role,
    ci.sku,
    bc.affects_role,
    bc.cut_axis,
    bc.cut_delta_mm,
    bc.cut_delta_scope,
    CASE 
        WHEN bc.affects_role = 'tube' 
         AND bc.cut_axis = 'length' 
         AND bc.cut_delta_mm < 0 
         AND bc.cut_delta_scope IS NOT NULL THEN '✅ OK: Engineering rule present'
        ELSE '⚠️  WARNING: Engineering rule missing or incomplete'
    END as status
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.name = 'ROLLER_MANUAL_STANDARD' 
AND bt.deleted = false 
AND bc.deleted = false
AND bc.component_role = 'idle_end';

-- 3) Show all idle_end and pin components in the template
-- Note: calc_notes may not exist in all schema versions
SELECT 
    bc.sequence_order,
    bc.component_role,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom,
    bc.applies_color,
    bc.auto_select,
    bc.affects_role,
    bc.cut_axis,
    bc.cut_delta_mm,
    bc.cut_delta_scope
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.name = 'ROLLER_MANUAL_STANDARD' 
AND bt.deleted = false 
AND bc.deleted = false
AND bc.component_role IN ('idle_end', 'pin')
ORDER BY bc.sequence_order;

COMMIT;

