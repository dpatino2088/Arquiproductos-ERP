-- ============================================================================
-- Notify Procurement when MO is marked as Confirmed (Reviewed).
-- Also notifies admin/superadmin as secondary observers.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.trg_notify_manufacturing_orders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_auth_user_id uuid := auth.uid();
  v_mo_no text;
BEGIN
  v_mo_no := COALESCE(NEW.manufacturing_order_no, NEW.id::text);

  IF TG_OP = 'INSERT' THEN
    -- MO created → Operator Manager
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
      format('Manufacturing order %s was created.', v_mo_no),
      jsonb_build_object('status', NEW.status, 'manufacturing_order_no', v_mo_no),
      v_actor_auth_user_id
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN

    -- ── MO moved to Confirmed (Reviewed) → notify Procurement ──────────────
    IF NEW.status::text = 'confirmed' AND OLD.status::text <> 'confirmed' THEN
      PERFORM public.enqueue_notification_for_roles(
        NEW.organization_id,
        NULL,                       -- org-wide, not dealer-scoped
        'org',
        ARRAY['procurement', 'admin', 'superadmin'],
        'manufacturing.mo.confirmed',
        'manufacturing',
        'manufacturing_order',
        NEW.id,
        'MO Ready for Procurement',
        format(
          'Manufacturing order %s has been reviewed and is pending material purchase.',
          v_mo_no
        ),
        jsonb_build_object(
          'from_status',             OLD.status,
          'to_status',               NEW.status,
          'manufacturing_order_no',  v_mo_no,
          'sales_order_id',          NEW.sales_order_id
        ),
        v_actor_auth_user_id
      );
    END IF;

    -- ── Any MO status change → Operator Manager ────────────────────────────
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
        v_mo_no,
        COALESCE(OLD.status::text, 'n/a'),
        COALESCE(NEW.status::text, 'n/a')
      ),
      jsonb_build_object(
        'from_status',            OLD.status,
        'to_status',              NEW.status,
        'manufacturing_order_no', v_mo_no
      ),
      v_actor_auth_user_id
    );

  END IF;

  RETURN NEW;
END;
$$;

-- Re-attach trigger (idempotent)
DROP TRIGGER IF EXISTS trg_notify_manufacturing_orders ON public."ManufacturingOrders";
CREATE TRIGGER trg_notify_manufacturing_orders
AFTER INSERT OR UPDATE OF status ON public."ManufacturingOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_manufacturing_orders();
