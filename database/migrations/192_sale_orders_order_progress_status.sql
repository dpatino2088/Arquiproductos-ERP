-- ====================================================
-- Migration: Add order_progress_status to SaleOrders
-- ====================================================
-- This migration adds order_progress_status field to track order progress
-- driven by manufacturing milestones, without mixing domains.
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '🔧 Adding order_progress_status to SaleOrders';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- STEP 1: Add order_progress_status column
-- ====================================================

DO $$
BEGIN
    -- Check if column already exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders' 
        AND column_name = 'order_progress_status'
    ) THEN
        RAISE NOTICE '⏭️  Column order_progress_status already exists, skipping creation';
    ELSE
        -- Add column with CHECK constraint
        ALTER TABLE "SalesOrders"
        ADD COLUMN order_progress_status text 
        DEFAULT 'approved_awaiting_confirmation'
        CHECK (order_progress_status IN (
            'approved_awaiting_confirmation',
            'confirmed',
            'scheduled',
            'in_production',
            'production_completed',
            'ready_for_delivery',
            'delivered'
        ));
        
        RAISE NOTICE '✅ Added order_progress_status column to SaleOrders';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Backfill existing SaleOrders
-- ====================================================

DO $$
DECLARE
    v_backfilled_count INTEGER;
BEGIN
    -- Set all existing SaleOrders without order_progress_status to 'approved_awaiting_confirmation'
    UPDATE "SalesOrders"
    SET order_progress_status = 'approved_awaiting_confirmation'
    WHERE order_progress_status IS NULL
    AND deleted = false;
    
    GET DIAGNOSTICS v_backfilled_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Backfilled % existing SaleOrder(s) with approved_awaiting_confirmation', v_backfilled_count;
END $$;

-- ====================================================
-- STEP 3: Update on_quote_approved_create_operational_docs function
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_record RECORD;
    v_component_record RECORD;
    v_line_number integer;
    v_subtotal numeric(12,4) := 0;
    v_tax numeric(12,4) := 0;
    v_total numeric(12,4) := 0;
    v_next_counter integer;
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_total_cost_exw numeric(12,4);
    v_category_code text;
    v_item_name text;
    v_validated_side_channel_type text;
    v_qlc_count integer;
    v_bom_result jsonb;
