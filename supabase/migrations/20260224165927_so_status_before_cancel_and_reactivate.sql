-- Store status before cancel so org users can reactivate SO to previous state.
SET search_path = public;

ALTER TABLE public."SalesOrders"
  ADD COLUMN IF NOT EXISTS status_before_cancel text;

COMMENT ON COLUMN public."SalesOrders".status_before_cancel IS 'Set when status changes to cancelled; used to restore on reactivate (org user only).';

-- Update transition_so_status: save status on cancel; allow reactivate from cancelled to status_before_cancel (or draft).
CREATE OR REPLACE FUNCTION public.transition_so_status(p_so_id uuid, p_new_status text, p_user_id uuid, p_user_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_so record;
  v_valid boolean := false;
  v_old text;
  v_restore text;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_so_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'SO not found'; END IF;
  v_old := v_so.status::text;

  -- Normal transitions (unchanged)
  v_valid := (v_old = 'draft' AND p_new_status = 'confirmed')
          OR (v_old = 'confirmed' AND p_new_status = 'on_hold')
          OR (v_old = 'on_hold' AND p_new_status = 'confirmed')
          OR (v_old = 'confirmed' AND p_new_status = 'delivered')
          OR (v_old = 'delivered' AND p_new_status = 'closed')
          OR (v_old IN ('draft','confirmed','on_hold') AND p_new_status = 'cancelled');

  -- Reactivate: cancelled -> previous state (status_before_cancel) or draft
  IF NOT v_valid AND v_old = 'cancelled' THEN
    v_restore := COALESCE(NULLIF(TRIM(v_so.status_before_cancel), ''), 'draft');
    IF p_new_status = v_restore AND v_restore IN ('draft', 'confirmed', 'on_hold') THEN
      v_valid := true;
    END IF;
  END IF;

  IF NOT v_valid THEN RAISE EXCEPTION 'Invalid SO transition: % -> %', v_old, p_new_status; END IF;

  IF v_old = 'cancelled' THEN
    -- Reactivate: set status to restored, clear status_before_cancel
    UPDATE "SalesOrders" SET
      status = p_new_status::sales_order_status,
      status_before_cancel = NULL,
      updated_at = now()
    WHERE id = p_so_id;
  ELSIF p_new_status = 'cancelled' THEN
    -- Cancel: save current status for later reactivate
    UPDATE "SalesOrders" SET
      status = 'cancelled'::sales_order_status,
      status_before_cancel = v_old,
      updated_at = now()
    WHERE id = p_so_id;
  ELSE
    UPDATE "SalesOrders" SET
      status = p_new_status::sales_order_status,
      completed_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE completed_at END,
      closed_at = CASE WHEN p_new_status = 'closed' THEN now() ELSE closed_at END,
      updated_at = now()
    WHERE id = p_so_id;
  END IF;

  PERFORM _insert_timeline(v_so.organization_id, 'sales_order', p_so_id, 'status_changed',
    'Status changed from ' || v_old || ' to ' || p_new_status, p_user_id, p_user_name,
    jsonb_build_object('from', v_old, 'to', p_new_status));

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_new_status);
END;
$function$;;
