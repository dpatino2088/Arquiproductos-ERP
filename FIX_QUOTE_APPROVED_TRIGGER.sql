-- ====================================================
-- Reparar Trigger de Quote Approved → Sales Order
-- ====================================================
-- Este script verifica y repara el trigger que crea Sales Orders
-- cuando un Quote se aprueba, sin afectar el BOM que ya funciona
-- ====================================================

-- ====================================================
-- STEP 1: Verificar estado actual
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Verificando trigger de Quote Approved...';
    RAISE NOTICE '====================================================';
    
    -- Verificar si la función existe
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Función on_quote_approved_create_operational_docs existe';
    ELSE
        RAISE NOTICE '❌ Función on_quote_approved_create_operational_docs NO existe';
    END IF;
    
    -- Verificar si el trigger existe
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs existe';
    ELSE
        RAISE NOTICE '❌ Trigger trg_on_quote_approved_create_operational_docs NO existe';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Recrear función con nombres correctos (SalesOrders plural)
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
    
    -- Check if SaleOrder already exists (FIXED: Use "SalesOrders" plural)
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Generate sale_order_no with fallback logic
        -- Try get_next_document_number first (most common)
        IF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_document_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_document_number(v_quote_record.organization_id, 'SO') INTO v_sale_order_no;
        -- Try get_next_sequential_number
        ELSIF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_sequential_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
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
        END IF;
        
        -- Create SaleOrder with status 'Draft' and order_progress_status 'approved_awaiting_confirmation'
        -- FIXED: Use "SalesOrders" plural
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
        
        RAISE NOTICE '✅ Created SaleOrder % (% with status = Draft, order_progress_status = approved_awaiting_confirmation)', v_sale_order_id, v_sale_order_no;
    ELSE
        -- Update existing SaleOrder to ensure status and order_progress_status are set
        -- FIXED: Use "SalesOrders" plural
        UPDATE "SalesOrders"
        SET status = COALESCE(NULLIF(status, ''), 'Draft'),
            order_progress_status = COALESCE(order_progress_status, 'approved_awaiting_confirmation'),
            updated_at = now()
        WHERE id = v_sale_order_id
        AND (status IS NULL OR status = '' OR LOWER(status) = 'draft' OR status != 'Draft');
        
        RAISE NOTICE '⏭️  SaleOrder % already exists for Quote %, updated status if needed', v_sale_order_id, NEW.id;
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
            
            -- Create SaleOrderLine (FIXED: Use "SalesOrderLines" plural)
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
            
            RAISE NOTICE '✅ Created SaleOrderLine % for QuoteLine %', v_sale_order_line_id, v_quote_line_record.id;
        END IF;
    END LOOP;
    
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
'Creates SalesOrder with status Draft and order_progress_status approved_awaiting_confirmation when Quote is approved. Also creates SalesOrderLines. Uses "SalesOrders" (plural) table name. Does NOT create BOM or Manufacturing Order.';

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
'Automatically creates SalesOrder when Quote status changes to approved. Uses "SalesOrders" (plural) table name.';

-- ====================================================
-- STEP 4: Verificación final
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Trigger reparado exitosamente!';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Verificando estado final...';
    
    -- Verificar función
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Función existe y está activa';
    ELSE
        RAISE WARNING '❌ Función NO existe después de la reparación';
    END IF;
    
    -- Verificar trigger
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Trigger existe y está activo';
    ELSE
        RAISE WARNING '❌ Trigger NO existe después de la reparación';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'El trigger ahora creará Sales Orders cuando un Quote se apruebe.';
    RAISE NOTICE 'NO afecta el BOM que ya funciona.';
END;
$$;






