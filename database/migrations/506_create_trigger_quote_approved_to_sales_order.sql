-- ====================================================
-- Migration: Create trigger Quote approved → SalesOrder
-- ====================================================
-- OBJETIVO: Cuando Quote.status cambia a 'approved':
--   1. Crear SalesOrder
--   2. Crear OrderList
--   3. Set Quote.tracking_status = 'pending_confirmation'
-- ====================================================

BEGIN;

-- Function to handle quote approval
CREATE OR REPLACE FUNCTION public.handle_quote_approved()
RETURNS TRIGGER AS $$
DECLARE
    v_sales_order_id uuid;
    v_sales_order_no text;
    v_quote_no text;
BEGIN
    -- Only process when status changes to 'approved'
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        -- Check if SalesOrder already exists (idempotent)
        SELECT id INTO v_sales_order_id
        FROM public."SalesOrders"
        WHERE quote_id = NEW.id
        AND deleted = false
        LIMIT 1;

        -- If SalesOrder doesn't exist, create it
        IF v_sales_order_id IS NULL THEN
            -- Generate sales_order_no from quote_no
            v_quote_no := NEW.quote_no;
            v_sales_order_no := 'SO-' || v_quote_no || '-' || to_char(now(), 'YYYYMMDD-HH24MISS');

            -- Insert SalesOrder
            INSERT INTO public."SalesOrders" (
                organization_id,
                quote_id,
                sales_order_no,
                tracking_status,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                NEW.organization_id,
                NEW.id,
                v_sales_order_no,
                'pending_confirmation',
                false,
                now(),
                now()
            )
            RETURNING id INTO v_sales_order_id;

            -- Insert OrderList (mirror of SalesOrder)
            INSERT INTO public."OrderList" (
                organization_id,
                sales_order_id,
                tracking_status,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                NEW.organization_id,
                v_sales_order_id,
                'pending_confirmation',
                false,
                now(),
                now()
            );
        END IF;

        -- Update Quote.tracking_status
        NEW.tracking_status := 'pending_confirmation';
    END IF;

    -- If status is NOT 'approved', ensure tracking_status is NULL
    IF NEW.status != 'approved' THEN
        NEW.tracking_status := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trg_quote_approved_to_sales_order ON public."Quotes";
CREATE TRIGGER trg_quote_approved_to_sales_order
    BEFORE UPDATE ON public."Quotes"
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.handle_quote_approved();

-- Add comment
COMMENT ON FUNCTION public.handle_quote_approved() IS 
    'Trigger function: When Quote.status changes to approved, creates SalesOrder and OrderList, and sets Quote.tracking_status to pending_confirmation.';

COMMENT ON TRIGGER trg_quote_approved_to_sales_order ON public."Quotes" IS 
    'Trigger: Automatically creates SalesOrder and OrderList when Quote is approved. Sets Quote.tracking_status.';

COMMIT;
