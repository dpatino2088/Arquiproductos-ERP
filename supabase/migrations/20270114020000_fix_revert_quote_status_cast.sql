-- Fix: Quotes.status is the enum type quote_status, so COALESCE(status, '')
-- tries to cast '' into the enum and raises 22P02. Cast to text before COALESCE.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.revert_quote_to_draft(
  p_quote_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quote         record;
  v_so_ids        uuid[];
  v_invoice_count int := 0;
  v_paid          numeric := 0;
  v_mo_count      int := 0;
  v_dn_count      int := 0;
BEGIN
  SELECT id, status, organization_id
    INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id
    AND COALESCE(deleted, false) = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found',
      'message', 'Quote not found.');
  END IF;

  IF lower(COALESCE(v_quote.status::text, '')) <> 'approved' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_approved',
      'message', 'Only an approved quote can be reverted to draft.');
  END IF;

  SELECT array_agg(id) INTO v_so_ids
  FROM public."SalesOrders"
  WHERE quote_id = p_quote_id
    AND COALESCE(deleted, false) = false;

  IF v_so_ids IS NOT NULL AND array_length(v_so_ids, 1) > 0 THEN
    SELECT count(*) INTO v_invoice_count
    FROM public."DealerInvoices"
    WHERE sales_order_id = ANY(v_so_ids)
      AND COALESCE(deleted, false) = false
      AND status <> 'void';
    IF v_invoice_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'has_invoice',
        'message', 'Cannot revert: the sales order already has invoices.');
    END IF;

    SELECT COALESCE(sum(pa.applied_amount), 0) INTO v_paid
    FROM public."PaymentApplications" pa
    JOIN public."DealerInvoices" di ON di.id = pa.invoice_id
    WHERE di.sales_order_id = ANY(v_so_ids);
    IF v_paid > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'has_payment',
        'message', 'Cannot revert: payments have been recorded for this order.');
    END IF;

    SELECT count(*) INTO v_mo_count
    FROM public."ManufacturingOrders"
    WHERE sales_order_id = ANY(v_so_ids)
      AND COALESCE(deleted, false) = false;
    IF v_mo_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'has_mo',
        'message', 'Cannot revert: manufacturing orders exist for this order.');
    END IF;

    SELECT count(*) INTO v_dn_count
    FROM public."DeliveryNotes"
    WHERE sales_order_id = ANY(v_so_ids)
      AND COALESCE(deleted, false) = false;
    IF v_dn_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'has_delivery',
        'message', 'Cannot revert: delivery notes exist for this order.');
    END IF;

    UPDATE public."SaleOrderLines"
      SET deleted = true, updated_at = now()
      WHERE sales_order_id = ANY(v_so_ids);

    UPDATE public."SalesOrders"
      SET deleted = true, updated_at = now()
      WHERE id = ANY(v_so_ids);
  END IF;

  UPDATE public."Quotes"
    SET status = 'draft',
        tracking_status = NULL,
        updated_at = now()
    WHERE id = p_quote_id;

  INSERT INTO public."ActivityTimeline" (
    organization_id, entity_type, entity_id, action, description,
    user_id, user_name, metadata
  ) VALUES (
    v_quote.organization_id, 'quote', p_quote_id, 'status_change',
    'Quote reverted from Approved to Draft (mistaken approval)',
    p_user_id, COALESCE(p_user_name, 'System'),
    jsonb_build_object('from', 'approved', 'to', 'draft',
                       'sales_orders_removed', COALESCE(array_length(v_so_ids, 1), 0))
  );

  RETURN jsonb_build_object('ok', true,
    'sales_orders_removed', COALESCE(array_length(v_so_ids, 1), 0));
END;
$$;

NOTIFY pgrst, 'reload schema';
