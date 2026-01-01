-- ====================================================
-- Migration: Update BOM Trigger to Use Base/Pricing Fields
-- ====================================================
-- This migration updates the trigger function to populate
-- base and pricing fields when creating BomInstanceLines
-- ====================================================

-- Update the trigger function to populate base/pricing fields
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
        -- Generate sale order number
        v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
        v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
        
        -- Extract totals from JSONB
        v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
        v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
        v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
        
        -- Create SaleOrder
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
            order_date,
            created_by,
            updated_by
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
            CURRENT_DATE,
            NEW.created_by,
            NEW.updated_by
        ) RETURNING id INTO v_sale_order_id;
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
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' OR
                  LOWER(v_quote_line_record.side_channel_type) = 'side_and_bottom' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                -- Invalid value, set to NULL
                v_validated_side_channel_type := NULL;
                RAISE NOTICE 'Invalid side_channel_type value "%" for QuoteLine %, setting to NULL', 
                    v_quote_line_record.side_channel_type, v_quote_line_record.id;
            END IF;
            
            -- Create SaleOrderLine
            INSERT INTO "SalesOrderLines" (
                organization_id,
                sale_order_id,
                quote_line_id,
                catalog_item_id,
                line_number,
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
                v_quote_record.organization_id,
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.catalog_item_id,
                v_line_number,
                v_quote_line_record.qty,
                COALESCE(v_quote_line_record.unit_price_snapshot, 0),
                COALESCE(v_quote_line_record.line_total, 0),
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
                NULL, -- Can be NULL now
                'locked', -- Locked because quote is approved
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
            -- Compute canonical UOM (preserves m2 for fabric/area)
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw using get_unit_cost_in_uom (supports m2 now)
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
                NULL, -- source_template_line_id (optional)
                v_component_record.catalog_item_id,
                NULL, -- resolved_sku (can be populated later if needed)
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
    END LOOP;
    
    RAISE NOTICE '✅ Operational docs creation completed for Quote %', NEW.id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        -- Return NEW to allow the quote update to succeed even if operational docs creation fails
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
    'Trigger function that creates SaleOrder, SaleOrderLines, BomInstances, and BomInstanceLines when a Quote is approved. Now includes base/pricing fields population. Re-entrant: creates only missing pieces.';

-- Recreate trigger (idempotent)
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated trigger function to populate base/pricing fields';
    RAISE NOTICE '   - BomInstanceLines now get qty_base, uom_base, qty_pricing, uom_pricing populated automatically';
    RAISE NOTICE '   - Fabric items preserve m2 as base, convert to pricing UOM based on fabric_pricing_mode';
    RAISE NOTICE '';
END $$;


