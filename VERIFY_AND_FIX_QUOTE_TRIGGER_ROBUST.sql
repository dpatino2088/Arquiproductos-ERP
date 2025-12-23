-- ====================================================
-- Script Robusto para Verificar y Corregir Trigger de Quote Approved
-- ====================================================
-- Este script verifica que el trigger funcione correctamente
-- y crea Sales Orders cuando se aprueba un Quote
-- ====================================================

-- ====================================================
-- STEP 1: Verificar estado actual del trigger
-- ====================================================

DO $$
DECLARE
    v_function_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Verificando trigger de Quote Approved...';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Verificar si la función existe
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'on_quote_approved_create_operational_docs'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Función on_quote_approved_create_operational_docs existe';
    ELSE
        RAISE WARNING '❌ Función on_quote_approved_create_operational_docs NO existe';
    END IF;
    
    -- Verificar si el trigger existe y está activo
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        AND t.tgenabled = 'O'  -- 'O' = enabled
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs existe y está ACTIVO';
    ELSE
        -- Verificar si existe pero está deshabilitado
        SELECT EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'Quotes'
            AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        ) INTO v_trigger_enabled;
        
        IF v_trigger_enabled THEN
            RAISE WARNING '⚠️ Trigger existe pero está DESHABILITADO';
        ELSE
            RAISE WARNING '❌ Trigger trg_on_quote_approved_create_operational_docs NO existe';
        END IF;
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: Recrear función con lógica robusta
-- ====================================================

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
    
    -- Get quote record with error handling
    BEGIN
        SELECT * INTO STRICT v_quote_record
        FROM "Quotes"
        WHERE id = NEW.id
        AND deleted = false;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE WARNING '⚠️ Quote % not found or deleted', NEW.id;
            RETURN NEW;
        WHEN TOO_MANY_ROWS THEN
            RAISE WARNING '⚠️ Multiple quotes found with id %', NEW.id;
            RETURN NEW;
    END;
    
    -- Validate required fields
    IF v_quote_record.organization_id IS NULL THEN
        RAISE WARNING '⚠️ Quote % has no organization_id, cannot create Sales Order', NEW.id;
        RETURN NEW;
    END IF;
    
    IF v_quote_record.customer_id IS NULL THEN
        RAISE WARNING '⚠️ Quote % has no customer_id, cannot create Sales Order', NEW.id;
        RETURN NEW;
    END IF;
    
    -- Calculate totals
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    
    -- Check if SalesOrder already exists (FIXED: Use "SalesOrders" plural)
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⏭️ SalesOrder % already exists for Quote %, skipping creation', v_sale_order_id, NEW.id;
        RETURN NEW;
    END IF;
    
    -- Generate sale_order_no with robust fallback logic
    BEGIN
        -- Try get_next_document_number first (most common)
        IF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_document_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_document_number(v_quote_record.organization_id, 'SO') INTO v_sale_order_no;
            IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
                RAISE WARNING '⚠️ get_next_document_number returned NULL, using fallback';
                v_sale_order_no := NULL; -- Will trigger fallback
            END IF;
        END IF;
        
        -- Try get_next_sequential_number if first method failed
        IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
            IF EXISTS (
                SELECT 1 FROM pg_proc 
                WHERE proname = 'get_next_sequential_number' 
                AND pronamespace = 'public'::regnamespace
            ) THEN
                SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
                IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
                    RAISE WARNING '⚠️ get_next_sequential_number returned NULL, using manual fallback';
                    v_sale_order_no := NULL; -- Will trigger fallback
                END IF;
            END IF;
        END IF;
        
        -- Fallback: manual generation
        IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
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
            RAISE NOTICE '📝 Generated sale_order_no manually: %', v_sale_order_no;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '⚠️ Error generating sale_order_no: %, using manual fallback', SQLERRM;
            -- Last resort: use timestamp-based number
            SELECT COALESCE(MAX((regexp_match(sale_order_no, 'SO-(\d+)'))[1]::integer), 0) + 1
            INTO v_next_number
            FROM "SalesOrders"
            WHERE organization_id = v_quote_record.organization_id
            AND deleted = false;
            v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
    END;
    
    -- Create SalesOrder with status 'Draft' and order_progress_status 'approved_awaiting_confirmation'
    BEGIN
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
        
        RAISE NOTICE '✅ Created SalesOrder % (% with status = Draft, order_progress_status = approved_awaiting_confirmation)', v_sale_order_id, v_sale_order_no;
    EXCEPTION
        WHEN unique_violation THEN
            RAISE WARNING '⚠️ SalesOrder with number % already exists, skipping', v_sale_order_no;
            RETURN NEW;
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error creating SalesOrder: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            RETURN NEW;
    END;
    
    -- Step B: For each QuoteLine, find or create SalesOrderLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        BEGIN
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
                    COALESCE(NEW.created_by, auth.uid()),
                    COALESCE(NEW.updated_by, auth.uid())
                ) RETURNING id INTO v_sale_order_line_id;
                
                RAISE NOTICE '✅ Created SalesOrderLine % for QuoteLine %', v_sale_order_line_id, v_quote_line_record.id;
            ELSE
                RAISE NOTICE '⏭️ SalesOrderLine already exists for QuoteLine %', v_quote_line_record.id;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error creating SalesOrderLine for QuoteLine %: %', v_quote_line_record.id, SQLERRM;
                -- Continue with next line
        END;
    END LOOP;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: % (SQLSTATE: %)', NEW.id, SQLERRM, SQLSTATE;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
'Creates SalesOrder with status Draft and order_progress_status approved_awaiting_confirmation when Quote is approved. Also creates SalesOrderLines. Uses robust error handling and fallback logic for number generation. Uses "SalesOrders" and "SalesOrderLines" (plural) table names.';

-- ====================================================
-- STEP 3: Asegurar que el trigger existe y está activo
-- ====================================================

DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

COMMENT ON TRIGGER trg_on_quote_approved_create_operational_docs ON "Quotes" IS 
'Automatically creates SalesOrder when Quote status changes to approved. Trigger is active and fires on status change to approved.';

-- ====================================================
-- STEP 4: Verificación final
-- ====================================================

DO $$
DECLARE
    v_function_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Verificación Final';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Verificar función
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'on_quote_approved_create_operational_docs'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Función on_quote_approved_create_operational_docs existe';
    ELSE
        RAISE WARNING '❌ Función on_quote_approved_create_operational_docs NO existe';
    END IF;
    
    -- Verificar trigger
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        AND t.tgenabled = 'O'  -- 'O' = enabled
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs existe y está ACTIVO';
    ELSE
        RAISE WARNING '❌ Trigger trg_on_quote_approved_create_operational_docs NO existe o NO está activo';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Script completado';
    RAISE NOTICE '====================================================';
END;
$$;

-- ====================================================
-- STEP 5: Verificar Quotes aprobados sin Sales Orders
-- ====================================================

SELECT 
    'Quotes sin Sales Orders' as tipo,
    COUNT(DISTINCT q.id) as quotes_aprobados_sin_so,
    STRING_AGG(q.quote_no, ', ' ORDER BY q.created_at) as quote_numbers
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
AND so.id IS NULL;

