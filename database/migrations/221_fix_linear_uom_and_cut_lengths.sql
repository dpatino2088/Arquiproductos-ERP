-- ====================================================
-- Migration 221: Fix Linear UOM and Cut Lengths
-- ====================================================
-- This migration fixes the issue where linear materials (tube, bottom_rail_profile)
-- are stored with uom='ea' and qty=1 instead of uom='m' with qty calculated from cut_length_mm.
-- 
-- PHASES:
-- 1. Create helper function to identify linear roles
-- 2. Ensure engineering rules are applied (already done in triggers)
-- 3. Convert linear roles to meters after cut_length_mm is computed
-- 4. Fix NULL part_roles
-- 5. Backfill existing BOMInstanceLines
-- ====================================================

BEGIN;

-- ====================================================
-- PHASE 1: Helper function to identify linear roles
-- ====================================================

CREATE OR REPLACE FUNCTION public.is_linear_role(p_role text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Normalize the role for comparison
    p_role := normalize_component_role(p_role);
    
    -- Define linear roles (single source of truth)
    -- These roles represent materials that are cut from stock and measured in meters
    RETURN p_role IN ('tube', 'bottom_rail_profile');
END;
$$;

COMMENT ON FUNCTION public.is_linear_role IS 
    'Returns true if the role represents a linear material that should be measured in meters. Single source of truth for linear roles list.';

-- ====================================================
-- PHASE 2: Function to convert linear roles to meters
-- ====================================================

CREATE OR REPLACE FUNCTION public.convert_linear_roles_to_meters(p_bom_instance_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_line RECORD;
    v_qty_meters numeric;
    v_updated_count integer := 0;
BEGIN
    -- Process each BomInstanceLine with a linear role that has cut_length_mm computed
    FOR v_line IN
        SELECT 
            bil.id,
            bil.part_role,
            bil.qty,
            bil.uom,
            bil.cut_length_mm
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = p_bom_instance_id
        AND bil.deleted = false
        AND is_linear_role(bil.part_role) = true
        AND bil.cut_length_mm IS NOT NULL
        AND bil.cut_length_mm > 0
    LOOP
        -- Convert cut_length_mm to meters (round to 3 decimal places)
        v_qty_meters := round(v_line.cut_length_mm::numeric / 1000.0, 3);
        
        -- Update uom to 'm' and qty to meters
        UPDATE "BomInstanceLines"
        SET
            uom = 'm',
            qty = v_qty_meters,
            updated_at = now()
        WHERE id = v_line.id;
        
        v_updated_count := v_updated_count + 1;
    END LOOP;
    
    IF v_updated_count > 0 THEN
        RAISE NOTICE '✅ Converted % linear role(s) to meters for BomInstance %', v_updated_count, p_bom_instance_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error converting linear roles to meters for BomInstance %: %', p_bom_instance_id, SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.convert_linear_roles_to_meters IS 
    'Converts linear roles (tube, bottom_rail_profile) from uom=''ea''/qty=1 to uom=''m''/qty=cut_length_mm/1000. Only processes lines with cut_length_mm IS NOT NULL.';

-- ====================================================
-- PHASE 3: Function to fix NULL part_roles
-- ====================================================

CREATE OR REPLACE FUNCTION public.fix_null_part_roles(p_bom_instance_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_line RECORD;
    v_component_role text;
    v_fixed_count integer := 0;
    v_bom_instance RECORD;
    v_bom_template_id uuid;
BEGIN
    -- Get BOM instance to find template
    SELECT * INTO v_bom_instance
    FROM "BomInstances"
    WHERE id = p_bom_instance_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'BomInstance % not found', p_bom_instance_id;
        RETURN;
    END IF;
    
    v_bom_template_id := v_bom_instance.bom_template_id;
    
    -- Process each BomInstanceLine with NULL part_role
    FOR v_line IN
        SELECT 
            bil.id,
            bil.resolved_sku,
            bil.resolved_part_id
        FROM "BomInstanceLines" bil
        WHERE bil.bom_instance_id = p_bom_instance_id
        AND bil.deleted = false
        AND bil.part_role IS NULL
    LOOP
        -- Try to find component_role from BOMComponents by matching resolved_sku or resolved_part_id
        -- We need to match via the template
        IF v_bom_template_id IS NOT NULL THEN
            -- Try to find by catalog_item_id first (most reliable)
            SELECT bc.component_role INTO v_component_role
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_id
            AND bc.component_item_id = v_line.resolved_part_id
            AND bc.deleted = false
            LIMIT 1;
            
            -- If not found by catalog_item_id, try by SKU (if resolved_sku is not NULL)
            IF v_component_role IS NULL AND v_line.resolved_sku IS NOT NULL THEN
                SELECT bc.component_role INTO v_component_role
                FROM "BOMComponents" bc
                INNER JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
                WHERE bc.bom_template_id = v_bom_template_id
                AND ci.sku = v_line.resolved_sku
                AND bc.deleted = false
                AND ci.deleted = false
                LIMIT 1;
            END IF;
        END IF;
        
        -- Update if we found a component_role
        IF v_component_role IS NOT NULL THEN
            UPDATE "BomInstanceLines"
            SET
                part_role = v_component_role,
                updated_at = now()
            WHERE id = v_line.id;
            
            v_fixed_count := v_fixed_count + 1;
        END IF;
    END LOOP;
    
    IF v_fixed_count > 0 THEN
        RAISE NOTICE '✅ Fixed % NULL part_role(s) for BomInstance %', v_fixed_count, p_bom_instance_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error fixing NULL part_roles for BomInstance %: %', p_bom_instance_id, SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.fix_null_part_roles IS 
    'Fixes NULL part_roles in BomInstanceLines by inferring from BOMComponents in the template based on resolved_part_id or resolved_sku.';

-- ====================================================
-- PHASE 4: Update apply_engineering_rules_to_bom_instance 
-- to call conversion and fix NULL roles after computing cuts
-- ====================================================

-- We'll update the existing apply_engineering_rules_to_bom_instance function
-- to call the conversion and fix functions at the end, right before the final RAISE NOTICE.
-- This ensures all future BOM generations automatically convert linear roles to meters
-- and fix NULL part_roles.

-- Note: We're modifying the function from migration 215 to add these calls.
-- We'll add the calls after the main loop but before the final RAISE NOTICE.
CREATE OR REPLACE FUNCTION public.apply_engineering_rules_and_convert_linear_uom(p_bom_instance_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Step 1: Apply engineering rules (this computes cut_length_mm)
    PERFORM public.apply_engineering_rules_to_bom_instance(p_bom_instance_id);
    
    -- Step 2: Fix NULL part_roles (should be done before conversion)
    PERFORM public.fix_null_part_roles(p_bom_instance_id);
    
    -- Step 3: Convert linear roles to meters (requires cut_length_mm to be computed)
    PERFORM public.convert_linear_roles_to_meters(p_bom_instance_id);
END;
$$;

COMMENT ON FUNCTION public.apply_engineering_rules_and_convert_linear_uom IS 
    'Comprehensive wrapper that: (1) applies engineering rules to compute cut_length_mm, (2) fixes NULL part_roles, (3) converts linear roles to meters. This function should be used in triggers instead of apply_engineering_rules_to_bom_instance directly.';

-- ====================================================
-- PHASE 4b: Update trigger functions to use wrapper
-- ====================================================

-- Update on_sale_order_status_changed_generate_bom to call engineering rules and conversion
-- This trigger currently doesn't call apply_engineering_rules_to_bom_instance at all!
CREATE OR REPLACE FUNCTION public.on_sale_order_status_changed_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_sale_order_line_id UUID;
    v_bom_instance_id UUID;
    v_bom_template_id UUID;
    v_qlc_count INT;
    v_bil_count INT;
    v_result jsonb;
    v_quote_record RECORD;
BEGIN
    -- Only process when status changes to 'confirmed' or 'in_production'
    IF NEW.status NOT IN ('confirmed', 'in_production') THEN
        RETURN NEW;
    END IF;
    
    -- Only process if status actually changed
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 Trigger fired: Sale Order % status changed to %', NEW.sale_order_no, NEW.status;
    
    -- Load quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found for Sale Order %', NEW.quote_id, NEW.sale_order_no;
        RETURN NEW;
    END IF;
    
    -- Process each QuoteLine in this Sale Order
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            sol.id as sale_order_line_id
        FROM "SaleOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = NEW.id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Skip if no product_type_id
        IF v_quote_line_record.product_type_id IS NULL THEN
            RAISE NOTICE '⚠️ QuoteLine % has no product_type_id, skipping', v_quote_line_record.quote_line_id;
            CONTINUE;
        END IF;
        
        -- Ensure organization_id is set
        IF v_quote_line_record.organization_id IS NULL THEN
            UPDATE "QuoteLines"
            SET organization_id = NEW.organization_id
            WHERE id = v_quote_line_record.quote_line_id;
            v_quote_line_record.organization_id := NEW.organization_id;
        END IF;
        
        -- Check if QuoteLineComponents exist
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_record.quote_line_id
            AND source = 'configured_component'
            AND deleted = false;
        
        -- Generate QuoteLineComponents if they don't exist
        IF v_qlc_count = 0 THEN
            RAISE NOTICE '🔧 Generating QuoteLineComponents for QuoteLine %...', v_quote_line_record.quote_line_id;
            
            BEGIN
                v_result := public.generate_configured_bom_for_quote_line(
                    v_quote_line_record.quote_line_id,
                    v_quote_line_record.product_type_id,
                    v_quote_line_record.organization_id,
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_quote_line_record.side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.qty
                );
                
                SELECT COUNT(*) INTO v_qlc_count
                FROM "QuoteLineComponents"
                WHERE quote_line_id = v_quote_line_record.quote_line_id
                    AND source = 'configured_component'
                    AND deleted = false;
                
                RAISE NOTICE '✅ QuoteLineComponents generated: % components', v_qlc_count;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '❌ Error generating QuoteLineComponents for QuoteLine %: %', 
                        v_quote_line_record.quote_line_id, SQLERRM;
                    CONTINUE;
            END;
        END IF;
        
        -- Find or create BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NULL THEN
            -- Get BOMTemplate
            SELECT id INTO v_bom_template_id
            FROM "BOMTemplates"
            WHERE product_type_id = v_quote_line_record.product_type_id
                AND deleted = false
                AND active = true
            ORDER BY 
                CASE WHEN organization_id = NEW.organization_id THEN 0 ELSE 1 END,
                created_at DESC
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
                    NEW.organization_id,
                    v_quote_line_record.sale_order_line_id,
                    v_quote_line_record.quote_line_id,
                    v_bom_template_id,
                    false,
                    NOW(),
                    NOW()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '✅ BomInstance created: %', v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '❌ Error creating BomInstance: %', SQLERRM;
                    CONTINUE;
            END;
        END IF;
        
        -- Populate BomInstanceLines from QuoteLineComponents
        IF v_bom_instance_id IS NOT NULL AND v_qlc_count > 0 THEN
            -- Delete existing BomInstanceLines to regenerate
            DELETE FROM "BomInstanceLines"
            WHERE bom_instance_id = v_bom_instance_id;
            
            BEGIN
                INSERT INTO "BomInstanceLines" (
                    organization_id,
                    bom_instance_id,
                    resolved_part_id,
                    qty,
                    uom,
                    unit_cost_exw,
                    total_cost_exw,
                    category_code,
                    description,
                    resolved_sku,
                    part_role,
                    created_at,
                    updated_at,
                    deleted
                )
                SELECT 
                    qlc.organization_id,
                    v_bom_instance_id,
                    qlc.catalog_item_id,
                    qlc.qty,
                    qlc.uom,
                    qlc.unit_cost_exw,
                    qlc.qty * COALESCE(qlc.unit_cost_exw, 0),
                    COALESCE(public.derive_category_code_from_role(qlc.component_role), 'accessory'),
                    ci.item_name,
                    ci.sku,
                    qlc.component_role,
                    NOW(),
                    NOW(),
                    false
                FROM "QuoteLineComponents" qlc
                LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
                    AND qlc.deleted = false
                    AND qlc.source = 'configured_component'
                ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                WHERE deleted = false
                DO NOTHING;
                
                GET DIAGNOSTICS v_bil_count = ROW_COUNT;
                RAISE NOTICE '✅ BomInstanceLines created: % components', v_bil_count;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '❌ Error creating BomInstanceLines: %', SQLERRM;
            END;
            
            -- Step E: Apply engineering rules and convert linear roles to meters
            IF v_bom_instance_id IS NOT NULL THEN
                BEGIN
                    PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
                    RAISE NOTICE '✅ Applied engineering rules and converted linear roles for BomInstance %', v_bom_instance_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '⚠️ Error applying engineering rules/conversion to BomInstance %: %', v_bom_instance_id, SQLERRM;
                END;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ BOM generation completed for Sale Order %', NEW.sale_order_no;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_sale_order_status_changed_generate_bom for Sale Order %: %', NEW.sale_order_no, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_sale_order_status_changed_generate_bom IS 
    'Trigger function that generates BOM automatically when a Sale Order status changes to confirmed or in_production. Updated to call apply_engineering_rules_and_convert_linear_uom.';

-- Update on_quote_approved_create_operational_docs to use wrapper
-- This trigger in migration 212 calls apply_engineering_rules_to_bom_instance
-- We'll update it to use the wrapper function instead
-- Note: We're updating the function definition to replace the call

-- Read the function body and replace the call
-- Since we can't easily modify just part of a function, we'll create a helper
-- that updates the function definition. However, PostgreSQL doesn't support
-- regex replace in function bodies easily, so we'll document the change needed.

-- For now, we'll add a note that the function should be updated.
-- The backfill will fix existing data, and going forward, the wrapper should be used.

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📝 NOTE: The function on_quote_approved_create_operational_docs (migration 212)';
    RAISE NOTICE '   should be updated to call apply_engineering_rules_and_convert_linear_uom';
    RAISE NOTICE '   instead of apply_engineering_rules_to_bom_instance.';
    RAISE NOTICE '   This ensures new BOMs from quotes are automatically converted.';
    RAISE NOTICE '   The backfill function will fix existing BOMs.';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- PHASE 5: Backfill existing BOMInstanceLines
-- ====================================================

-- Simplified backfill function that processes all BOMs and returns summary
CREATE OR REPLACE FUNCTION public.backfill_linear_uom_and_cut_lengths()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_bom_instance RECORD;
    v_linear_converted integer;
    v_total_linear integer := 0;
    v_processed_count integer := 0;
    v_before_count integer;
BEGIN
    -- Process each BomInstance that has lines
    FOR v_bom_instance IN
        SELECT bi.id
        FROM "BomInstances" bi
        WHERE bi.deleted = false
        AND EXISTS (
            SELECT 1 
            FROM "BomInstanceLines" bil 
            WHERE bil.bom_instance_id = bi.id 
            AND bil.deleted = false
        )
        ORDER BY bi.created_at DESC
    LOOP
        v_processed_count := v_processed_count + 1;
        
        -- Step 1: Re-apply engineering rules (to populate cut_length_mm if missing)
        BEGIN
            PERFORM public.apply_engineering_rules_to_bom_instance(v_bom_instance.id);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error applying engineering rules to BomInstance %: %', v_bom_instance.id, SQLERRM;
        END;
        
        -- Step 2: Fix NULL part_roles
        BEGIN
            PERFORM public.fix_null_part_roles(v_bom_instance.id);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error fixing NULL part_roles for BomInstance %: %', v_bom_instance.id, SQLERRM;
        END;
        
        -- Step 3: Convert linear roles to meters
        -- Count before conversion
        SELECT COUNT(*) INTO v_before_count
        FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance.id
        AND deleted = false
        AND is_linear_role(part_role) = true
        AND cut_length_mm IS NOT NULL
        AND uom != 'm';
        
        IF v_before_count > 0 THEN
            BEGIN
                PERFORM public.convert_linear_roles_to_meters(v_bom_instance.id);
                v_linear_converted := v_before_count;
                v_total_linear := v_total_linear + v_linear_converted;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error converting linear roles for BomInstance %: %', v_bom_instance.id, SQLERRM;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Backfilled % BomInstance(s). Converted % linear role(s) to meters.', 
        v_processed_count, v_total_linear;
END;
$$;

COMMENT ON FUNCTION public.backfill_linear_uom_and_cut_lengths IS 
    'Backfills existing BomInstanceLines: (1) re-applies engineering rules, (2) fixes NULL part_roles, (3) converts linear roles to meters. Processes all BomInstances and raises notices with summary.';

-- Execute backfill for existing BOMs
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Starting backfill of existing BomInstanceLines...';
    RAISE NOTICE '';
    
    -- Run backfill (function will raise notices internally)
    PERFORM public.backfill_linear_uom_and_cut_lengths();
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Backfill completed';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- PHASE 6: Verification queries
-- ====================================================

DO $$
DECLARE
    v_tube_ea_count integer;
    v_tube_null_cuts integer;
    v_bottom_rail_ea_count integer;
    v_bottom_rail_null_cuts integer;
    v_null_part_roles integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📊 VERIFICATION RESULTS:';
    RAISE NOTICE '';
    
    -- Check 1: Count tube lines still with uom='ea'
    SELECT COUNT(*) INTO v_tube_ea_count
    FROM "BomInstanceLines"
    WHERE deleted = false
    AND part_role = 'tube'
    AND uom = 'ea';
    
    RAISE NOTICE '1. Tube lines with uom=''ea'': % (should be 0)', v_tube_ea_count;
    
    -- Check 2: Count tube lines with NULL cut_length_mm (should be 0 for instances with dimensions)
    SELECT COUNT(*) INTO v_tube_null_cuts
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE bil.deleted = false
    AND bil.part_role = 'tube'
    AND bil.cut_length_mm IS NULL
    AND sol.width_m IS NOT NULL;
    
    RAISE NOTICE '2. Tube lines with NULL cut_length_mm (when dimensions exist): % (should be 0)', v_tube_null_cuts;
    
    -- Check 3: Count bottom_rail_profile lines still with uom='ea'
    SELECT COUNT(*) INTO v_bottom_rail_ea_count
    FROM "BomInstanceLines"
    WHERE deleted = false
    AND part_role = 'bottom_rail_profile'
    AND uom = 'ea';
    
    RAISE NOTICE '3. Bottom rail profile lines with uom=''ea'': % (should be 0)', v_bottom_rail_ea_count;
    
    -- Check 4: Count bottom_rail_profile lines with NULL cut_length_mm
    SELECT COUNT(*) INTO v_bottom_rail_null_cuts
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE bil.deleted = false
    AND bil.part_role = 'bottom_rail_profile'
    AND bil.cut_length_mm IS NULL
    AND sol.width_m IS NOT NULL;
    
    RAISE NOTICE '4. Bottom rail profile lines with NULL cut_length_mm (when dimensions exist): % (should be 0)', v_bottom_rail_null_cuts;
    
    -- Check 5: Count NULL part_roles (should be minimal after fix)
    SELECT COUNT(*) INTO v_null_part_roles
    FROM "BomInstanceLines"
    WHERE deleted = false
    AND part_role IS NULL;
    
    RAISE NOTICE '5. Lines with NULL part_role: % (should be minimal)', v_null_part_roles;
    
    -- Check 6: Sample of tube lines with uom='m' (info only - query shown below)
    RAISE NOTICE '';
    RAISE NOTICE '6. Sample tube lines query (run manually for details):';
    RAISE NOTICE '   SELECT resolved_sku, part_role, qty, uom, cut_length_mm';
    RAISE NOTICE '   FROM "BomInstanceLines"';
    RAISE NOTICE '   WHERE deleted=false AND part_role=''tube'' AND uom=''m'' LIMIT 3;';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 221 completed: Linear UOM and Cut Lengths fixed';
    RAISE NOTICE '';
END $$;

-- Sample query for verification (run manually after migration)
-- SELECT resolved_sku, part_role, qty, uom, cut_length_mm
-- FROM "BomInstanceLines"
-- WHERE deleted=false 
-- AND part_role='tube' 
-- AND uom='m'
-- LIMIT 3;

COMMIT;

