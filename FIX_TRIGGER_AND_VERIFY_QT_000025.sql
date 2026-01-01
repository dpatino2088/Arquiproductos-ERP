-- ====================================================
-- Fix Trigger and Verify QT-000025 Sales Order
-- ====================================================
-- This script:
-- 1. Fixes the trigger function to use 'SalesOrders' correctly
-- 2. Verifies trigger is active
-- 3. Creates Sales Order for QT-000025 if missing
-- ====================================================

SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 1: Recreate Trigger Function with Correct Table Names
-- ====================================================

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
        -- Try get_next_sequential_number (FIXED: use SalesOrders, not SaleOrders)
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
    
    -- Step B: For each QuoteLine, find or create SalesOrderLine
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
'Creates Sales Order with status Draft and order_progress_status approved_awaiting_confirmation when Quote is approved. Also creates Sales Order Lines. Uses fallback logic for number generation. FIXED: Uses SalesOrders table name.';

-- ====================================================
-- STEP 2: Recreate Trigger
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
-- STEP 3: Create Sales Order for QT-000025 if missing
-- ====================================================

DO $$
DECLARE
    v_quote_id uuid;
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_next_number integer;
    v_last_order_no text;
    v_line_count integer;
BEGIN
    -- Get quote record
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE quote_no = 'QT-000025'
    AND deleted = false;
    
    IF v_quote_id IS NULL THEN
        RAISE WARNING '❌ Quote QT-000025 not found';
        RETURN;
    END IF;
    
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_id
    AND deleted = false;
    
    RAISE NOTICE '✅ Found Quote: % (Status: %)', v_quote_record.quote_no, v_quote_record.status;
    
    -- Check if Sales Order already exists
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false
    LIMIT 1;
    
    IF v_sale_order_id IS NOT NULL THEN
        SELECT sale_order_no INTO v_sale_order_no FROM "SalesOrders" WHERE id = v_sale_order_id;
        SELECT COUNT(*) INTO v_line_count FROM "SalesOrderLines" WHERE sale_order_id = v_sale_order_id AND deleted = false;
        RAISE NOTICE 'ℹ️ Sales Order already exists for QT-000025';
        RAISE NOTICE '   Sales Order No: %', v_sale_order_no;
        RAISE NOTICE '   Line Count: %', v_line_count;
        RETURN;
    END IF;
    
    RAISE NOTICE '⚠️ No Sales Order found for QT-000025. Creating one...';
    
    -- Calculate totals
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    
    -- Generate sales_order_no
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_document_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_document_number(v_quote_record.organization_id, 'SO') INTO v_sale_order_no;
    ELSIF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_sequential_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
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
            v_next_number := COALESCE(
                (SELECT (regexp_match(v_last_order_no, 'SO-(\d+)'))[1]::integer),
                0
            ) + 1;
        END IF;

        v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
    END IF;
    
    -- Create Sales Order
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
        v_quote_id,
        v_quote_record.customer_id,
        v_sale_order_no,
        'Draft',
        'approved_awaiting_confirmation',
        COALESCE(v_quote_record.currency, 'USD'),
        v_subtotal,
        v_tax,
        v_total,
        v_quote_record.notes,
        CURRENT_DATE,
        COALESCE(v_quote_record.created_by, auth.uid()),
        COALESCE(v_quote_record.updated_by, auth.uid())
    ) RETURNING id INTO v_sale_order_id;
    
    RAISE NOTICE '✅ Created Sales Order % (%) for QT-000025', v_sale_order_id, v_sale_order_no;
    
    -- Create Sales Order Lines from Quote Lines
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
    )
    SELECT 
        v_quote_record.organization_id,
        v_sale_order_id,
        ql.id,
        ql.catalog_item_id,
        ROW_NUMBER() OVER (ORDER BY ql.created_at ASC) AS line_number,
        NULL AS description,  -- QuoteLines doesn't have description column
        ql.qty,
        COALESCE(ql.unit_price_snapshot, 0),
        COALESCE(ql.line_total, 0),
        ql.width_m,
        ql.height_m,
        ql.area,
        ql.position,
        ql.collection_name,
        ql.variant_name,
        ql.product_type,
        ql.product_type_id,
        ql.drive_type,
        ql.bottom_rail_type,
        COALESCE(ql.cassette, false),
        ql.cassette_type,
        COALESCE(ql.side_channel, false),
        CASE 
            WHEN ql.side_channel_type IS NULL THEN NULL
            WHEN LOWER(ql.side_channel_type) IN ('side_only', 'side_and_bottom') THEN LOWER(ql.side_channel_type)
            ELSE NULL
        END,
        ql.hardware_color,
        ql.metadata,
        COALESCE(v_quote_record.created_by, auth.uid()),
        COALESCE(v_quote_record.updated_by, auth.uid())
    FROM "QuoteLines" ql
    WHERE ql.quote_id = v_quote_id
    AND ql.deleted = false
    ORDER BY ql.created_at ASC;
    
    SELECT COUNT(*) INTO v_line_count FROM "SalesOrderLines" WHERE sale_order_id = v_sale_order_id AND deleted = false;
    RAISE NOTICE '✅ Created % Sales Order Lines for QT-000025', v_line_count;
    
END;
$$;

-- ====================================================
-- STEP 4: Verify Result
-- ====================================================

SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    so.id AS sales_order_id,
    so.sale_order_no,
    so.status AS sales_order_status,
    so.order_progress_status,
    COUNT(sol.id) AS line_count,
    CASE 
        WHEN so.id IS NULL THEN '❌ No Sales Order'
        ELSE '✅ Sales Order exists'
    END AS result
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE q.quote_no = 'QT-000025'
AND q.deleted = false
GROUP BY q.id, q.quote_no, q.status, so.id, so.sale_order_no, so.status, so.order_progress_status;

-- ====================================================
-- STEP 5: Verify Trigger Status
-- ====================================================

SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'Enabled ✅'
        WHEN 'D' THEN 'Disabled ❌'
        ELSE 'Unknown'
    END AS trigger_status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'Quotes'
AND t.tgname = 'trg_on_quote_approved_create_operational_docs';

-- ====================================================
-- STEP 6: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Fix Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Fixed:';
    RAISE NOTICE '  ✅ Trigger function uses SalesOrders (not SaleOrders)';
    RAISE NOTICE '  ✅ Trigger recreated and enabled';
    RAISE NOTICE '  ✅ Sales Order created for QT-000025 (if missing)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Verify Sales Order appears in UI';
    RAISE NOTICE '  2. Test trigger by approving another quote';
    RAISE NOTICE '';
END;
$$;

