-- ====================================================
-- Verify and Fix Sales Order for QT-000025
-- ====================================================
-- This script verifies if QT-000025 has a Sales Order
-- and creates one if it doesn't exist
-- ====================================================

SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 1: Check Current State
-- ====================================================

SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    q.organization_id,
    q.customer_id,
    q.created_at,
    so.id AS sales_order_id,
    so.sale_order_no,
    so.status AS sales_order_status,
    so.order_progress_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000025'
AND q.deleted = false;

-- ====================================================
-- STEP 2: Verify Trigger Status
-- ====================================================

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
-- STEP 3: Check Function Definition
-- ====================================================

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

-- ====================================================
-- STEP 4: Create Sales Order for QT-000025 if missing
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
        RAISE NOTICE 'ℹ️ Sales Order already exists for QT-000025';
        SELECT sale_order_no INTO v_sale_order_no FROM "SalesOrders" WHERE id = v_sale_order_id;
        RAISE NOTICE '   Sales Order No: %', v_sale_order_no;
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
        RAISE NOTICE '   Using get_next_document_number: %', v_sale_order_no;
    ELSIF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_sequential_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
        RAISE NOTICE '   Using get_next_sequential_number: %', v_sale_order_no;
    ELSE
        -- Fallback: manual generation
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
        RAISE NOTICE '   Using manual generation: %', v_sale_order_no;
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
        ql.description,
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
    
    RAISE NOTICE '✅ Created Sales Order Lines for QT-000025';
    
END;
$$;

-- ====================================================
-- STEP 5: Verify Result
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
-- STEP 6: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Verification Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Verify Sales Order appears in UI';
    RAISE NOTICE '  2. Check that trigger is working for future quotes';
    RAISE NOTICE '  3. If trigger is not working, run RECREATE_TRIGGER_FUNCTION_COMPLETE.sql';
    RAISE NOTICE '';
END;
$$;








