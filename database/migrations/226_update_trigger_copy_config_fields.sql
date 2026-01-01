-- ====================================================
-- Migration 226: Update Trigger to Copy Configuration Fields
-- ====================================================
-- Updates on_quote_approved_create_operational_docs to copy
-- tube_type, operating_system_variant, top_rail_type to SalesOrderLines
-- ====================================================

BEGIN;

-- Update the INSERT INTO SalesOrderLines to include new config fields
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
            updated_by,
            deleted
        ) VALUES (
            v_quote_record.organization_id,
            NEW.id,
            v_quote_record.customer_id,
            v_sale_order_no,
            'Draft',  -- ⚠️ Must be 'Draft' (capital D) per SalesOrders_status_check constraint
            COALESCE(v_quote_record.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            v_quote_record.notes,
            CURRENT_DATE,
            NEW.created_by,
            NEW.updated_by,
            false
        ) RETURNING id INTO v_sale_order_id;
        
        RAISE NOTICE '✅ Created SalesOrder % (sale_order_no: %)', v_sale_order_id, v_sale_order_no;
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
            END IF;
            
            -- Create SaleOrderLine with ALL configuration fields
            INSERT INTO "SalesOrderLines" (
                sale_order_id,
                quote_line_id,
                line_number,
                catalog_item_id,
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
                -- ⭐ NEW: Copy configuration fields
                tube_type,
                operating_system_variant,
                top_rail_type,
                unit_price_snapshot,
                unit_cost_snapshot,
                line_total,
                measure_basis_snapshot,
                margin_percentage,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_sale_order_id,
                v_quote_line_record.id,
                v_line_number,
                v_quote_line_record.catalog_item_id,
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
                -- ⭐ NEW: Copy configuration fields
                v_quote_line_record.tube_type,
                v_quote_line_record.operating_system_variant,
                v_quote_line_record.top_rail_type,
                v_quote_line_record.unit_price_snapshot,
                v_quote_line_record.unit_cost_snapshot,
                v_quote_line_record.line_total,
                v_quote_line_record.measure_basis_snapshot,
                v_quote_line_record.margin_percentage,
                false,
                now(),
                now()
            ) RETURNING id INTO v_sale_order_line_id;
        END IF;
        
        -- ⭐ Step C: Generate QuoteLineComponents if they don't exist
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
                -- ⭐ Now uses the new resolver with configuration fields
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
                    -- ⭐ NEW: Pass configuration fields for deterministic SKU resolution
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant
                );
                
                RAISE NOTICE '✅ QuoteLineComponents generated for QuoteLine %', v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error generating QuoteLineComponents for QuoteLine %: %', v_quote_line_record.id, SQLERRM;
                    -- Continue processing even if BOM generation fails
            END;
        ELSIF v_qlc_count = 0 AND v_quote_line_record.product_type_id IS NULL THEN
            RAISE WARNING '⚠️ QuoteLine % has no product_type_id, cannot generate BOM', v_quote_line_record.id;
        END IF;
        
        -- Step D: Find or create BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get BOMTemplate for this product_type_id
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
                
                -- Create BomInstance
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
                    -- Continue even if BomInstance creation fails
            END;
        END IF;
        
        -- Step E: Populate BomInstanceLines from QuoteLineComponents (frozen snapshot)
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
            -- Only insert if BomInstance exists
            IF v_bom_instance_id IS NOT NULL THEN
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
                    NULL, -- source_template_line_id (optional)
                    v_component_record.catalog_item_id,
                    ci.sku,
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_canonical_uom,
                    COALESCE(v_component_record.item_name, ci.item_name),
                    v_unit_cost_exw,
                    v_total_cost_exw,
                    v_category_code,
                    now(),
                    now(),
                    false
                )
                ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                WHERE deleted = false
                DO NOTHING; -- Frozen snapshot: don't update if exists
            END IF;
        END LOOP;
        
        -- Step F: Apply engineering rules and convert linear UOM
        IF v_bom_instance_id IS NOT NULL THEN
            BEGIN
                PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
                RAISE NOTICE '✅ Applied engineering rules and converted linear UOM for BomInstance %', v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error applying engineering rules and converting linear UOM for BomInstance %: %', v_bom_instance_id, SQLERRM;
            END;
        END IF;
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
    'Trigger function that creates SalesOrder, SalesOrderLines, BomInstances, and BomInstanceLines when a Quote is approved. Automatically generates QuoteLineComponents if they don''t exist and product_type_id is available. Copies all configuration fields (tube_type, operating_system_variant, top_rail_type) to SalesOrderLines for traceability.';

COMMIT;

