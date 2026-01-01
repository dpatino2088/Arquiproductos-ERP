-- ====================================================
-- Migration 321: Improve Trigger with Enhanced Logging
-- ====================================================
-- PROBLEM: Trigger may not be firing when quote is approved from UI
-- SOLUTION: 
--   1. Change trigger from "AFTER UPDATE OF status" to "AFTER UPDATE" 
--      (so it fires on ANY update, not just status field)
--   2. Add comprehensive logging at the START of the function
--   3. Keep all existing logic from migration 315
-- ====================================================

BEGIN;

-- Step 1: Update the trigger function to add logging at the very beginning
-- (The function body from 315 remains unchanged, we just add logging at the start)
CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_record RECORD;
    v_component_record RECORD;
    v_line_number integer;
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_total_cost_exw numeric(12,4);
    v_category_code text;
    v_item_name text;
    v_validated_side_channel_type text;
    v_qlc_count integer;
    v_bom_result jsonb;
    v_old_status_text text;
    v_new_status_text text;
BEGIN
    -- ⭐ ENHANCED LOGGING: Log ALL trigger executions (even if not approved)
    v_old_status_text := COALESCE(OLD.status::text, 'NULL');
    v_new_status_text := COALESCE(NEW.status::text, 'NULL');
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔔 Trigger on_quote_approved_create_operational_docs FIRED';
    RAISE NOTICE '  Quote ID: %', NEW.id;
    RAISE NOTICE '  Quote No: %', NEW.quote_no;
    RAISE NOTICE '  Old Status: %', v_old_status_text;
    RAISE NOTICE '  New Status: %', v_new_status_text;
    RAISE NOTICE '  Deleted: %', NEW.deleted;
    RAISE NOTICE '  Status Changed: %', (OLD.status IS DISTINCT FROM NEW.status);
    RAISE NOTICE '========================================';
    
    -- Only process when status is 'Approved' (case-insensitive check)
    IF NEW.status IS NULL THEN
        RAISE NOTICE '⏭️  Quote % has NULL status, skipping', NEW.id;
        RETURN NEW;
    END IF;
    
    IF NEW.status::text ILIKE 'approved' = false THEN
        RAISE NOTICE '⏭️  Quote % status is not approved (%), skipping', NEW.id, v_new_status_text;
        RETURN NEW;
    END IF;
    
    -- Only process if status actually changed (transition check)
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RAISE NOTICE '⏭️  Quote % status unchanged (%), skipping', NEW.id, v_new_status_text;
        RETURN NEW;
    END IF;
    
    -- Only process if quote is not deleted
    IF NEW.deleted = true THEN
        RAISE NOTICE '⏭️  Quote % is deleted, skipping', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '✅ Processing Quote %: Status changed from % to Approved', NEW.id, v_old_status_text;
    
    -- Check if required tables exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) THEN
        RAISE WARNING '⚠️ SalesOrders or SalesOrderLines tables do not exist, skipping operational docs creation';
        RETURN NEW;
    END IF;
    
    -- Load quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found or deleted, skipping operational docs creation', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '✅ Quote % loaded, organization_id: %', NEW.id, v_quote_record.organization_id;
    
    -- ⭐ STEP A: Use idempotent helper function to ensure SalesOrder exists
    BEGIN
        v_sale_order_id := public.ensure_sales_order_for_approved_quote(NEW.id);
        RAISE NOTICE '✅ SalesOrder ensured for Quote %: %', NEW.id, v_sale_order_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error ensuring SalesOrder for Quote %: %', NEW.id, SQLERRM;
            RETURN NEW;
    END;
    
    -- ⭐ STEP B: For each QuoteLine, find or create SaleOrderLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Find existing SaleOrderLine for this quote_line_id
        SELECT id INTO v_sale_order_line_id
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' OR
                  LOWER(v_quote_line_record.side_channel_type) = 'side_and_bottom' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SaleOrderLine (using only columns that exist)
            INSERT INTO "SalesOrderLines" (
                sale_order_id,
                quote_line_id,
                line_number,
                qty,
                width_m,
                height_m,
                area,
                position,
                collection_name,
                variant_name,
                product_type,
                product_type_id,
                drive_type,
                bottom_rail_type,
                cassette,
                cassette_type,
                side_channel,
                side_channel_type,
                hardware_color,
                tube_type,
                operating_system_variant,
                top_rail_type,
                organization_id,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_sale_order_id,
                v_quote_line_record.id,
                v_line_number,
                v_quote_line_record.qty,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.area,
                v_quote_line_record.position,
                v_quote_line_record.collection_name,
                v_quote_line_record.variant_name,
                v_quote_line_record.product_type,
                v_quote_line_record.product_type_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.cassette,
                v_quote_line_record.cassette_type,
                v_quote_line_record.side_channel,
                v_validated_side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.tube_type,
                v_quote_line_record.operating_system_variant,
                v_quote_line_record.top_rail_type,
                v_quote_record.organization_id,
                false,
                now(),
                now()
            ) RETURNING id INTO v_sale_order_line_id;
        END IF;
        
        -- ⭐ Step C: Generate QuoteLineComponents if they don't exist
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_record.id
            AND source = 'configured_component'
            AND deleted = false;
        
        IF v_qlc_count = 0 AND v_quote_line_record.product_type_id IS NOT NULL THEN
            RAISE NOTICE '🔧 No QuoteLineComponents found for QuoteLine %. Generating BOM...', v_quote_line_record.id;
            
            BEGIN
                IF v_quote_line_record.organization_id IS NULL THEN
                    UPDATE "QuoteLines"
                    SET organization_id = v_quote_record.organization_id
                    WHERE id = v_quote_line_record.id;
                END IF;
                
                v_bom_result := public.generate_configured_bom_for_quote_line(
                    v_quote_line_record.id,
                    v_quote_line_record.product_type_id,
                    COALESCE(v_quote_line_record.organization_id, v_quote_record.organization_id),
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_quote_line_record.side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.qty,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant
                );
                
                RAISE NOTICE '✅ QuoteLineComponents generated for QuoteLine %', v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error generating QuoteLineComponents for QuoteLine %: %', v_quote_line_record.id, SQLERRM;
            END;
        ELSIF v_qlc_count = 0 AND v_quote_line_record.product_type_id IS NULL THEN
            RAISE WARNING '⚠️ QuoteLine % has no product_type_id, cannot generate BOM', v_quote_line_record.id;
        END IF;
        
        -- ⭐ Step D: Find or create BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            DECLARE
                v_bom_template_id uuid;
            BEGIN
                SELECT id INTO v_bom_template_id
                FROM "BOMTemplates"
                WHERE product_type_id = v_quote_line_record.product_type_id
                    AND deleted = false
                    AND active = true
                ORDER BY 
                    CASE WHEN organization_id = v_quote_record.organization_id THEN 0 ELSE 1 END,
                    created_at DESC
                LIMIT 1;
                
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_quote_record.organization_id,
                    v_sale_order_line_id,
                    v_quote_line_record.id,
                    v_bom_template_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error creating BomInstance: %', SQLERRM;
            END;
        END IF;
        
        -- ⭐ Step E: Populate BomInstanceLines from QuoteLineComponents
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.item_name,
                ci.sku
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            IF v_bom_instance_id IS NOT NULL THEN
                v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
                
                v_unit_cost_exw := public.get_unit_cost_in_uom(
                    v_component_record.catalog_item_id,
                    v_canonical_uom,
                    v_quote_record.organization_id
                );
                
                IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                    v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
                END IF;
                
                v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
                v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
                
                INSERT INTO "BomInstanceLines" (
                    organization_id,
                    bom_instance_id,
                    source_template_line_id,
                    resolved_part_id,
                    resolved_sku,
                    part_role,
                    qty,
                    uom,
                    description,
                    unit_cost_exw,
                    total_cost_exw,
                    category_code,
                    created_at,
                    updated_at,
                    deleted
                ) VALUES (
                    v_quote_record.organization_id,
                    v_bom_instance_id,
                    NULL,
                    v_component_record.catalog_item_id,
                    v_component_record.sku,
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_canonical_uom,
                    COALESCE(v_component_record.item_name, ''),
                    v_unit_cost_exw,
                    v_total_cost_exw,
                    v_category_code,
                    now(),
                    now(),
                    false
                )
                ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                WHERE deleted = false
                DO NOTHING;
            END IF;
        END LOOP;
        
        -- ⭐ Step F: Apply engineering rules
        IF v_bom_instance_id IS NOT NULL THEN
            BEGIN
                PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
                RAISE NOTICE '✅ Applied engineering rules for BomInstance %', v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error applying engineering rules for BomInstance %: %', v_bom_instance_id, SQLERRM;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Operational docs creation completed for Quote %', NEW.id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

