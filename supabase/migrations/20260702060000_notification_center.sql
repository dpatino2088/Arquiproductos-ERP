-- Notification center: role-routed, persistent bell notifications.

CREATE TABLE IF NOT EXISTS public."UserNotifications" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  dealer_id uuid NULL,
  recipient_auth_user_id uuid NOT NULL,
  recipient_app_user_id uuid NULL REFERENCES public."AppUsers"(id) ON DELETE SET NULL,
  event_code text NOT NULL,
  module text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_recipient_created
  ON public."UserNotifications"(recipient_auth_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_unread
  ON public."UserNotifications"(recipient_auth_user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_entity
  ON public."UserNotifications"(entity_type, entity_id);

ALTER TABLE public."UserNotifications" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user notifications select own" ON public."UserNotifications";
CREATE POLICY "user notifications select own"
ON public."UserNotifications"
FOR SELECT
USING (recipient_auth_user_id = auth.uid());

DROP POLICY IF EXISTS "user notifications update own" ON public."UserNotifications";
CREATE POLICY "user notifications update own"
ON public."UserNotifications"
FOR UPDATE
USING (recipient_auth_user_id = auth.uid())
WITH CHECK (recipient_auth_user_id = auth.uid());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'UserNotifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public."UserNotifications";
  END IF;
END$$;

CREATE OR REPLACE FUNCTION public.enqueue_notification_for_roles(
  p_org_id uuid,
  p_dealer_id uuid,
  p_user_type text,
  p_role_codes text[],
  p_event_code text,
  p_module text,
  p_entity_type text,
  p_entity_id uuid,
  p_title text,
  p_message text,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_exclude_auth_user_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  IF p_org_id IS NULL OR COALESCE(array_length(p_role_codes, 1), 0) = 0 THEN
    RETURN 0;
  END IF;

  WITH recipients AS (
    SELECT
      au.id AS app_user_id,
      au.auth_user_id
    FROM public."AppUsers" au
    WHERE au.organization_id = p_org_id
      AND au.user_type = p_user_type
      AND au.role_code = ANY(p_role_codes)
      AND COALESCE(au.deleted, false) = false
      AND au.status IN ('active', 'invited')
      AND au.auth_user_id IS NOT NULL
      AND (p_dealer_id IS NULL OR au.dealer_id = p_dealer_id)
      AND (p_exclude_auth_user_id IS NULL OR au.auth_user_id <> p_exclude_auth_user_id)
  )
  INSERT INTO public."UserNotifications" (
    organization_id,
    dealer_id,
    recipient_auth_user_id,
    recipient_app_user_id,
    event_code,
    module,
    entity_type,
    entity_id,
    title,
    message,
    payload
  )
  SELECT
    p_org_id,
    p_dealer_id,
    r.auth_user_id,
    r.app_user_id,
    p_event_code,
    p_module,
    p_entity_type,
    p_entity_id,
    p_title,
    p_message,
    COALESCE(p_payload, '{}'::jsonb)
  FROM recipients r;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_notify_sales_orders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_auth_user_id uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- SO created -> Sales Coordinator
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NEW.dealer_id,
      'org',
      ARRAY['sales_coordinator'],
      'sales.order.created',
      'sales',
      'sales_order',
      NEW.id,
      'New Sales Order',
      format('Sales order %s was created.', COALESCE(NEW.sales_order_no, NEW.id::text)),
      jsonb_build_object('status', NEW.status, 'sales_order_no', NEW.sales_order_no),
      v_actor_auth_user_id
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- SO status changed -> Dealer users (manager/member)
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NEW.dealer_id,
      'dealer',
      ARRAY['dealer_manager', 'dealer_member'],
      'sales.order.status_changed',
      'sales',
      'sales_order',
      NEW.id,
      'Order Status Updated',
      format(
        'Sales order %s changed from %s to %s.',
        COALESCE(NEW.sales_order_no, NEW.id::text),
        COALESCE(OLD.status::text, 'n/a'),
        COALESCE(NEW.status::text, 'n/a')
      ),
      jsonb_build_object(
        'from_status', OLD.status,
        'to_status', NEW.status,
        'sales_order_no', NEW.sales_order_no
      ),
      v_actor_auth_user_id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_sales_orders ON public."SalesOrders";
CREATE TRIGGER trg_notify_sales_orders
AFTER INSERT OR UPDATE OF status ON public."SalesOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_sales_orders();

CREATE OR REPLACE FUNCTION public.trg_notify_manufacturing_orders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_auth_user_id uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- MO created -> Operator Manager (operator_admin)
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NEW.dealer_id,
      'org',
      ARRAY['operator_admin'],
      'manufacturing.mo.created',
      'manufacturing',
      'manufacturing_order',
      NEW.id,
      'New Manufacturing Order',
      format('Manufacturing order %s was created.', COALESCE(NEW.manufacturing_order_no, NEW.id::text)),
      jsonb_build_object('status', NEW.status, 'manufacturing_order_no', NEW.manufacturing_order_no),
      v_actor_auth_user_id
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- MO status changed -> Operator Manager
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NEW.dealer_id,
      'org',
      ARRAY['operator_admin'],
      'manufacturing.mo.status_changed',
      'manufacturing',
      'manufacturing_order',
      NEW.id,
      'MO Status Updated',
      format(
        'Manufacturing order %s changed from %s to %s.',
        COALESCE(NEW.manufacturing_order_no, NEW.id::text),
        COALESCE(OLD.status::text, 'n/a'),
        COALESCE(NEW.status::text, 'n/a')
      ),
      jsonb_build_object(
        'from_status', OLD.status,
        'to_status', NEW.status,
        'manufacturing_order_no', NEW.manufacturing_order_no
      ),
      v_actor_auth_user_id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_manufacturing_orders ON public."ManufacturingOrders";
CREATE TRIGGER trg_notify_manufacturing_orders
AFTER INSERT OR UPDATE OF status ON public."ManufacturingOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_manufacturing_orders();

CREATE OR REPLACE FUNCTION public.trg_notify_purchase_orders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_auth_user_id uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- PO created -> Procurement
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NULL,
      'org',
      ARRAY['procurement'],
      'procurement.po.created',
      'procurement',
      'purchase_order',
      NEW.id,
      'New Purchase Order',
      format('Purchase order %s was created.', COALESCE(NEW.po_number, NEW.id::text)),
      jsonb_build_object('status', NEW.status, 'po_number', NEW.po_number),
      v_actor_auth_user_id
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- PO status changed -> Procurement
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NULL,
      'org',
      ARRAY['procurement'],
      'procurement.po.status_changed',
      'procurement',
      'purchase_order',
      NEW.id,
      'PO Status Updated',
      format(
        'Purchase order %s changed from %s to %s.',
        COALESCE(NEW.po_number, NEW.id::text),
        COALESCE(OLD.status::text, 'n/a'),
        COALESCE(NEW.status::text, 'n/a')
      ),
      jsonb_build_object('from_status', OLD.status, 'to_status', NEW.status, 'po_number', NEW.po_number),
      v_actor_auth_user_id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_purchase_orders ON public."PurchaseOrders";
CREATE TRIGGER trg_notify_purchase_orders
AFTER INSERT OR UPDATE OF status ON public."PurchaseOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_purchase_orders();

CREATE OR REPLACE FUNCTION public.trg_notify_dealer_invoices()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_auth_user_id uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Invoice created -> Finance + Dealer users
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NULL,
      'org',
      ARRAY['finance'],
      'financials.invoice.created',
      'financials',
      'dealer_invoice',
      NEW.id,
      'New Invoice',
      format('Invoice %s was created.', COALESCE(NEW.invoice_number, NEW.id::text)),
      jsonb_build_object('status', NEW.status, 'invoice_number', NEW.invoice_number),
      v_actor_auth_user_id
    );

    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NEW.dealer_id,
      'dealer',
      ARRAY['dealer_manager', 'dealer_member'],
      'financials.invoice.created',
      'financials',
      'dealer_invoice',
      NEW.id,
      'New Invoice',
      format('Invoice %s was issued for your account.', COALESCE(NEW.invoice_number, NEW.id::text)),
      jsonb_build_object('status', NEW.status, 'invoice_number', NEW.invoice_number),
      v_actor_auth_user_id
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- Invoice status changed -> Finance + Dealer users
    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NULL,
      'org',
      ARRAY['finance'],
      'financials.invoice.status_changed',
      'financials',
      'dealer_invoice',
      NEW.id,
      'Invoice Status Updated',
      format(
        'Invoice %s changed from %s to %s.',
        COALESCE(NEW.invoice_number, NEW.id::text),
        COALESCE(OLD.status::text, 'n/a'),
        COALESCE(NEW.status::text, 'n/a')
      ),
      jsonb_build_object('from_status', OLD.status, 'to_status', NEW.status, 'invoice_number', NEW.invoice_number),
      v_actor_auth_user_id
    );

    PERFORM public.enqueue_notification_for_roles(
      NEW.organization_id,
      NEW.dealer_id,
      'dealer',
      ARRAY['dealer_manager', 'dealer_member'],
      'financials.invoice.status_changed',
      'financials',
      'dealer_invoice',
      NEW.id,
      'Invoice Status Updated',
      format(
        'Invoice %s changed from %s to %s.',
        COALESCE(NEW.invoice_number, NEW.id::text),
        COALESCE(OLD.status::text, 'n/a'),
        COALESCE(NEW.status::text, 'n/a')
      ),
      jsonb_build_object('from_status', OLD.status, 'to_status', NEW.status, 'invoice_number', NEW.invoice_number),
      v_actor_auth_user_id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_dealer_invoices ON public."DealerInvoices";
CREATE TRIGGER trg_notify_dealer_invoices
AFTER INSERT OR UPDATE OF status ON public."DealerInvoices"
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_dealer_invoices();
