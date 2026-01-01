-- ====================================================
-- Migration 326: Minimal Trigger - SalesOrder Only
-- ====================================================
-- GOAL: Make SalesOrder creation deterministic and unbreakable
-- RULE: DB is the ONLY layer that creates SalesOrders
-- ====================================================

-- ====================================================
-- PART A: Unique Index (Idempotency)
-- ====================================================

-- Drop existing index if it exists (to recreate with exact definition)
DROP INDEX IF EXISTS public.ux_salesorders_org_quote_active;

-- Create partial unique index: 1 active SO per (org, quote)
CREATE UNIQUE INDEX ux_salesorders_org_quote_active
ON public."SalesOrders" (organization_id, quote_id)
WHERE deleted = false;

COMMENT ON INDEX public.ux_salesorders_org_quote_active IS 
    'Ensures idempotency: only one active SalesOrder per organization and quote';

-- ====================================================
-- PART B: Idempotent Function (Concurrency-Safe)
-- ====================================================

CREATE OR REPLACE FUNCTION public.ensure_sales_order_for_approved_quote(
    p_quote_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_existing_so_id uuid;
    v_so_id uuid;
    v_sale_order_no text;
    v_next_counter integer;
    v_subtotal numeric(12,4) := 0;
    v_tax numeric(12,4) := 0;
    v_total numeric(12,4) := 0;
BEGIN
    -- Load quote record
    SELECT 
        q.id,
        q.organization_id,
        q.customer_id,
        q.currency,
        q.notes,
        q.created_by,
        q.updated_by,
        q.totals
    INTO v_quote_record
    FROM "Quotes" q
    WHERE q.id = p_quote_id
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote % not found or deleted', p_quote_id;
    END IF;
    
    IF v_quote_record.organization_id IS NULL THEN
        RAISE EXCEPTION 'Quote % has NULL organization_id', p_quote_id;
    END IF;
    
    -- Check if SalesOrder already exists (idempotency check)
    SELECT so.id INTO v_existing_so_id
    FROM "SalesOrders" so
    WHERE so.organization_id = v_quote_record.organization_id
    AND so.quote_id = p_quote_id
    AND so.deleted = false
    LIMIT 1;
    
    IF v_existing_so_id IS NOT NULL THEN
        RAISE NOTICE 'SalesOrder already exists for Quote %: %', p_quote_id, v_existing_so_id;
        RETURN v_existing_so_id;
    END IF;
    
    -- Generate sale_order_no (robust with multiple fallbacks)
    BEGIN
        -- Try using counter function
        v_next_counter := public.get_next_counter_value(
            v_quote_record.organization_id, 
            'sale_order'
        );
        v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
        
        -- Validate: ensure sale_order_no is not NULL or empty
        IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
            RAISE EXCEPTION 'Generated sale_order_no is NULL or empty';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error generating sale_order_no via counter: %, trying fallback 1', SQLERRM;
            
            -- Fallback 1: use MAX + 1 from existing SalesOrders
            BEGIN
                SELECT COALESCE(
                    MAX(CAST(SUBSTRING(sale_order_no FROM 'SO-(\d+)') AS INTEGER)), 
                    0
                ) + 1
                INTO v_next_counter
                FROM "SalesOrders"
                WHERE organization_id = v_quote_record.organization_id
                AND sale_order_no IS NOT NULL
                AND sale_order_no ~ '^SO-\d+$';
                
                v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
                
                -- Validate fallback 1
                IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
                    RAISE EXCEPTION 'Fallback 1 generated NULL sale_order_no';
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Fallback 1 failed: %, trying fallback 2', SQLERRM;
                    
                    -- Fallback 2: use timestamp-based number (last resort)
                    v_next_counter := CAST(EXTRACT(EPOCH FROM now())::bigint % 1000000 AS integer);
                    v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
                    
                    -- Final validation
                    IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
                        RAISE EXCEPTION 'All fallbacks failed: sale_order_no is still NULL';
                    END IF;
            END;
    END;
    
    -- Final validation before INSERT
    IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
        RAISE EXCEPTION 'CRITICAL: sale_order_no is NULL or empty after all attempts';
    END IF;
    
    -- Extract totals from JSONB
    IF v_quote_record.totals IS NOT NULL THEN
        v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
        v_tax := COALESCE(
            (v_quote_record.totals->>'tax')::numeric(12,4), 
            (v_quote_record.totals->>'tax_total')::numeric(12,4), 
            0
        );
        v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    END IF;
    
    -- Create SalesOrder (idempotent: unique index prevents duplicates)
    BEGIN
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
            deleted,
            created_at,
            updated_at
        )
        VALUES (
            v_quote_record.organization_id,
            p_quote_id,
            v_quote_record.customer_id,
            v_sale_order_no,  -- CRITICAL: Must be set
            'Draft',  -- Must be 'Draft' (capital D) per SalesOrders_status_check constraint
            COALESCE(v_quote_record.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            v_quote_record.notes,
            CURRENT_DATE,
            v_quote_record.created_by,
            v_quote_record.updated_by,
            false,
            now(),
            now()
        )
        RETURNING id INTO v_so_id;
        
        RAISE NOTICE '✅ Created SalesOrder % (sale_order_no: %) for Quote %', 
            v_so_id, v_sale_order_no, p_quote_id;
        
        RETURN v_so_id;
        
    EXCEPTION
        WHEN unique_violation THEN
            -- Concurrent insert happened, fetch existing
            RAISE NOTICE '⚠️ Concurrent insert detected, fetching existing SalesOrder';
            SELECT so.id INTO v_existing_so_id
            FROM "SalesOrders" so
            WHERE so.organization_id = v_quote_record.organization_id
            AND so.quote_id = p_quote_id
            AND so.deleted = false
            LIMIT 1;
            
            IF v_existing_so_id IS NOT NULL THEN
                RAISE NOTICE '✅ Returning existing SalesOrder: %', v_existing_so_id;
                RETURN v_existing_so_id;
            ELSE
                RAISE EXCEPTION 'Unique violation but SalesOrder not found for Quote %', p_quote_id;
            END IF;
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error creating SalesOrder for Quote %: %', p_quote_id, SQLERRM;
    END;
END;
$$;

COMMENT ON FUNCTION public.ensure_sales_order_for_approved_quote IS 
    'Idempotent function to ensure a SalesOrder exists for an approved quote. Returns existing SO if present, creates new one if not. Handles concurrent inserts safely.';

-- ====================================================
-- PART C: Minimal Trigger (SalesOrder Only)
-- ====================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON public."Quotes";

-- Create minimal trigger: ONLY creates SalesOrder
CREATE TRIGGER trg_on_quote_approved_create_operational_docs
AFTER UPDATE ON public."Quotes"
FOR EACH ROW
WHEN (
    NEW.deleted = false
    AND OLD.status IS DISTINCT FROM NEW.status
    AND (
        UPPER(TRIM(COALESCE(NEW.status::text, ''))) = 'APPROVED'
        OR NEW.status::text ILIKE 'approved'
    )
)
EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- ====================================================
-- PART D: Minimal Trigger Function (SalesOrder + SalesOrderLines Only)
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_so_id uuid;
    v_quote_record RECORD;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
BEGIN
    -- Log trigger execution
    RAISE NOTICE '🔔 Trigger on_quote_approved_create_operational_docs FIRED for Quote % (status: %)', 
        NEW.id, NEW.status;
    
    -- STEP 1: Create SalesOrder (idempotent)
    BEGIN
        v_so_id := public.ensure_sales_order_for_approved_quote(NEW.id);
        
        IF v_so_id IS NOT NULL THEN
            RAISE NOTICE '✅ SalesOrder created/verified: % for Quote %', v_so_id, NEW.id;
        ELSE
            RAISE WARNING '⚠️ ensure_sales_order_for_approved_quote returned NULL for Quote %', NEW.id;
            RETURN NEW;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error creating SalesOrder for Quote %: %', NEW.id, SQLERRM;
            RAISE;
    END;
    
    -- STEP 2: Load quote record (for organization_id)
    SELECT organization_id INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found or deleted', NEW.id;
        RETURN NEW;
    END IF;
    
    -- STEP 3: Create SalesOrderLines for each QuoteLine (idempotent)
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Check if SalesOrderLine already exists
        SELECT id INTO v_sale_order_line_id
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_so_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so_id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SalesOrderLine (using only columns that exist)
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sale_order_id,
                    quote_line_id,
                    line_number,
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
                    tube_type,
                    operating_system_variant,
                    top_rail_type,
                    organization_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_so_id,
                    v_quote_line_record.id,
                    v_line_number,
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
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant,
                    v_quote_line_record.top_rail_type,
                    v_quote_record.organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                RAISE NOTICE '  ✅ Created SalesOrderLine % for QuoteLine %', v_sale_order_line_id, v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error creating SalesOrderLine for QuoteLine %: %', 
                        v_quote_line_record.id, SQLERRM;
                    -- Continue with next line instead of failing entire trigger
            END;
        ELSE
            RAISE NOTICE '  ⏭️  SalesOrderLine already exists for QuoteLine %', v_quote_line_record.id;
        END IF;
    END LOOP;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
    'Minimal trigger function: Creates SalesOrder and SalesOrderLines only. BOM/components generation must be done separately (e.g., in Manufacturing step).';

-- ====================================================
-- PART E: Enable Trigger
-- ====================================================

ALTER TABLE public."Quotes" 
ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;

-- ====================================================
-- PART F: Backfill Missing SalesOrders
-- ====================================================

DO $$
DECLARE
    v_quote RECORD;
    v_count integer := 0;
    v_so_id uuid;
BEGIN
    RAISE NOTICE '🔧 Backfilling missing SalesOrders for approved quotes...';
    
    FOR v_quote IN
        SELECT q.id, q.quote_no, q.organization_id
        FROM "Quotes" q
        WHERE q.deleted = false
        AND q.status::text ILIKE 'approved'
        AND NOT EXISTS (
            SELECT 1
            FROM "SalesOrders" so
            WHERE so.quote_id = q.id
            AND so.deleted = false
        )
        ORDER BY q.created_at
    LOOP
        BEGIN
            v_so_id := public.ensure_sales_order_for_approved_quote(v_quote.id);
            
            IF v_so_id IS NOT NULL THEN
                v_count := v_count + 1;
                RAISE NOTICE '  ✅ Created SalesOrder for Quote %', v_quote.quote_no;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Failed to create SalesOrder for Quote %: %', 
                    v_quote.quote_no, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Backfill complete: % SalesOrders created', v_count;
END $$;

-- ====================================================
-- PART G: Verification Queries
-- ====================================================

-- Query 1: Approved quotes without SalesOrder (must return 0 rows)
SELECT 
    'VERIFICATION 1: Approved quotes without SalesOrder' as check_name,
    q.id,
    q.quote_no,
    q.status,
    q.organization_id,
    CASE 
        WHEN so.id IS NULL THEN '❌ MISSING'
        ELSE '✅ OK'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.deleted = false
AND q.status::text ILIKE 'approved'
AND so.id IS NULL
ORDER BY q.created_at DESC;

-- Query 2: Duplicate SalesOrders check (must return 0 rows)
SELECT 
    'VERIFICATION 2: Duplicate SalesOrders' as check_name,
    organization_id,
    quote_id,
    COUNT(*) as duplicate_count,
    array_agg(id) as so_ids,
    array_agg(sale_order_no) as so_numbers
FROM "SalesOrders"
WHERE deleted = false
GROUP BY organization_id, quote_id
HAVING COUNT(*) > 1;

-- Query 3: SalesOrders without sale_order_no (must return 0 rows)
SELECT 
    'VERIFICATION 3: SalesOrders without sale_order_no' as check_name,
    id,
    sale_order_no,
    quote_id,
    organization_id,
    created_at
FROM "SalesOrders"
WHERE deleted = false
AND (sale_order_no IS NULL OR sale_order_no = '');

-- Query 4: Summary
SELECT 
    'VERIFICATION 4: Summary' as check_name,
    COUNT(DISTINCT q.id) FILTER (WHERE q.status::text ILIKE 'approved') as total_approved,
    COUNT(DISTINCT so.id) FILTER (WHERE q.status::text ILIKE 'approved') as approved_with_so,
    COUNT(DISTINCT q.id) FILTER (
        WHERE q.status::text ILIKE 'approved' AND so.id IS NULL
    ) as approved_without_so,
    CASE 
        WHEN COUNT(DISTINCT q.id) FILTER (
            WHERE q.status::text ILIKE 'approved' AND so.id IS NULL
        ) = 0 THEN '✅ All approved quotes have SalesOrders'
        ELSE '❌ Some approved quotes are missing SalesOrders'
    END as overall_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.deleted = false;

