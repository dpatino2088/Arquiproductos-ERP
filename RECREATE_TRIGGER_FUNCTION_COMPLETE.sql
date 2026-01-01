-- ====================================================
-- Recreate Trigger Function - Complete and Fixed
-- ====================================================
-- This script recreates the on_quote_approved_create_operational_docs function
-- with all fixes and correct naming (Sales Orders)
-- ====================================================

-- ====================================================
-- STEP 1: Drop and Recreate the Function
-- ====================================================

DROP FUNCTION IF EXISTS public.on_quote_approved_create_operational_docs() CASCADE;

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
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
    v_next_number integer;
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
    
    -- Check if Sales Order already exists
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Generate sales_order_no with fallback logic
        -- Try get_next_document_number first (most common)
        IF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_document_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_document_number(v_quote_record.organization_id, 'SO') INTO v_sale_order_no;
            RAISE NOTICE '   Using get_next_document_number: %', v_sale_order_no;
        -- Try get_next_sequential_number
        ELSIF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_sequential_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
            RAISE NOTICE '   Using get_next_sequential_number: %', v_sale_order_no;
        -- Fallback: manual generation
        ELSE
            SELECT sale_order_no INTO v_last_order_no
            FROM "SalesOrders"
            WHERE organization_id = v_quote_record.organization_id
            AND deleted = false
            ORDER BY created_at DESC
            LIMIT 1;

            IF v_last_order_no IS NULL THEN
                v_next_number := 1;
            ELSE
                -- Extract number from format SO-000001
                v_next_number := COALESCE(
                    (SELECT (regexp_match(v_last_order_no, 'SO-(\d+)'))[1]::integer),
                    0
                ) + 1;
            END IF;

            v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
            RAISE NOTICE '   Using manual generation: %', v_sale_order_no;
        END IF;
        
        -- Create Sales Order with status 'Draft' and order_progress_status 'approved_awaiting_confirmation'
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
            'Draft',  -- Customer-facing format
            'approved_awaiting_confirmation',
            COALESCE(v_quote_record.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            v_quote_record.notes,
            CURRENT_DATE,
            COALESCE(NEW.created_by, auth.uid()),
            COALESCE(NEW.updated_by, auth.uid())
        ) RETURNING id INTO v_sale_order_id;
        
        RAISE NOTICE '✅ Created Sales Order % (% with status = Draft, order_progress_status = approved_awaiting_confirmation)', v_sale_order_id, v_sale_order_no;
    ELSE
        -- Update existing Sales Order to ensure status and order_progress_status are set
        UPDATE "SalesOrders"
        SET status = COALESCE(NULLIF(status, ''), 'Draft'),
            order_progress_status = COALESCE(order_progress_status, 'approved_awaiting_confirmation'),
            updated_at = now()
        WHERE id = v_sale_order_id
        AND (status IS NULL OR status = '' OR LOWER(status) = 'draft' OR status != 'Draft');
        
        RAISE NOTICE 'ℹ️ Sales Order already exists for Quote %. Updated if needed.', NEW.id;
    END IF;
    
    -- Step B: For each QuoteLine, find or create SaleOrderLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Find existing SalesOrderLine for this quote_line_id
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
                RAISE NOTICE '   Invalid side_channel_type "%" for QuoteLine %, setting to NULL', 
                    v_quote_line_record.side_channel_type, v_quote_line_record.id;
            END IF;
            
            -- Create SalesOrderLine
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
                NULL,  -- QuoteLines doesn't have description column
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
                v_quote_line_record.metadata,
                COALESCE(NEW.created_by, auth.uid()),
                COALESCE(NEW.updated_by, auth.uid())
            ) RETURNING id INTO v_sale_order_line_id;
            
            RAISE NOTICE '   ✅ Created Sales Order Line % for QuoteLine %', v_line_number, v_quote_line_record.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Trigger completed successfully for Quote %', NEW.id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        RAISE WARNING '❌ Error details: %', SQLSTATE;
        -- Don't re-raise to prevent blocking the quote status update
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
'Creates Sales Order with status Draft and order_progress_status approved_awaiting_confirmation when Quote is approved. Also creates Sales Order Lines. Uses fallback logic for number generation.';

-- ====================================================
-- STEP 2: Recreate the Trigger
-- ====================================================

DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

COMMENT ON TRIGGER trg_on_quote_approved_create_operational_docs ON "Quotes" IS 
'Automatically creates Sales Order when Quote status changes to approved.';

-- ====================================================
-- STEP 3: Verify Function and Trigger
-- ====================================================

-- Verify function exists and has correct properties
SELECT 
    p.proname AS function_name,
    CASE p.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        WHEN 'v' THEN 'VOLATILE'
    END AS volatility,
    CASE p.prosecdef
        WHEN true THEN 'SECURITY DEFINER ✅'
        ELSE 'SECURITY INVOKER'
    END AS security
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';

-- Verify trigger exists and is enabled
SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'Enabled ✅'
        WHEN 'D' THEN 'Disabled ❌'
        ELSE 'Unknown'
    END AS trigger_status,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'Quotes'
AND t.tgname = 'trg_on_quote_approved_create_operational_docs';

-- ====================================================
-- STEP 4: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Function and Trigger Recreated!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Function: on_quote_approved_create_operational_docs';
    RAISE NOTICE '  ✅ SECURITY DEFINER';
    RAISE NOTICE '  ✅ VOLATILE';
    RAISE NOTICE '  ✅ Creates Sales Orders (not Sale Orders)';
    RAISE NOTICE '';
    RAISE NOTICE 'Trigger: trg_on_quote_approved_create_operational_docs';
    RAISE NOTICE '  ✅ Enabled on Quotes table';
    RAISE NOTICE '  ✅ Fires when status changes to ''approved''';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Test by updating a Quote to ''approved''';
    RAISE NOTICE '  2. Verify Sales Order is created automatically';
    RAISE NOTICE '  3. Check logs for any errors';
    RAISE NOTICE '';
END;
$$;

