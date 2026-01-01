-- ====================================================
-- Migration: Create trigger for Sale Order status changes
-- ====================================================
-- This migration creates a trigger that generates BOM automatically
-- when a Sale Order status changes to 'confirmed' or 'in_production'
-- ====================================================

-- Function to generate BOM when Sale Order status changes
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
    'Trigger function that generates BOM automatically when a Sale Order status changes to confirmed or in_production.';

-- Create trigger
DROP TRIGGER IF EXISTS trg_on_sale_order_status_changed_generate_bom ON "SaleOrders";

CREATE TRIGGER trg_on_sale_order_status_changed_generate_bom
    AFTER UPDATE OF status ON "SaleOrders"
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.on_sale_order_status_changed_generate_bom();

COMMENT ON TRIGGER trg_on_sale_order_status_changed_generate_bom ON "SaleOrders" IS 
    'Trigger that generates BOM automatically when Sale Order status changes to confirmed or in_production.';