BEGIN
    -- Only process when status transitions to 'approved'
    IF NEW.status != 'approved' THEN
        RETURN NEW;
    END IF;
    
    -- Log trigger execution
    RAISE NOTICE '🔔 Trigger fired: Quote % status changed to approved', NEW.id;
    
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
        -- Tables don't exist yet, skip processing
        RAISE WARNING '⚠️ SaleOrders or SaleOrderLines tables do not exist, skipping operational docs creation';
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
    
    -- Step A: Find or create SaleOrder for this quote
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND organization_id = v_quote_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Generate sale order number
        v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
        v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
        
        -- Extract totals from JSONB
        v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
        v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
        v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
        
        -- Create SaleOrder with order_progress_status = 'approved_awaiting_confirmation'
        INSERT INTO "SalesOrders" (
            organization_id,
            quote_id,
            customer_id,
            sale_order_no,
            status,
            order_progress_status,
            currency,
            subtotal,
            tax,
            total,
            notes,
            order_date,
            created_by,
            updated_by
        ) VALUES (
            v_quote_record.organization_id,
            NEW.id,
            v_quote_record.customer_id,
            v_sale_order_no,
            'draft',
            'approved_awaiting_confirmation',
            COALESCE(v_quote_record.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            v_quote_record.notes,
            CURRENT_DATE,
            NEW.created_by,
            NEW.updated_by
        ) RETURNING id INTO v_sale_order_id;
        
        RAISE NOTICE '✅ Created SaleOrder % with order_progress_status = approved_awaiting_confirmation', v_sale_order_id;
    ELSE
        -- Update existing SaleOrder to ensure order_progress_status is set
        UPDATE "SalesOrders"
        SET order_progress_status = COALESCE(order_progress_status, 'approved_awaiting_confirmation')
        WHERE id = v_sale_order_id
        AND order_progress_status IS NULL;
    END IF;
    
    -- Step B: For each QuoteLine, find or create SaleOrderLine
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
            
            -- Validate and normalize side_channel_type to match constraint
            -- Constraint allows: NULL, 'side_only', 'side_and_bottom'
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSE
                -- Invalid value, set to NULL
                v_validated_side_channel_type := NULL;
                RAISE WARNING '⚠️ Invalid side_channel_type "%" for QuoteLine %, setting to NULL', 
                    v_quote_line_record.side_channel_type, v_quote_line_record.id;
            END IF;
            
            -- Create SaleOrderLine
            INSERT INTO "SalesOrderLines" (
                organization_id,
                sale_order_id,
                quote_line_id,
                catalog_item_id,
                line_number,
                description,
                qty,
                unit_price,
                line_total,
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
                metadata,
                created_by,
                updated_by
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.catalog_item_id,
                v_line_number,
                v_quote_line_record.description,
                v_quote_line_record.qty,
                v_quote_line_record.unit_price_snapshot,
                v_quote_line_record.line_total,
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
                v_quote_line_record.metadata,
                NEW.created_by,
                NEW.updated_by
            ) RETURNING id INTO v_sale_order_line_id;
        END IF;
        
        -- ⭐ NEW: Step C: Generate QuoteLineComponents if they don't exist
        -- Check if QuoteLineComponents exist for this QuoteLine
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_record.id
            AND source = 'configured_component'
            AND deleted = false;
        
        -- If no components exist and we have product_type_id, generate them
        IF v_qlc_count = 0 AND v_quote_line_record.product_type_id IS NOT NULL THEN
            RAISE NOTICE '🔧 No QuoteLineComponents found for QuoteLine %. Generating BOM...', v_quote_line_record.id;
            
            BEGIN
                -- Ensure organization_id is set
                IF v_quote_line_record.organization_id IS NULL THEN
                    UPDATE "QuoteLines"
                    SET organization_id = v_quote_record.organization_id
                    WHERE id = v_quote_line_record.id;
                END IF;
                
                -- Generate QuoteLineComponents using generate_configured_bom_for_quote_line
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
                    v_quote_line_record.qty
                );
                RAISE NOTICE '   ✅ QuoteLineComponents generados para QuoteLine %', v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error generando QuoteLineComponents para QuoteLine %: %', v_quote_line_record.id, SQLERRM;
            END;
        END IF;
        
        -- Step D: Find or create BomInstance for this SaleOrderLine
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND organization_id = v_quote_record.organization_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Create BomInstance
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_id,
                sale_order_line_id,
                quote_line_id,
                bom_template_id,
                status,
                created_by,
                updated_by
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_id,
                v_sale_order_line_id,
                v_quote_line_record.id,
                NULL, -- bom_template_id can be NULL
                'draft',
                NEW.created_by,
                NEW.updated_by
            ) RETURNING id INTO v_bom_instance_id;
        END IF;
        
        -- Step E: Copy QuoteLineComponents to BomInstanceLines
        FOR v_component_record IN
            SELECT 
                qlc.organization_id,
                qlc.catalog_item_id,
                qlc.qty,
                qlc.uom,
                qlc.unit_cost_exw,
                qlc.total_cost_exw,
                qlc.component_role,
                ci.item_name,
                ci.sku
            FROM "QuoteLineComponents" qlc
            LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
        LOOP
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw using get_unit_cost_in_uom
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_component_record.catalog_item_id,
                v_canonical_uom,
                v_quote_record.organization_id
            );
            
            -- Compute total_cost_exw
            v_total_cost_exw := v_unit_cost_exw * v_component_record.qty;
            
            -- Derive category_code from component_role
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Get item_name
            v_item_name := COALESCE(v_component_record.item_name, v_component_record.sku, 'Unknown');
            
            -- Insert or update BomInstanceLine
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
            ) VALUES (
                v_component_record.organization_id,
                v_bom_instance_id,
                v_component_record.catalog_item_id,
                v_component_record.qty,
                v_component_record.uom,
                v_unit_cost_exw,
                v_total_cost_exw,
                COALESCE(v_category_code, 'accessory'),
                v_item_name,
                v_component_record.sku,
                v_component_record.component_role,
                NOW(),
                NOW(),
                false
            )
            ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
            DO UPDATE SET
                qty = EXCLUDED.qty,
                unit_cost_exw = EXCLUDED.unit_cost_exw,
                total_cost_exw = EXCLUDED.total_cost_exw,
                updated_at = NOW(),
                deleted = false;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Operational documents created for Quote %', NEW.id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
