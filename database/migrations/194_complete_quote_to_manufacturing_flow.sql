-- ====================================================
-- Migration: Complete Quote to Manufacturing Flow
-- ====================================================
-- This migration:
-- 1. Updates on_quote_approved_create_operational_docs to create SaleOrder with status 'Draft'
-- 2. Creates trigger to auto-create ManufacturingOrder when SaleOrder.status = 'Confirmed'
-- 3. Ensures proper status flow: Quote(approved) → SaleOrder(Draft) → SaleOrder(Confirmed) → ManufacturingOrder
-- ====================================================

-- ====================================================
-- STEP 1: Update on_quote_approved_create_operational_docs
-- ====================================================
-- Change SaleOrder status from 'draft' to 'Draft' (customer-facing format)

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_quote_record record;
    v_quote_line_record record;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_validated_side_channel_type text;
    v_qlc_count integer;
BEGIN
    -- Only process when status transitions to 'approved'
    IF NEW.status != 'approved' THEN
        RETURN NEW;
    END IF;
    
    -- Prevent duplicate processing
    IF OLD.status = 'approved' THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 Trigger fired: Quote % status changed to approved', NEW.id;
    
    -- Get quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found or deleted', NEW.id;
        RETURN NEW;
    END IF;
    
    -- Calculate totals
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    
    -- Check if SaleOrder already exists
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Generate sale_order_no
        SELECT public.get_next_sequential_number('SaleOrders', 'sale_order_no', 'SO-')
        INTO v_sale_order_no;
        
        -- Create SaleOrder with status 'Draft' and order_progress_status 'approved_awaiting_confirmation'
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
            'Draft',  -- Changed from 'draft' to 'Draft'
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
        
        RAISE NOTICE '✅ Created SaleOrder % with status = Draft, order_progress_status = approved_awaiting_confirmation', v_sale_order_id;
    ELSE
        -- Update existing SaleOrder to ensure status and order_progress_status are set
        UPDATE "SalesOrders"
        SET status = COALESCE(status, 'Draft'),
            order_progress_status = COALESCE(order_progress_status, 'approved_awaiting_confirmation')
        WHERE id = v_sale_order_id
        AND (status IS NULL OR status = 'draft' OR status != 'Draft');
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
            
            -- Validate and normalize side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSE
                v_validated_side_channel_type := NULL;
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
    END LOOP;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
'Creates SaleOrder with status Draft and order_progress_status approved_awaiting_confirmation when Quote is approved. Also creates SaleOrderLines.';

-- ====================================================
-- STEP 2: Create function to auto-create ManufacturingOrder
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_manufacturing_order_no text;
    v_manufacturing_order_id uuid;
BEGIN
    -- Only process when status changes to 'Confirmed'
    IF NEW.status != 'Confirmed' OR OLD.status = 'Confirmed' THEN
        RETURN NEW;
    END IF;
    
    -- Check if ManufacturingOrder already exists for this SaleOrder
    SELECT id INTO v_manufacturing_order_id
    FROM "ManufacturingOrders"
    WHERE sale_order_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⏭️  ManufacturingOrder already exists for SaleOrder %, skipping creation', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 SaleOrder % status changed to Confirmed, creating ManufacturingOrder', NEW.id;
    
    -- Generate manufacturing_order_no
    SELECT public.get_next_sequential_number('ManufacturingOrders', 'manufacturing_order_no', 'MO-')
    INTO v_manufacturing_order_no;
    
    -- Create ManufacturingOrder with status 'planned'
    INSERT INTO "ManufacturingOrders" (
        organization_id,
        sale_order_id,
        manufacturing_order_no,
        status,
        created_by,
        updated_by
    ) VALUES (
        NEW.organization_id,
        NEW.id,
        v_manufacturing_order_no,
        'planned',
        NEW.updated_by,
        NEW.updated_by
    ) RETURNING id INTO v_manufacturing_order_id;
    
    RAISE NOTICE '✅ Created ManufacturingOrder % for SaleOrder %', v_manufacturing_order_id, NEW.id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_sale_order_confirmed_create_manufacturing_order for SaleOrder %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_sale_order_confirmed_create_manufacturing_order IS 
'Automatically creates a ManufacturingOrder (Order List) when SaleOrder.status changes to Confirmed. Sets ManufacturingOrder.status to planned.';

-- ====================================================
-- STEP 3: Create trigger on SaleOrders
-- ====================================================

DROP TRIGGER IF EXISTS trg_sale_order_confirmed_create_mo ON "SalesOrders";

CREATE TRIGGER trg_sale_order_confirmed_create_mo
    AFTER UPDATE OF status ON "SalesOrders"
    FOR EACH ROW
    WHEN (NEW.status = 'Confirmed' AND OLD.status IS DISTINCT FROM 'Confirmed')
    EXECUTE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order();

COMMENT ON TRIGGER trg_sale_order_confirmed_create_mo ON "SalesOrders" IS 
'Automatically creates ManufacturingOrder when SaleOrder.status changes to Confirmed.';

-- ====================================================
-- STEP 4: Verification queries (commented out)
-- ====================================================

/*
-- Verify function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'on_sale_order_confirmed_create_manufacturing_order';

-- Verify trigger exists
SELECT tgname, relname, pg_get_triggerdef(oid)
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'SaleOrders'
AND tgname = 'trg_sale_order_confirmed_create_mo';

-- Test: Update a SaleOrder to Confirmed and check if ManufacturingOrder is created
-- SELECT id, sale_order_no, status FROM "SalesOrders" WHERE status = 'Draft' LIMIT 1;
-- UPDATE "SalesOrders" SET status = 'Confirmed' WHERE id = '<sale_order_id>';
-- SELECT id, manufacturing_order_no, status FROM "ManufacturingOrders" WHERE sale_order_id = '<sale_order_id>';
*/




