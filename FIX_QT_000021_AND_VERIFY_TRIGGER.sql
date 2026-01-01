-- ====================================================
-- Script para Corregir QT-000021 y Verificar Trigger
-- ====================================================
-- Este script:
-- 1. Crea el Sales Order faltante para QT-000021
-- 2. Verifica que el trigger esté funcionando correctamente
-- ====================================================

-- ====================================================
-- STEP 1: Verificar estado del trigger
-- ====================================================

DO $$
DECLARE
    v_function_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled text;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Verificando estado del trigger...';
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
    
    -- Verificar trigger y su estado
    SELECT 
        EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'Quotes'
            AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        ),
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM pg_trigger t
                JOIN pg_class c ON t.tgrelid = c.oid
                WHERE c.relname = 'Quotes'
                AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
            ) THEN (
                SELECT CASE t.tgenabled
                    WHEN 'O' THEN 'ENABLED'
                    WHEN 'D' THEN 'DISABLED'
                    WHEN 'R' THEN 'REPLICA'
                    WHEN 'A' THEN 'ALWAYS'
                    ELSE 'UNKNOWN'
                END
                FROM pg_trigger t
                JOIN pg_class c ON t.tgrelid = c.oid
                WHERE c.relname = 'Quotes'
                AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
                LIMIT 1
            )
            ELSE 'NOT FOUND'
        END
    INTO v_trigger_exists, v_trigger_enabled;
    
    IF v_trigger_exists THEN
        IF v_trigger_enabled = 'ENABLED' THEN
            RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs existe y está ACTIVO';
        ELSE
            RAISE WARNING '⚠️ Trigger existe pero está %', v_trigger_enabled;
        END IF;
    ELSE
        RAISE WARNING '❌ Trigger trg_on_quote_approved_create_operational_docs NO existe';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: Crear Sales Order para QT-000021 manualmente
-- ====================================================

DO $$
DECLARE
    v_quote_id uuid;
    v_quote_record record;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_number integer;
    v_last_order_no text;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_quote_line_record record;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Creando Sales Order para QT-000021...';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Buscar Quote QT-000021
    SELECT id INTO v_quote_id
    FROM "Quotes"
    WHERE quote_no = 'QT-000021'
    AND deleted = false
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION '❌ Quote QT-000021 no encontrado';
    END IF;

    RAISE NOTICE '✅ Quote QT-000021 encontrado (ID: %)', v_quote_id;

    -- Verificar si ya tiene Sales Order
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false
    LIMIT 1;

    IF FOUND THEN
        RAISE NOTICE '⏭️ Quote QT-000021 ya tiene Sales Order %', v_sale_order_id;
        RETURN;
    END IF;

    -- Obtener datos del Quote
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_id
    AND deleted = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION '❌ No se pudo obtener datos del Quote QT-000021';
    END IF;

    -- Validar campos requeridos
    IF v_quote_record.organization_id IS NULL THEN
        RAISE EXCEPTION '❌ Quote QT-000021 no tiene organization_id';
    END IF;

    IF v_quote_record.customer_id IS NULL THEN
        RAISE EXCEPTION '❌ Quote QT-000021 no tiene customer_id';
    END IF;

    -- Calcular totales
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);

    -- Generar sale_order_no
    BEGIN
        -- Try get_next_document_number first
        IF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_document_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_document_number(v_quote_record.organization_id, 'SO') INTO v_sale_order_no;
        END IF;
        
        -- Try get_next_sequential_number if first method failed
        IF v_sale_order_no IS NULL OR v_sale_order_no = '' THEN
            IF EXISTS (
                SELECT 1 FROM pg_proc 
                WHERE proname = 'get_next_sequential_number' 
                AND pronamespace = 'public'::regnamespace
            ) THEN
                SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
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
                v_next_number := COALESCE(
                    (SELECT (regexp_match(v_last_order_no, 'SO-(\d+)'))[1]::integer),
                    0
                ) + 1;
            END IF;

            v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '⚠️ Error generando sale_order_no: %, usando fallback', SQLERRM;
            SELECT COALESCE(MAX((regexp_match(sale_order_no, 'SO-(\d+)'))[1]::integer), 0) + 1
            INTO v_next_number
            FROM "SalesOrders"
            WHERE organization_id = v_quote_record.organization_id
            AND deleted = false;
            v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
    END;

    RAISE NOTICE '📝 Sale Order Number generado: %', v_sale_order_no;

    -- Crear SalesOrder
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
        
        RAISE NOTICE '✅ SalesOrder % creado para Quote QT-000021', v_sale_order_id;
    EXCEPTION
        WHEN unique_violation THEN
            RAISE WARNING '⚠️ SalesOrder con número % ya existe', v_sale_order_no;
            RETURN;
        WHEN OTHERS THEN
            RAISE EXCEPTION '❌ Error creando SalesOrder: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
    END;

    -- Crear SalesOrderLines para cada QuoteLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = v_quote_id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        BEGIN
            -- Validar side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;

            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND deleted = false;

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
                COALESCE(v_quote_record.created_by, auth.uid()),
                COALESCE(v_quote_record.updated_by, auth.uid())
            ) RETURNING id INTO v_sale_order_line_id;
            
            RAISE NOTICE '✅ SalesOrderLine % creado para QuoteLine %', v_sale_order_line_id, v_quote_line_record.id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error creando SalesOrderLine para QuoteLine %: %', v_quote_line_record.id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '✅ Proceso completado para QT-000021';
    RAISE NOTICE '====================================================';
END;
$$;

-- ====================================================
-- STEP 3: Verificar que el trigger esté correctamente configurado
-- ====================================================

-- Ejecutar el script VERIFY_AND_FIX_QUOTE_TRIGGER_ROBUST.sql completo
-- para asegurar que el trigger esté funcionando correctamente

-- ====================================================
-- STEP 4: Verificación final
-- ====================================================

SELECT 
    'Verificación Final' as tipo,
    COUNT(DISTINCT q.id) as quotes_aprobados,
    COUNT(DISTINCT so.id) as sales_orders_existentes,
    COUNT(DISTINCT CASE WHEN so.id IS NULL THEN q.id END) as quotes_sin_so,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN so.id IS NULL THEN q.id END) = 0 THEN '✅ Todos los Quotes aprobados tienen Sales Orders'
        ELSE '⚠️ Hay Quotes aprobados sin Sales Orders'
    END as estado
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false;

-- Verificar específicamente QT-000021
SELECT 
    'QT-000021' as quote_no,
    q.id as quote_id,
    q.status as quote_status,
    so.id as sale_order_id,
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN so.id IS NOT NULL THEN '✅ Tiene Sales Order'
        ELSE '❌ Sin Sales Order'
    END as estado
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000021'
AND q.deleted = false;






