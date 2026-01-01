-- ====================================================
-- Crear SalesOrders faltantes para Quotes aprobados
-- ====================================================
-- Este script busca quotes aprobados que no tienen SalesOrder
-- y los crea usando la misma lógica del trigger
-- ====================================================

DO $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_next_number integer;
    v_last_order_no text;
    v_quote_line_record RECORD;
    v_line_number integer;
    v_validated_side_channel_type text;
BEGIN
    -- Buscar quotes aprobados sin SalesOrder
    FOR v_quote_record IN
        SELECT 
            q.id,
            q.organization_id,
            q.customer_id,
            q.quote_no,
            q.status,
            q.currency,
            q.totals,
            q.notes,
            q.created_by,
            q.updated_by
        FROM "Quotes" q
        WHERE q.status = 'approved'
        AND q.deleted = false
        AND NOT EXISTS (
            SELECT 1 
            FROM "SalesOrders" so
            WHERE so.quote_id = q.id
            AND so.deleted = false
        )
        ORDER BY q.created_at ASC
    LOOP
        RAISE NOTICE '🔔 Procesando Quote % (%) sin SalesOrder...', v_quote_record.quote_no, v_quote_record.id;
        
        -- Calcular totales
        v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
        v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
        v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
        
        -- Generar sale_order_no
        -- Intentar usar get_next_document_number primero
        IF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_document_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_document_number(v_quote_record.organization_id, 'SO') INTO v_sale_order_no;
        -- Intentar get_next_sequential_number
        ELSIF EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'get_next_sequential_number' 
            AND pronamespace = 'public'::regnamespace
        ) THEN
            SELECT public.get_next_sequential_number('SalesOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
        -- Fallback: generación manual
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
        
        -- Crear SalesOrder
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
            v_quote_record.id,
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
        
        RAISE NOTICE '✅ Creado SalesOrder % (%) para Quote %', v_sale_order_id, v_sale_order_no, v_quote_record.quote_no;
        
        -- Crear SalesOrderLines desde QuoteLines
        v_line_number := 1;
        FOR v_quote_line_record IN
            SELECT 
                ql.id,
                ql.catalog_item_id,
                ql.qty,
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
                ql.cassette,
                ql.cassette_type,
                ql.side_channel,
                ql.side_channel_type,
                ql.hardware_color,
                ql.unit_price_snapshot,
                ql.line_total
            FROM "QuoteLines" ql
            WHERE ql.quote_id = v_quote_record.id
            AND ql.deleted = false
            ORDER BY ql.created_at ASC
        LOOP
            -- Validar side_channel_type
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
            
            -- Crear SalesOrderLine
            INSERT INTO "SalesOrderLines" (
                organization_id,
                sale_order_id,
                quote_line_id,
                catalog_item_id,
                line_number,
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
                created_by,
                updated_by
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.catalog_item_id,
                v_line_number,
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
                COALESCE(v_quote_record.created_by, auth.uid()),
                COALESCE(v_quote_record.updated_by, auth.uid())
            );
            
            v_line_number := v_line_number + 1;
        END LOOP;
        
        RAISE NOTICE '✅ Creadas % líneas para SalesOrder %', v_line_number - 1, v_sale_order_no;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Proceso completado!';
END;
$$;

-- Verificar resultados
SELECT 
    q.quote_no,
    q.status AS quote_status,
    so.sale_order_no,
    so.status AS so_status,
    so.order_progress_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;