'Creates SaleOrder, SaleOrderLines, BomInstances, and BomInstanceLines when a Quote is approved. Sets order_progress_status to approved_awaiting_confirmation for new SaleOrders.';

-- ====================================================
-- STEP 4: Create function to update SaleOrders.order_progress_status from ManufacturingOrders
-- ====================================================

CREATE OR REPLACE FUNCTION public.sync_sale_order_progress_from_manufacturing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_new_status text;
    v_current_status text;
    v_manufacturing_status text;
BEGIN
    -- Get sale_order_id from ManufacturingOrder
    v_sale_order_id := COALESCE(NEW.sale_order_id, OLD.sale_order_id);
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get current order_progress_status
    SELECT order_progress_status INTO v_current_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Determine new status based on ManufacturingOrder changes
    IF TG_OP = 'INSERT' THEN
        -- ManufacturingOrder created -> set to 'scheduled'
        v_new_status := 'scheduled';
        RAISE NOTICE '🔔 ManufacturingOrder % created for SaleOrder %, setting order_progress_status to scheduled', 
            COALESCE(NEW.id, 'unknown'), v_sale_order_id;
    ELSIF TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW' THEN
        -- ManufacturingOrder status changed
        v_manufacturing_status := NEW.status;
        
        IF v_manufacturing_status = 'in_production' THEN
            v_new_status := 'in_production';
            RAISE NOTICE '🔔 ManufacturingOrder % status changed to in_production for SaleOrder %, setting order_progress_status to in_production', 
                NEW.id, v_sale_order_id;
        ELSIF v_manufacturing_status = 'completed' THEN
            v_new_status := 'production_completed';
            RAISE NOTICE '🔔 ManufacturingOrder % status changed to completed for SaleOrder %, setting order_progress_status to production_completed', 
                NEW.id, v_sale_order_id;
        ELSE
            -- No status change needed
            RETURN NEW;
        END IF;
    ELSE
        -- DELETE or other operations - no action needed
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- DO NOT overwrite manual states (ready_for_delivery, delivered)
    -- Allow upgrade from 'confirmed' to 'scheduled' or 'in_production', but don't downgrade
    IF v_current_status IN ('ready_for_delivery', 'delivered') THEN
        RAISE NOTICE '⏭️  SaleOrder % has manual status %, not updating to %', 
            v_sale_order_id, v_current_status, v_new_status;
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Allow upgrade from 'confirmed' to 'scheduled' or 'in_production'
    IF v_current_status = 'confirmed' AND v_new_status IN ('scheduled', 'in_production') THEN
        -- Allow upgrade
        NULL;
    ELSIF v_current_status = 'confirmed' AND v_new_status = 'production_completed' THEN
        -- Allow upgrade to production_completed
        NULL;
    ELSIF v_current_status IN ('scheduled', 'in_production', 'production_completed') AND v_new_status IN ('scheduled', 'in_production', 'production_completed') THEN
        -- Allow progression through manufacturing states
        NULL;
    ELSIF v_current_status = 'approved_awaiting_confirmation' THEN
        -- Always allow update from initial state
        NULL;
    ELSE
        -- Don't update if it would be a downgrade or invalid transition
        RAISE NOTICE '⏭️  Skipping update: SaleOrder % current status % would change to % (invalid transition)', 
            v_sale_order_id, v_current_status, v_new_status;
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Only update if value differs
    IF v_current_status != v_new_status THEN
        UPDATE "SalesOrders"
        SET order_progress_status = v_new_status,
            updated_at = NOW()
        WHERE id = v_sale_order_id
        AND deleted = false;
        
        RAISE NOTICE '✅ Updated SaleOrder % order_progress_status from % to %', 
            v_sale_order_id, v_current_status, v_new_status;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in sync_sale_order_progress_from_manufacturing: %', SQLERRM;
        RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.sync_sale_order_progress_from_manufacturing IS 
