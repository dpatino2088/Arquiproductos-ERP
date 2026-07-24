-- Auto-archive Sales Order (+ linked Quote + Proposals) when BOTH:
--   1) SO status is delivered / closed / completed
--   2) Financial summary says delivery_financials_ok (paid + fully invoiced)
--
-- Hooks both sides of the race (delivery before pay, or pay before delivery):
--   - AFTER UPDATE OF status on SalesOrders
--   - AFTER INSERT on PaymentApplications

CREATE OR REPLACE FUNCTION public.maybe_auto_archive_fulfilled_sales_order(p_so_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_so record;
  v_paid boolean := false;
  v_quote_id uuid;
  v_archived_so boolean := false;
  v_archived_quote boolean := false;
  v_archived_proposals int := 0;
BEGIN
  IF p_so_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'so_id required');
  END IF;

  SELECT id, organization_id, quote_id, status::text AS status, COALESCE(archived, false) AS archived
  INTO v_so
  FROM "SalesOrders"
  WHERE id = p_so_id
    AND COALESCE(deleted, false) = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'SO not found');
  END IF;

  IF v_so.archived THEN
    RETURN jsonb_build_object('ok', true, 'already_archived', true);
  END IF;

  IF lower(v_so.status) NOT IN ('delivered', 'closed', 'completed') THEN
    RETURN jsonb_build_object('ok', true, 'skipped', 'not_delivered', 'status', v_so.status);
  END IF;

  SELECT COALESCE(s.delivery_financials_ok, false)
  INTO v_paid
  FROM sales_order_financial_summary s
  WHERE s.sales_order_id = p_so_id;

  IF NOT COALESCE(v_paid, false) THEN
    RETURN jsonb_build_object('ok', true, 'skipped', 'not_paid');
  END IF;

  UPDATE "SalesOrders"
  SET archived = true,
      updated_at = now()
  WHERE id = p_so_id
    AND COALESCE(archived, false) = false;
  v_archived_so := FOUND;

  v_quote_id := v_so.quote_id;
  IF v_quote_id IS NOT NULL THEN
    UPDATE "Quotes"
    SET archived = true,
        updated_at = now()
    WHERE id = v_quote_id
      AND COALESCE(deleted, false) = false
      AND COALESCE(archived, false) = false;
    v_archived_quote := FOUND;

    UPDATE "Proposals"
    SET archived = true,
        updated_at = now()
    WHERE quote_id = v_quote_id
      AND COALESCE(deleted, false) = false
      AND COALESCE(archived, false) = false;
    GET DIAGNOSTICS v_archived_proposals = ROW_COUNT;
  END IF;

  IF v_archived_so THEN
    BEGIN
      INSERT INTO public."ActivityTimeline" (
        organization_id, entity_type, entity_id, action, description, user_id, user_name, metadata
      ) VALUES (
        v_so.organization_id,
        'sales_order',
        p_so_id,
        'archived',
        'Auto-archived: delivered and paid',
        '00000000-0000-0000-0000-000000000000',
        'System',
        jsonb_build_object(
          'source', 'maybe_auto_archive_fulfilled_sales_order',
          'quote_id', v_quote_id,
          'archived_quote', v_archived_quote,
          'archived_proposals', v_archived_proposals
        )
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'archived_so', v_archived_so,
    'archived_quote', v_archived_quote,
    'archived_proposals', v_archived_proposals
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.maybe_auto_archive_fulfilled_sales_order(uuid) TO authenticated;

-- When SO reaches delivered (or closed/completed), try archive if already paid.
CREATE OR REPLACE FUNCTION public.trg_so_status_maybe_auto_archive()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.status IS DISTINCT FROM OLD.status
     AND lower(NEW.status::text) IN ('delivered', 'closed', 'completed')
     AND COALESCE(NEW.archived, false) = false
  THEN
    PERFORM public.maybe_auto_archive_fulfilled_sales_order(NEW.id);
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_so_status_maybe_auto_archive ON public."SalesOrders";
CREATE TRIGGER trg_so_status_maybe_auto_archive
  AFTER UPDATE OF status ON public."SalesOrders"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_so_status_maybe_auto_archive();

-- When a payment is applied, try archive if SO already delivered.
CREATE OR REPLACE FUNCTION public.trg_payment_app_maybe_auto_archive_so()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_so_id uuid;
BEGIN
  SELECT di.sales_order_id
  INTO v_so_id
  FROM public."DealerInvoices" di
  WHERE di.id = NEW.invoice_id;

  IF v_so_id IS NOT NULL THEN
    PERFORM public.maybe_auto_archive_fulfilled_sales_order(v_so_id);
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_payment_app_maybe_auto_archive_so ON public."PaymentApplications";
CREATE TRIGGER trg_payment_app_maybe_auto_archive_so
  AFTER INSERT ON public."PaymentApplications"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_payment_app_maybe_auto_archive_so();

-- One-time backfill for already fulfilled orders.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT so.id
    FROM "SalesOrders" so
    JOIN sales_order_financial_summary s ON s.sales_order_id = so.id
    WHERE COALESCE(so.deleted, false) = false
      AND COALESCE(so.archived, false) = false
      AND so.status::text IN ('delivered', 'closed', 'completed')
      AND COALESCE(s.delivery_financials_ok, false) = true
  LOOP
    PERFORM public.maybe_auto_archive_fulfilled_sales_order(r.id);
  END LOOP;
END $$;
