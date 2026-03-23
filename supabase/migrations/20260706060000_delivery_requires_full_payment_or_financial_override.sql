-- ============================================================================
-- Delivery payment gate: strict 0.00 balance + Financials override
-- ============================================================================
-- 1) Create SalesOrderDeliveryOverrides table
-- 2) Add helper function get_sales_order_delivery_gate
-- 3) Add RPCs authorize/revoke delivery release (admin/superadmin only)
-- 4) Enforce gate in transition_mo_status (delivered)
-- 5) Enforce gate in complete_delivery_note
-- ============================================================================

SET search_path = public;

-- --------------------------------------------------------------------------
-- 1) Overrides table
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public."SalesOrderDeliveryOverrides" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  sales_order_id uuid NOT NULL REFERENCES public."SalesOrders"(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'revoked')),
  reason text NOT NULL,
  authorized_by uuid,
  authorized_by_name text,
  authorized_at timestamptz NOT NULL DEFAULT now(),
  revoked_by uuid,
  revoked_by_name text,
  revoked_reason text,
  revoked_at timestamptz,
  used_by uuid,
  used_by_name text,
  used_source text,
  used_delivery_note_id uuid REFERENCES public."DeliveryNotes"(id),
  used_at timestamptz,
  metadata jsonb,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_so_delivery_overrides_org_status
  ON public."SalesOrderDeliveryOverrides"(organization_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_so_delivery_overrides_so
  ON public."SalesOrderDeliveryOverrides"(sales_order_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_so_delivery_override_active
  ON public."SalesOrderDeliveryOverrides"(sales_order_id)
  WHERE status = 'active' AND deleted = false;

ALTER TABLE public."SalesOrderDeliveryOverrides" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sales_order_delivery_overrides_read_org ON public."SalesOrderDeliveryOverrides";
CREATE POLICY sales_order_delivery_overrides_read_org
ON public."SalesOrderDeliveryOverrides"
FOR SELECT
USING (
  organization_id IN (
    SELECT au.organization_id
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.deleted = false
      AND au.status = 'active'
  )
);

-- --------------------------------------------------------------------------
-- 2) Helper: strict 2-decimal gate for delivery
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_sales_order_delivery_gate(uuid);
CREATE OR REPLACE FUNCTION public.get_sales_order_delivery_gate(p_sales_order_id uuid)
RETURNS TABLE (
  sales_order_id uuid,
  balance_due numeric(14,2),
  payment_complete boolean,
  has_active_override boolean,
  active_override_id uuid,
  delivery_allowed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total numeric(14,2) := 0;
  v_covered numeric(14,2) := 0;
BEGIN
  SELECT COALESCE(so.total_amount, 0)::numeric(14,2)
  INTO v_total
  FROM public."SalesOrders" so
  WHERE so.id = p_sales_order_id
    AND so.deleted = false;

  SELECT COALESCE(SUM(COALESCE(pa.applied_amount, 0) + COALESCE(cn.credited, 0)), 0)::numeric(14,2)
  INTO v_covered
  FROM public."DealerInvoices" di
  LEFT JOIN (
    SELECT invoice_id, SUM(applied_amount)::numeric(14,2) AS applied_amount
    FROM public."PaymentApplications"
    GROUP BY invoice_id
  ) pa ON pa.invoice_id = di.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount)::numeric(14,2) AS credited
    FROM public."DealerCreditNotes"
    WHERE deleted = false AND status <> 'void'
    GROUP BY invoice_id
  ) cn ON cn.invoice_id = di.id
  WHERE di.sales_order_id = p_sales_order_id
    AND di.deleted = false
    AND di.status <> 'void';

  sales_order_id := p_sales_order_id;
  balance_due := GREATEST(ROUND(v_total - v_covered, 2), 0)::numeric(14,2);
  payment_complete := (balance_due = 0);

  SELECT EXISTS (
    SELECT 1
    FROM public."SalesOrderDeliveryOverrides" o
    WHERE o.sales_order_id = p_sales_order_id
      AND o.status = 'active'
      AND o.deleted = false
  )
  INTO has_active_override;

  SELECT o.id
  INTO active_override_id
  FROM public."SalesOrderDeliveryOverrides" o
  WHERE o.sales_order_id = p_sales_order_id
    AND o.status = 'active'
    AND o.deleted = false
  ORDER BY o.created_at DESC
  LIMIT 1;

  delivery_allowed := payment_complete OR has_active_override;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_sales_order_delivery_gate(uuid) TO authenticated;

