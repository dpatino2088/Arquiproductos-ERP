-- ====================================================
-- Fix ManufacturingOrder Number Generation in Trigger
-- ====================================================
-- This updates the trigger function to use get_next_document_number
-- if available, with proper fallbacks
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_manufacturing_order_no text;
    v_manufacturing_order_id uuid;
    v_next_number integer;
    v_last_order_no text;
BEGIN
    -- Only process when status changes to 'Confirmed'
    IF NEW.status != 'Confirmed' OR OLD.status = 'Confirmed' THEN
        RETURN NEW;
    END IF;
    
    -- Check if ManufacturingOrder already exists for this SaleOrder
    SELECT id INTO v_manufacturing_order_id
    FROM "ManufacturingOrders"
    WHERE sale_order_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⏭️  ManufacturingOrder already exists for SaleOrder %, skipping creation', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 SaleOrder % status changed to Confirmed, creating ManufacturingOrder', NEW.id;
    
    -- Generate manufacturing_order_no (try get_next_document_number first, then fallback)
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_document_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_document_number(NEW.organization_id, 'MO') INTO v_manufacturing_order_no;
        RAISE NOTICE '   Using get_next_document_number: %', v_manufacturing_order_no;
    ELSIF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_sequential_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_sequential_number('ManufacturingOrders', 'manufacturing_order_no', 'MO-')
        INTO v_manufacturing_order_no;
        RAISE NOTICE '   Using get_next_sequential_number: %', v_manufacturing_order_no;
    ELSE
        -- Fallback: manual generation
        SELECT manufacturing_order_no INTO v_last_order_no
        FROM "ManufacturingOrders"
        WHERE organization_id = NEW.organization_id
        AND deleted = false
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_last_order_no IS NULL THEN
            v_next_number := 1;
        ELSE
            v_next_number := COALESCE(
                (SELECT (regexp_match(v_last_order_no, 'MO-(\d+)'))[1]::integer),
                0
            ) + 1;
        END IF;
        
        v_manufacturing_order_no := 'MO-' || LPAD(v_next_number::text, 6, '0');
        RAISE NOTICE '   Using manual generation: %', v_manufacturing_order_no;
    END IF;
    
    -- Create ManufacturingOrder with status 'planned'
    INSERT INTO "ManufacturingOrders" (
        organization_id,
        sale_order_id,
        manufacturing_order_no,
        status,
        created_by,
        updated_by
    ) VALUES (
        NEW.organization_id,
        NEW.id,
        v_manufacturing_order_no,
        'planned',
        NEW.updated_by,
        NEW.updated_by
    ) RETURNING id INTO v_manufacturing_order_id;
    
    RAISE NOTICE '✅ Created ManufacturingOrder % (%) for SaleOrder %', v_manufacturing_order_id, v_manufacturing_order_no, NEW.id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_sale_order_confirmed_create_manufacturing_order for SaleOrder %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_sale_order_confirmed_create_manufacturing_order IS 
'Automatically creates a ManufacturingOrder (Order List) when SaleOrder.status changes to Confirmed. Sets ManufacturingOrder.status to planned. Uses get_next_document_number if available, with fallbacks.';








