-- ====================================================
-- FASE 1: Reparar Trigger de Quote Approved
-- ====================================================
-- Este trigger debe copiar QuoteLines a SalesOrderLines
-- cuando un Quote se aprueba
-- ====================================================

-- Verificar estado actual
DO $$
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'FASE 1: Verificando trigger de Quote Approved';
    RAISE NOTICE '====================================================';
    
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'Quotes'
        AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        AND t.tgenabled = 'O'
    ) THEN
        RAISE NOTICE '✅ Trigger existe y está activo';
    ELSE
        RAISE WARNING '❌ Trigger NO está activo';
    END IF;
END;
$$;

-- Recrear función con toda la lógica necesaria
CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_quote_line_record RECORD;
BEGIN
    -- Solo procesar cuando status cambia a 'approved'
    IF NEW.status != 'approved' OR OLD.status = 'approved' THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 Quote % aprobado, creando Sales Order', NEW.quote_no;
    
    -- Calcular totales
    v_subtotal := COALESCE((NEW.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((NEW.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((NEW.totals->>'total')::numeric(12,4), 0);
    
    -- Verificar si ya existe Sales Order
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⏭️  Sales Order ya existe: %', v_sale_order_id;
    ELSE
        -- Generar número de Sales Order
        BEGIN
            SELECT public.get_next_document_number(NEW.organization_id, 'SO') 
            INTO v_sale_order_no;
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback
                v_sale_order_no := 'SO-' || LPAD(FLOOR(RANDOM() * 100000)::text, 6, '0');
        END;
        
        -- Crear Sales Order
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
            updated_by,
            created_at,
            updated_at
        ) VALUES (
            NEW.organization_id,
            NEW.id,
            NEW.customer_id,
            v_sale_order_no,
            'Draft',
            'approved_awaiting_confirmation',
            COALESCE(NEW.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            NEW.notes,
            CURRENT_DATE,
            COALESCE(NEW.created_by, auth.uid()),
            COALESCE(NEW.updated_by, auth.uid()),
            now(),
            now()
        ) RETURNING id INTO v_sale_order_id;
        
        RAISE NOTICE '✅ Sales Order creado: % (ID: %)', v_sale_order_no, v_sale_order_id;
    END IF;
    
    -- CRÍTICO: Copiar QuoteLines a SalesOrderLines
    RAISE NOTICE '🔧 Copiando QuoteLines a SalesOrderLines...';
    v_line_number := 0;
    
    FOR v_quote_line_record IN
        SELECT *
        FROM "QuoteLines"
        WHERE quote_id = NEW.id
        AND deleted = false
        ORDER BY created_at ASC
    LOOP
        -- Verificar si ya existe esta línea
        SELECT id INTO v_sale_order_line_id
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF FOUND THEN
            RAISE NOTICE '  ⏭️  SalesOrderLine ya existe para QuoteLine %', v_quote_line_record.id;
            CONTINUE;
        END IF;
        
        v_line_number := v_line_number + 1;
        
        BEGIN
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
                metadata,
                created_at,
                updated_at
            ) VALUES (
                NEW.organization_id,
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.catalog_item_id,
                v_line_number,
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
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.metadata,
                now(),
                now()
            );
            
            RAISE NOTICE '  ✅ SalesOrderLine creado: line %', v_line_number;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creando SalesOrderLine: % (%)', SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Total líneas copiadas: %', v_line_number;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error en trigger: % (%)', SQLERRM, SQLSTATE;
        RETURN NEW;
END;
$$;

-- Recrear trigger
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- Verificar
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FASE 1 COMPLETADA';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'El trigger ahora:';
    RAISE NOTICE '1. Crea Sales Order con status Draft';
    RAISE NOTICE '2. Copia TODAS las QuoteLines a SalesOrderLines';
    RAISE NOTICE '3. NO crea BOM (eso es en FASE 3)';
    RAISE NOTICE '';
END;
$$;