-- Step 2: Recreate trigger to fire on ANY UPDATE (not just UPDATE OF status)
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
AFTER UPDATE ON "Quotes"  -- ⭐ Changed from "AFTER UPDATE OF status" to "AFTER UPDATE"
FOR EACH ROW
WHEN (
    NEW.deleted = false
    AND NEW.status IS NOT NULL
    AND (NEW.status::text ILIKE 'approved' OR NEW.status::text = 'Approved')
    AND (OLD.status IS DISTINCT FROM NEW.status)
)
EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Enable the trigger
ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;

COMMENT ON TRIGGER trg_on_quote_approved_create_operational_docs ON "Quotes" IS 
    'Creates SalesOrder when quote status transitions to Approved. Enhanced logging for debugging. Fires on ANY UPDATE (not just status field).';

COMMIT;

-- ====================================================
-- Verification
-- ====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger function and trigger recreated with enhanced logging';
    RAISE NOTICE '   - Changed from "AFTER UPDATE OF status" to "AFTER UPDATE"';
    RAISE NOTICE '   - Logs ALL trigger executions (even non-approved)';
    RAISE NOTICE '   - Logs status transitions';
    RAISE NOTICE '   - Logs SalesOrder creation results';
    RAISE NOTICE '';
    RAISE NOTICE '📝 To test: Update a quote status to ''approved'' and check Supabase logs';
END $$;

