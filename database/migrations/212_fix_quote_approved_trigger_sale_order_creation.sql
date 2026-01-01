-- ====================================================
-- Migration: Fix Quote Approved Trigger - Ensure Sale Orders are Created
-- ====================================================
-- Fixes the trigger to properly create Sales Orders with improved error handling
-- Uses the COMPLETE function from migration 203 but with better number generation fallback
-- ====================================================

-- Update the trigger function - COMPLETE version from migration 203 with improved error handling
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
    v_bom_line_id uuid;
    v_last_order_no text;
BEGIN
    -- Only process when status transitions to 'approved'
    IF NEW.status != 'approved' THEN
        RETURN NEW;
    END IF;
    
    -- Prevent duplicate processing
    IF OLD.status = 'approved' THEN
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
    
    -- Step A: Find or create SaleOrder for this quote
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND organization_id = v_quote_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Generate sale order number with IMPROVED fallback logic
        BEGIN
            -- Try get_next_counter_value first (preferred method)
            IF EXISTS (
                SELECT 1 FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE n.nspname = 'public'
                AND p.proname = 'get_next_counter_value'
            ) THEN
                BEGIN
                    v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
                    v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
                    RAISE NOTICE '✅ Generated sale_order_no using get_next_counter_value: %', v_sale_order_no;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '⚠️ get_next_counter_value failed: %, using fallback', SQLERRM;
                        v_next_counter := NULL; -- Will trigger fallback
                END;
            END IF;
            
            -- Fallback: manual generation if get_next_counter_value doesn't exist or failed
            IF v_sale_order_no IS NULL OR v_next_counter IS NULL THEN
                SELECT sale_order_no INTO v_last_order_no
                FROM "SalesOrders"
                WHERE organization_id = v_quote_record.organization_id
                AND deleted = false
                ORDER BY created_at DESC
                LIMIT 1;

                IF v_last_order_no IS NULL THEN
                    v_next_counter := 1;
                ELSE
                    -- Extract number from format SO-000001
                    v_next_counter := COALESCE(
                        (SELECT (regexp_match(v_last_order_no, 'SO-(\d+)'))[1]::integer),
                        0
                    ) + 1;
                END IF;

                v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
                RAISE NOTICE '✅ Generated sale_order_no using fallback method: %', v_sale_order_no;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error generating sale_order_no: %, using timestamp fallback', SQLERRM;
                -- Last resort: timestamp-based number
                v_sale_order_no := 'SO-' || LPAD((EXTRACT(EPOCH FROM NOW())::bigint % 1000000)::text, 6, '0');
        END;
        
        -- Extract totals from JSONB
        v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
        v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
        v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
        
        -- Create SaleOrder - using schema from migration 203 (with deleted, created_at, updated_at)
        BEGIN
            INSERT INTO "SalesOrders" (
                organization_id,
                quote_id,
                customer_id,
                sale_order_no,
                status,
                currency,
                subtotal,
                tax,
                total,
                notes,
                created_at,
                updated_at,
                deleted
            ) VALUES (
                v_quote_record.organization_id,
                NEW.id,
                v_quote_record.customer_id,
                v_sale_order_no,
                'draft',
                COALESCE(v_quote_record.currency, 'USD'),
                v_subtotal,
                v_tax,
                v_total,
                v_quote_record.notes,
                now(),
                now(),
                false
            ) RETURNING id INTO v_sale_order_id;
            
            RAISE NOTICE '✅ Created SaleOrder % (%) for Quote %', v_sale_order_no, v_sale_order_id, NEW.id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error creating SaleOrder: %', SQLERRM;
                RAISE WARNING '❌ SQLSTATE: %', SQLSTATE;
                -- Don't re-raise - allow quote update to succeed
                RETURN NEW;
        END;
    ELSE
        RAISE NOTICE '⏭️  SaleOrder already exists for Quote %', NEW.id;
    END IF;
    
    -- Step B: Process each QuoteLine (from migration 203)
    FOR v_quote_line_record IN
        SELECT * FROM "QuoteLines"
        WHERE quote_id = NEW.id
        AND deleted = false
        ORDER BY line_number, created_at
    LOOP
        -- Find or create SaleOrderLine
        SELECT id INTO v_sale_order_line_id
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Validate side_channel_type
            v_validated_side_channel_type := NULL;
            IF v_quote_line_record.side_channel THEN
                IF v_quote_line_record.side_channel_type IN ('left', 'right', 'both') THEN
                    v_validated_side_channel_type := v_quote_line_record.side_channel_type;
                ELSE
                    v_validated_side_channel_type := 'both';
                END IF;
            END IF;
            
            -- Create SaleOrderLine
            INSERT INTO "SalesOrderLines" (
                sale_order_id,
                quote_line_id,
                line_number,
                catalog_item_id,
                item_name,
                sku,
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
                created_by,
                updated_by
            ) VALUES (
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.line_number,
                v_quote_line_record.catalog_item_id,
                v_quote_line_record.item_name,
                v_quote_line_record.sku,
                v_quote_line_record.qty,
                v_quote_line_record.unit_price,
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
                COALESCE(v_quote_line_record.cassette, false),
                v_quote_line_record.cassette_type,
                COALESCE(v_quote_line_record.side_channel, false),
                v_validated_side_channel_type,
                v_quote_line_record.hardware_color,
                NEW.created_by,
                NEW.updated_by
            ) RETURNING id INTO v_sale_order_line_id;
        END IF;
        
        -- Step C: Find or create BomInstance for this sale_order_line_id
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                configured_product_id,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_line_id,
                v_quote_line_record.id,
                NULL,
                'locked',
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
        END IF;
        
        -- Step D: Populate BomInstanceLines from QuoteLineComponents (frozen snapshot)
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw using get_unit_cost_in_uom
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_component_record.catalog_item_id,
                v_canonical_uom,
                v_quote_record.organization_id
            );
            
            -- If unit_cost_exw is NULL or 0, try to use the stored unit_cost_exw from QuoteLineComponents
            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
            END IF;
            
            -- Calculate total_cost_exw
            v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
            
            -- Derive category_code from component_role
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Insert BomInstanceLine with ON CONFLICT DO NOTHING (frozen first insert)
            INSERT INTO "BomInstanceLines" (
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
                v_bom_instance_id,
                NULL,
                v_component_record.catalog_item_id,
                NULL,
                v_component_record.component_role,
                v_component_record.qty,
                v_canonical_uom,
                v_component_record.item_name,
                v_unit_cost_exw,
                v_total_cost_exw,
                v_category_code,
                now(),
                now(),
                false
            )
            ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
            WHERE deleted = false
            DO NOTHING
            RETURNING id INTO v_bom_line_id;
            
            -- If line was inserted (not conflicted), populate base/pricing fields
            IF v_bom_line_id IS NOT NULL THEN
                PERFORM public.populate_bom_line_base_pricing_fields(
                    v_bom_line_id,
                    v_component_record.catalog_item_id,
                    v_component_record.qty,
                    v_component_record.uom,
                    v_component_record.component_role,
                    v_quote_record.organization_id
                );
            END IF;
        END LOOP;
        
        -- Step E: Apply engineering rules to compute cut dimensions
        IF v_bom_instance_id IS NOT NULL THEN
            BEGIN
                PERFORM public.apply_engineering_rules_to_bom_instance(v_bom_instance_id);
                RAISE NOTICE '✅ Applied engineering rules to BomInstance %', v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error applying engineering rules to BomInstance %: %', v_bom_instance_id, SQLERRM;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Operational docs creation completed for Quote %', NEW.id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        RAISE WARNING '❌ SQLSTATE: %', SQLSTATE;
        -- Don't re-raise to prevent blocking the quote update
        RETURN NEW;
END;
$$;

-- Ensure trigger exists and is enabled
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Explicitly enable the trigger
ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
    'Creates SalesOrders, SalesOrderLines, BomInstances, and BomInstanceLines when Quote status changes to approved. Improved error handling and number generation fallback.';

COMMENT ON TRIGGER trg_on_quote_approved_create_operational_docs ON "Quotes" IS 
    'Automatically creates SalesOrder when Quote status changes to approved.';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 212 completed: Fixed Quote Approved Trigger';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Fixed:';
    RAISE NOTICE '   - Improved error handling for sale order number generation';
    RAISE NOTICE '   - Added fallback logic if get_next_counter_value fails';
    RAISE NOTICE '   - Explicitly enabled trigger';
    RAISE NOTICE '';
END $$;