-- --------------------------------------------------------------------------
-- 3) RPCs: authorize/revoke override
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.authorize_sales_order_delivery_release(uuid, text);
CREATE OR REPLACE FUNCTION public.authorize_sales_order_delivery_release(
  p_sales_order_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid := auth.uid();
  v_so record;
  v_actor record;
  v_existing_active uuid;
  v_inserted_id uuid;
BEGIN
  IF v_auth_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Authentication required');
  END IF;

  IF length(trim(COALESCE(p_reason, ''))) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Reason must be at least 5 characters');
  END IF;

  SELECT so.id, so.organization_id, so.sales_order_no
  INTO v_so
  FROM public."SalesOrders" so
  WHERE so.id = p_sales_order_id
    AND so.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sales order not found');
  END IF;

  SELECT au.id, au.role_code, COALESCE(au.display_name, au.email) AS actor_name
  INTO v_actor
  FROM public."AppUsers" au
  WHERE au.auth_user_id = v_auth_user_id
    AND au.organization_id = v_so.organization_id
    AND au.deleted = false
    AND au.status = 'active'
  LIMIT 1;

  IF NOT FOUND OR v_actor.role_code NOT IN ('admin', 'superadmin') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Only admin or superadmin can authorize delivery release');
  END IF;

  SELECT o.id
  INTO v_existing_active
  FROM public."SalesOrderDeliveryOverrides" o
  WHERE o.sales_order_id = p_sales_order_id
    AND o.status = 'active'
    AND o.deleted = false
  LIMIT 1;

  IF v_existing_active IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'already_active', true,
      'override_id', v_existing_active
    );
  END IF;

  INSERT INTO public."SalesOrderDeliveryOverrides" (
    organization_id,
    sales_order_id,
    status,
    reason,
    authorized_by,
    authorized_by_name
  ) VALUES (
    v_so.organization_id,
    p_sales_order_id,
    'active',
    trim(p_reason),
    v_auth_user_id,
    v_actor.actor_name
  )
  RETURNING id INTO v_inserted_id;

  INSERT INTO public."FinancialAuditLog" (
    organization_id,
    action,
    entity_type,
    entity_id,
    related_entity_type,
    related_entity_id,
    reason,
    performed_by,
    performed_by_name,
    metadata
  ) VALUES (
    v_so.organization_id,
    'authorize_delivery_release',
    'sales_order_delivery_override',
    v_inserted_id,
    'sales_order',
    p_sales_order_id,
    trim(p_reason),
    v_auth_user_id,
    v_actor.actor_name,
    jsonb_build_object('sales_order_no', v_so.sales_order_no)
  );

  RETURN jsonb_build_object('ok', true, 'override_id', v_inserted_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.authorize_sales_order_delivery_release(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.revoke_sales_order_delivery_release(uuid, text);
CREATE OR REPLACE FUNCTION public.revoke_sales_order_delivery_release(
  p_sales_order_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id uuid := auth.uid();
  v_so record;
  v_actor record;
  v_override record;
BEGIN
  IF v_auth_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Authentication required');
  END IF;

  IF length(trim(COALESCE(p_reason, ''))) < 5 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Reason must be at least 5 characters');
  END IF;

  SELECT so.id, so.organization_id, so.sales_order_no
  INTO v_so
  FROM public."SalesOrders" so
  WHERE so.id = p_sales_order_id
    AND so.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sales order not found');
  END IF;

  SELECT au.id, au.role_code, COALESCE(au.display_name, au.email) AS actor_name
  INTO v_actor
  FROM public."AppUsers" au
  WHERE au.auth_user_id = v_auth_user_id
    AND au.organization_id = v_so.organization_id
    AND au.deleted = false
    AND au.status = 'active'
  LIMIT 1;

  IF NOT FOUND OR v_actor.role_code NOT IN ('admin', 'superadmin') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Only admin or superadmin can revoke delivery release');
  END IF;

  SELECT o.*
  INTO v_override
  FROM public."SalesOrderDeliveryOverrides" o
  WHERE o.sales_order_id = p_sales_order_id
    AND o.status = 'active'
    AND o.deleted = false
  ORDER BY o.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No active delivery release override found');
  END IF;

  UPDATE public."SalesOrderDeliveryOverrides"
  SET status = 'revoked',
      revoked_by = v_auth_user_id,
      revoked_by_name = v_actor.actor_name,
      revoked_reason = trim(p_reason),
      revoked_at = now(),
      updated_at = now()
  WHERE id = v_override.id;

  INSERT INTO public."FinancialAuditLog" (
    organization_id,
    action,
    entity_type,
    entity_id,
    related_entity_type,
    related_entity_id,
    reason,
    performed_by,
    performed_by_name,
    metadata
  ) VALUES (
    v_so.organization_id,
    'revoke_delivery_release',
    'sales_order_delivery_override',
    v_override.id,
    'sales_order',
    p_sales_order_id,
    trim(p_reason),
    v_auth_user_id,
    v_actor.actor_name,
    jsonb_build_object('sales_order_no', v_so.sales_order_no)
  );

  RETURN jsonb_build_object('ok', true, 'override_id', v_override.id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.revoke_sales_order_delivery_release(uuid, text) TO authenticated;

-- --------------------------------------------------------------------------
-- 4) Enforce gate in transition_mo_status for "delivered"
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.transition_mo_status(uuid, text, uuid, text);
CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id      uuid,
  p_new_status text,
  p_user_id    uuid,
  p_user_name  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo          record;
  v_from        text;
  v_to          text;
  v_allowed     text[];
  v_readiness   jsonb;
  v_has_shortage boolean;
  v_gate        record;
  v_actor_name  text;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_mo_id AND deleted = false;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_from := COALESCE(v_mo.status::text, 'draft');
  v_to   := lower(trim(p_new_status));
  v_actor_name := COALESCE(NULLIF(trim(p_user_name), ''), 'System');

  v_allowed := CASE v_from
    WHEN 'draft'            THEN ARRAY['confirmed', 'planned', 'procurement', 'materials_ready', 'in_production', 'cancelled']
    WHEN 'confirmed'        THEN ARRAY['procurement', 'materials_ready', 'planned', 'in_production', 'cancelled', 'draft']
    WHEN 'procurement'      THEN ARRAY['materials_ready', 'in_production', 'cancelled', 'confirmed']
    WHEN 'materials_ready'  THEN ARRAY['in_production', 'cancelled']
    WHEN 'planned'          THEN ARRAY['in_production', 'cancelled', 'draft']
    WHEN 'in_production'    THEN ARRAY['quality_check', 'cancelled']
    WHEN 'quality_check'    THEN ARRAY['ready_for_pickup']
    WHEN 'ready_for_pickup' THEN ARRAY['delivered']
    WHEN 'delivered'        THEN ARRAY['completed']
    WHEN 'completed'        THEN ARRAY[]::text[]
    WHEN 'cancelled'        THEN ARRAY['draft']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (v_to = ANY(v_allowed)) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Invalid transition: %s → %s. Allowed: %s', v_from, v_to, array_to_string(v_allowed, ', ')),
      'from', v_from,
      'to', v_to
    );
  END IF;

  IF v_to = 'in_production' THEN
    v_readiness := public.get_mo_material_readiness(p_mo_id);
    v_has_shortage := COALESCE((v_readiness->>'has_shortage')::boolean, false);
    IF v_has_shortage THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Materials incomplete. All materials must be on hand or on order before starting production.',
        'from', v_from,
        'to', v_to,
        'material_readiness', v_readiness
      );
    END IF;
  END IF;

  IF v_to = 'delivered' AND v_mo.sales_order_id IS NOT NULL THEN
    SELECT * INTO v_gate
    FROM public.get_sales_order_delivery_gate(v_mo.sales_order_id);

    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'from', v_from,
        'to', v_to,
        'balance_due', COALESCE(v_gate.balance_due, 0)
      );
    END IF;
  END IF;

  UPDATE "ManufacturingOrders"
  SET status = v_to::manufacturing_order_status,
      updated_at = now(),
      production_started_at = CASE
        WHEN v_to = 'in_production' AND production_started_at IS NULL THEN now()
        ELSE production_started_at
      END,
      completed_at = CASE
        WHEN v_to IN ('delivered', 'completed') AND completed_at IS NULL THEN now()
        ELSE completed_at
      END,
      delivered_at = CASE
        WHEN v_to = 'delivered' AND delivered_at IS NULL THEN now()
        ELSE delivered_at
      END
  WHERE id = p_mo_id AND deleted = false;

  IF v_to = 'delivered'
     AND v_mo.sales_order_id IS NOT NULL
     AND COALESCE(v_gate.payment_complete, false) = false
     AND v_gate.active_override_id IS NOT NULL THEN
    UPDATE public."SalesOrderDeliveryOverrides"
    SET status = 'used',
        used_by = p_user_id,
        used_by_name = v_actor_name,
        used_source = 'mo_transition',
        used_at = now(),
        updated_at = now()
    WHERE id = v_gate.active_override_id
      AND status = 'active'
      AND deleted = false;
  END IF;

  RETURN jsonb_build_object('ok', true, 'from', v_from, 'to', v_to);
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_mo_status(uuid, text, uuid, text) TO authenticated;

