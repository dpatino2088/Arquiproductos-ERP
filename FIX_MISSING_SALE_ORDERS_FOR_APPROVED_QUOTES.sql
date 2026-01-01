-- ====================================================
-- Script: Fix Missing Sale Orders for Approved Quotes
-- ====================================================
-- This script creates SaleOrders for approved Quotes that don't have one yet
-- Run this AFTER running migration 197
-- ====================================================

DO $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_number integer;
    v_last_order_no text;
    v_organization_id uuid;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '🔍 Searching for approved Quotes without SaleOrders...';
    
    -- Find approved quotes without SaleOrders
    FOR v_quote_record IN
        SELECT 
            q.id,
            q.organization_id,
            q.customer_id,
            q.quote_no,
            q.currency,
            q.totals,
            q.notes,
            q.created_by,
            q.updated_by
        FROM "Quotes" q
        LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND so.id IS NULL
        ORDER BY q.created_at ASC
    LOOP
        v_organization_id := v_quote_record.organization_id;
        
        -- Generate sale_order_no
        -- Try get_next_document_number first
        IF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_document_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_document_number(v_organization_id, 'SO') INTO v_sale_order_no;
        -- Fallback: manual generation
        ELSE
            SELECT sale_order_no INTO v_last_order_no
            FROM "SaleOrders"
            WHERE organization_id = v_organization_id
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
        
        -- Create SaleOrder
        INSERT INTO "SaleOrders" (
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
            v_quote_record.id,
            v_quote_record.customer_id,
            v_sale_order_no,
            'Draft',
            'approved_awaiting_confirmation',
            COALESCE(v_quote_record.currency, 'USD'),
            COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0),
            COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0),
            COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0),
            v_quote_record.notes,
            CURRENT_DATE,
            COALESCE(v_quote_record.created_by, auth.uid()),
            COALESCE(v_quote_record.updated_by, auth.uid())
        ) RETURNING id INTO v_sale_order_id;
        
        RAISE NOTICE '✅ Created SaleOrder % (%) for Quote % (%)', 
            v_sale_order_id, v_sale_order_no, v_quote_record.id, v_quote_record.quote_no;
        
        v_count := v_count + 1;
    END LOOP;
    
    IF v_count = 0 THEN
        RAISE NOTICE '✅ All approved Quotes already have SaleOrders.';
    ELSE
        RAISE NOTICE '✅ Created % SaleOrder(s) for approved Quotes.', v_count;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error creating SaleOrders: %', SQLERRM;
        RAISE;
END;
$$;

-- Verification query
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.order_progress_status
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;