'Syncs SaleOrders.order_progress_status from ManufacturingOrders changes. Sets scheduled on INSERT, in_production/production_completed on status updates. Does not overwrite manual states (ready_for_delivery, delivered).';

-- ====================================================
-- STEP 5: Create triggers on ManufacturingOrders
-- ====================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trg_sync_sale_order_progress_on_mo_insert ON "ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_sync_sale_order_progress_on_mo_status_update ON "ManufacturingOrders";

-- Trigger on INSERT: set SaleOrder to 'scheduled'
CREATE TRIGGER trg_sync_sale_order_progress_on_mo_insert
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.sync_sale_order_progress_from_manufacturing();

-- Trigger on UPDATE of status: set SaleOrder to 'in_production' or 'production_completed'
CREATE TRIGGER trg_sync_sale_order_progress_on_mo_status_update
    AFTER UPDATE OF status ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.sync_sale_order_progress_from_manufacturing();

-- ====================================================
-- STEP 6: Add comment to column
-- ====================================================

COMMENT ON COLUMN "SalesOrders".order_progress_status IS 
'Order progress status driven by manufacturing milestones. Values: approved_awaiting_confirmation (default when created from approved quote), confirmed (manual - payment confirmed), scheduled (auto - when ManufacturingOrder created), in_production (auto - when ManufacturingOrder status = in_production), production_completed (auto - when ManufacturingOrder status = completed), ready_for_delivery (manual), delivered (manual).';

-- ====================================================
-- STEP 7: Verification queries (commented - for manual execution)
-- ====================================================

/*
-- Verification Query 1: Verify column exists
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SalesOrders'
AND column_name = 'order_progress_status';

-- Verification Query 2: Show SaleOrders distribution by order_progress_status
SELECT 
    order_progress_status,
    COUNT(*) as count,
    COUNT(*) FILTER (WHERE deleted = false) as active_count,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_count
FROM "SalesOrders"
GROUP BY order_progress_status
ORDER BY count DESC;

-- Verification Query 3: Example test (DO NOT EXECUTE - for reference only)
-- This shows how status propagation would work:
-- 
-- Step 1: Create a test ManufacturingOrder for an existing SaleOrder
-- INSERT INTO "ManufacturingOrders" (
--     organization_id,
--     sale_order_id,
--     manufacturing_order_no,
--     status
-- ) VALUES (
--     'YOUR_ORGANIZATION_ID',
--     'YOUR_SALE_ORDER_ID',
--     'MO-TEST-001',
--     'planned'
-- );
-- -- Expected: SaleOrders.order_progress_status should become 'scheduled'
--
-- Step 2: Update ManufacturingOrder status to 'in_production'
-- UPDATE "ManufacturingOrders"
-- SET status = 'in_production'
-- WHERE id = 'YOUR_MANUFACTURING_ORDER_ID';
-- -- Expected: SaleOrders.order_progress_status should become 'in_production'
--
-- Step 3: Update ManufacturingOrder status to 'completed'
-- UPDATE "ManufacturingOrders"
-- SET status = 'completed'
-- WHERE id = 'YOUR_MANUFACTURING_ORDER_ID';
-- -- Expected: SaleOrders.order_progress_status should become 'production_completed'
*/

-- ====================================================
-- STEP 8: Final summary
-- ====================================================

DO $$
DECLARE
    v_column_exists BOOLEAN;
    v_backfilled_count INTEGER;
BEGIN
    -- Check if column exists
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders' 
        AND column_name = 'order_progress_status'
    ) INTO v_column_exists;
    
    -- Count backfilled records
    SELECT COUNT(*) INTO v_backfilled_count
    FROM "SalesOrders"
    WHERE order_progress_status = 'approved_awaiting_confirmation'
    AND deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '📋 Summary:';
    RAISE NOTICE '   - Column order_progress_status: %', 
        CASE WHEN v_column_exists THEN '✅ Added' ELSE '❌ Failed' END;
    RAISE NOTICE '   - Backfilled SaleOrders: %', v_backfilled_count;
    RAISE NOTICE '   - Function updated: on_quote_approved_create_operational_docs';
    RAISE NOTICE '   - Function created: sync_sale_order_progress_from_manufacturing';
    RAISE NOTICE '   - Triggers created: 2 (INSERT and UPDATE OF status)';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '';
END $$;