-- --------------------------------------------------------------------------
-- 5) Enforce gate in complete_delivery_note
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_dn        record;
  v_total     integer;
  v_checked   integer;
  v_mo_id     uuid;
  v_new_dn_status text;
  v_all_mol_delivered boolean;
  v_so_id     uuid;
  v_all_mo_delivered boolean;
  v_org_id    uuid;
  v_mo_no     text;
  v_gate      record;
BEGIN
  SELECT * INTO v_dn FROM public."DeliveryNotes"
  WHERE id = p_delivery_note_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found');
  END IF;

  v_mo_id := v_dn.manufacturing_order_id;
  v_org_id := v_dn.organization_id;

  SELECT manufacturing_order_no, sales_order_id
  INTO v_mo_no, v_so_id
  FROM public."ManufacturingOrders"
  WHERE id = v_mo_id;

  IF v_so_id IS NOT NULL THEN
    SELECT * INTO v_gate
    FROM public.get_sales_order_delivery_gate(v_so_id);

    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'balance_due', COALESCE(v_gate.balance_due, 0)
      );
    END IF;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE checked = true)
  INTO v_total, v_checked
  FROM public."DeliveryNoteLines"
  WHERE delivery_note_id = p_delivery_note_id;

  IF v_total = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines in delivery note');
  END IF;

  IF v_checked = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines checked for delivery');
  END IF;

  v_new_dn_status := CASE WHEN v_checked >= v_total THEN 'completed' ELSE 'partial' END;

  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = CASE WHEN v_new_dn_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_delivery_note_id;

  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered',
      delivered_at = now(),
      delivered_qty = mol.quantity,
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.mo_line_id = mol.id
    AND dnl.checked = true;

  SELECT NOT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = v_mo_id
      AND deleted = false
      AND delivery_status <> 'delivered'
  ) INTO v_all_mol_delivered;

  IF v_all_mol_delivered THEN
    UPDATE public."ManufacturingOrders"
    SET status = 'delivered', delivered_at = now(), updated_at = now()
    WHERE id = v_mo_id AND status <> 'delivered';

    IF v_so_id IS NOT NULL THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM public."ManufacturingOrders"
        WHERE sales_order_id = v_so_id
          AND deleted = false
          AND status <> 'delivered'
          AND status <> 'cancelled'
      ) INTO v_all_mo_delivered;

      IF v_all_mo_delivered THEN
        UPDATE public."SalesOrders"
        SET status = 'fulfilled', updated_at = now()
        WHERE id = v_so_id AND status <> 'fulfilled';
      END IF;

      IF COALESCE(v_gate.payment_complete, false) = false
         AND v_gate.active_override_id IS NOT NULL THEN
        UPDATE public."SalesOrderDeliveryOverrides"
        SET status = 'used',
            used_by = v_dn.delivered_by_user_id,
            used_by_name = COALESCE(v_dn.delivered_by_name, 'System'),
            used_source = 'delivery_note',
            used_delivery_note_id = p_delivery_note_id,
            used_at = now(),
            updated_at = now()
        WHERE id = v_gate.active_override_id
          AND status = 'active'
          AND deleted = false;
      END IF;
    END IF;
  END IF;

  INSERT INTO public."ActivityTimeline" (
    entity_type, entity_id, action, description, user_name, organization_id
  ) VALUES (
    'manufacturing_order', v_mo_id,
    CASE WHEN v_new_dn_status = 'completed' THEN 'delivery_completed' ELSE 'delivery_partial' END,
    format('%s: %s/%s lines delivered%s',
      v_dn.delivery_number, v_checked, v_total,
      CASE WHEN v_dn.received_by_name IS NOT NULL
        THEN format(' — received by %s', v_dn.received_by_name) ELSE '' END
    ),
    COALESCE(v_dn.delivered_by_name, 'System'),
    v_org_id
  );

  IF v_all_mol_delivered THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'manufacturing_order', v_mo_id,
      'status_change',
      'Manufacturing order marked as Delivered — all lines delivered',
      COALESCE(v_dn.delivered_by_name, 'System'),
      v_org_id
    );
  END IF;

  IF v_all_mo_delivered AND v_so_id IS NOT NULL THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'sales_order', v_so_id,
      'status_change',
      'Sales order fulfilled — all manufacturing orders delivered',
      'System (auto)',
      v_org_id
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_note_status', v_new_dn_status,
    'checked_count', v_checked,
    'total_count', v_total,
    'mo_delivered', v_all_mol_delivered
  );
END;
$fn$;

NOTIFY pgrst, 'reload schema';
