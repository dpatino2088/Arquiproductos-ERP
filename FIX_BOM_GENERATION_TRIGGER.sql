-- ====================================================
-- Fix BOM Generation Trigger
-- ====================================================
-- Este script corrige la función que genera BOM cuando
-- se crea un Manufacturing Order
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_quote_id uuid;
    v_quote_line_record RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
BEGIN
    -- Get SalesOrder record (FIXED: Use "SalesOrders" plural)
    SELECT * INTO v_sales_order_record
    FROM "SalesOrders"
    WHERE id = NEW.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ SalesOrder % not found for ManufacturingOrder %', NEW.sale_order_id, NEW.id;
        RETURN NEW;
    END IF;
    
    v_quote_id := v_sales_order_record.quote_id;
    
    RAISE NOTICE '🔔 ManufacturingOrder % created manually, generating BOM for SalesOrder %', NEW.manufacturing_order_no, v_sales_order_record.sale_order_no;
    
    -- Update SalesOrder status to 'In Production' (FIXED: Use "SalesOrders" plural)
    UPDATE "SalesOrders"
    SET status = 'In Production',
        updated_at = now()
    WHERE id = NEW.sale_order_id
    AND deleted = false
    AND status <> 'Delivered';
    
    -- FIXED: Do NOT update Quotes.status - quote_status enum doesn't include 'In Production'
    -- Quotes status should remain 'approved' throughout the manufacturing process
    
    -- Generate BOM for all QuoteLines in this SalesOrder
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
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = NEW.sale_order_id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Skip if no product_type_id
        IF v_quote_line_record.product_type_id IS NULL THEN
            RAISE NOTICE '⚠️ QuoteLine % has no product_type_id, skipping BOM generation', v_quote_line_record.quote_line_id;
            CONTINUE;
        END IF;
        
        -- Ensure organization_id is set
        IF v_quote_line_record.organization_id IS NULL THEN
            UPDATE "QuoteLines"
            SET organization_id = NEW.organization_id
            WHERE id = v_quote_line_record.quote_line_id;
            v_quote_line_record.organization_id := NEW.organization_id;
        END IF;
        
        -- Generate BOM for this QuoteLine
        BEGIN
            RAISE NOTICE '🔧 Generating BOM for QuoteLine %...', v_quote_line_record.quote_line_id;
            
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line_record.quote_line_id,
                v_quote_line_record.product_type_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                COALESCE(v_quote_line_record.cassette, false),
                v_quote_line_record.cassette_type,
                COALESCE(v_quote_line_record.side_channel, false),
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.qty
            );
            
            -- Note: BomInstance should be created by generate_configured_bom_for_quote_line
            -- If it doesn't exist, create it
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
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
                    NEW.organization_id,
                    v_quote_line_record.sale_order_line_id,
                    v_quote_line_record.quote_line_id,
                    NULL, -- configured_product_id can be NULL
                    'locked', -- Status: locked because it's for a Manufacturing Order
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
            ELSE
                RAISE NOTICE '✅ BomInstance % already exists for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
            END IF;
            
            RAISE NOTICE '✅ BOM generated for QuoteLine %', v_quote_line_record.quote_line_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error generating BOM for QuoteLine %: %', v_quote_line_record.quote_line_id, SQLERRM;
        END;
    END LOOP;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_insert_generate_bom for ManufacturingOrder %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Generates BOM automatically when a ManufacturingOrder is created manually from OrderList. This is the ONLY point where BOM is generated. Updates SO status to "In Production" but does NOT update Quotes.status (enum doesn''t support it). Uses "SalesOrders" (plural) table name.';

-- Ensure trigger exists and is active
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Automatically generates BOM when a ManufacturingOrder is created manually from OrderList. This is the ONLY point where BOM is generated.';

-- Verify
DO $$
BEGIN
    RAISE NOTICE '✅ Function on_manufacturing_order_insert_generate_bom updated';
    RAISE NOTICE '✅ Trigger trg_mo_insert_generate_bom created/updated';
END;
$$;

