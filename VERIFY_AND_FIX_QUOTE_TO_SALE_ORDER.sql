-- ====================================================
-- Complete Verification and Fix Script
-- ====================================================
-- This script:
-- 1. Verifies trigger and function exist
-- 2. Tests the trigger manually
-- 3. Creates missing SaleOrders
-- ====================================================

-- STEP 1: Verify trigger exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND tgname = 'trg_on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs exists';
    ELSE
        RAISE WARNING '❌ Trigger trg_on_quote_approved_create_operational_docs MISSING!';
        RAISE NOTICE '🔧 Creating trigger...';
        
        EXECUTE 'CREATE TRIGGER trg_on_quote_approved_create_operational_docs
            AFTER UPDATE OF status ON "Quotes"
            FOR EACH ROW
            WHEN (NEW.status = ''approved'' AND OLD.status IS DISTINCT FROM ''approved'')
            EXECUTE FUNCTION public.on_quote_approved_create_operational_docs()';
        
        RAISE NOTICE '✅ Trigger created';
    END IF;
END;
$$;

-- STEP 2: Verify function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Function on_quote_approved_create_operational_docs exists';
    ELSE
        RAISE WARNING '❌ Function on_quote_approved_create_operational_docs MISSING!';
        RAISE NOTICE '⚠️  Please run migration 197 first';
    END IF;
END;
$$;

-- STEP 3: Show approved quotes without SaleOrders
SELECT 
    'Approved Quotes without SaleOrders:' AS info,
    COUNT(*) AS count
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
AND so.id IS NULL;

-- STEP 4: Create SaleOrders for approved quotes (if any)
DO $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_number integer;
    v_last_order_no text;
    v_organization_id uuid;
    v_count integer := 0;
    v_line_number integer;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_validated_side_channel_type text;
BEGIN
    RAISE NOTICE '🔍 Creating SaleOrders for approved Quotes without one...';
    
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
        BEGIN
            v_organization_id := v_quote_record.organization_id;
            
            -- Generate sale_order_no
            IF EXISTS (
                SELECT 1 FROM pg_proc 
                WHERE proname = 'get_next_document_number' 
                AND pronamespace = 'public'::regnamespace
            ) THEN
                SELECT public.get_next_document_number(v_organization_id, 'SO') INTO v_sale_order_no;
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
            
            -- Create SaleOrderLines
            v_line_number := 1;
            FOR v_quote_line_record IN
                SELECT ql.*
                FROM "QuoteLines" ql
                WHERE ql.quote_id = v_quote_record.id
                AND ql.deleted = false
                ORDER BY ql.created_at ASC
            LOOP
                SELECT id INTO v_sale_order_line_id
                FROM "SaleOrderLines"
                WHERE sale_order_id = v_sale_order_id
                AND quote_line_id = v_quote_line_record.id
                AND deleted = false
                LIMIT 1;
                
                IF v_sale_order_line_id IS NULL THEN
                    IF v_quote_line_record.side_channel_type IS NULL THEN
                        v_validated_side_channel_type := NULL;
                    ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                        v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
                    ELSE
                        v_validated_side_channel_type := NULL;
                    END IF;
                    
                    INSERT INTO "SaleOrderLines" (
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
                        COALESCE(v_quote_record.created_by, auth.uid()),
                        COALESCE(v_quote_record.updated_by, auth.uid())
                    );
                    
                    v_line_number := v_line_number + 1;
                END IF;
            END LOOP;
            
            v_count := v_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error creating SaleOrder for Quote % (%): %', 
                    v_quote_record.id, v_quote_record.quote_no, SQLERRM;
        END;
    END LOOP;
    
    IF v_count = 0 THEN
        RAISE NOTICE '✅ All approved Quotes already have SaleOrders.';
    ELSE
        RAISE NOTICE '✅ Successfully created % SaleOrder(s).', v_count;
    END IF;
END;
$$;

-- STEP 5: Final verification
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.order_progress_status,
    (SELECT COUNT(*) FROM "SaleOrderLines" WHERE sale_order_id = so.id AND deleted = false) AS line_count
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;

