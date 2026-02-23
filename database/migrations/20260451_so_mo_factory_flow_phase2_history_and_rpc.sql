-- ====================================================
-- Migration: SO/MO Factory Flow Phase 2 — History Tables, RPC, Triggers
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Create append-only history tables
-- ====================================================

CREATE TABLE IF NOT EXISTS public."SalesOrderStatusHistory" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_order_id uuid NOT NULL REFERENCES public."SalesOrders"(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  reason text,
  changed_by_user_id uuid REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now(),
  source text DEFAULT 'ui' CHECK (source IN ('ui', 'api', 'system'))
);

CREATE INDEX IF NOT EXISTS idx_so_status_history_sales_order_id
  ON public."SalesOrderStatusHistory"(sales_order_id);

CREATE TABLE IF NOT EXISTS public."SalesOrderPaymentStatusHistory" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_order_id uuid NOT NULL REFERENCES public."SalesOrders"(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  reason text,
  changed_by_user_id uuid REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now(),
  source text DEFAULT 'ui' CHECK (source IN ('ui', 'api', 'system'))
);

CREATE INDEX IF NOT EXISTS idx_so_payment_history_sales_order_id
  ON public."SalesOrderPaymentStatusHistory"(sales_order_id);

CREATE TABLE IF NOT EXISTS public."ManufacturingOrderStatusHistory" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  reason text,
  changed_by_user_id uuid REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now(),
  source text DEFAULT 'ui' CHECK (source IN ('ui', 'api', 'system'))
);

CREATE INDEX IF NOT EXISTS idx_mo_status_history_manufacturing_order_id
  ON public."ManufacturingOrderStatusHistory"(manufacturing_order_id);

-- ====================================================
-- STEP 2: Release-to-manufacturing RPC
-- ====================================================

CREATE OR REPLACE FUNCTION public.release_sales_order_to_manufacturing(
  p_sales_order_id uuid,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS TABLE(mo_id uuid, mo_number text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_so RECORD;
  v_mo_id uuid;
  v_mo_number text;
  v_sol RECORD;
BEGIN
  -- Validate SO exists and is eligible
  SELECT * INTO v_so
  FROM public."SalesOrders"
  WHERE id = p_sales_order_id AND deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SalesOrder % not found', p_sales_order_id;
  END IF;

  IF v_so.order_status NOT IN ('Open', 'On Hold') THEN
    RAISE EXCEPTION 'SalesOrder % has order_status %, cannot release (must be Open or On Hold)', p_sales_order_id, v_so.order_status;
  END IF;

  IF v_so.payment_status NOT IN ('Deposit Paid', 'Balance Pending', 'Paid in Full') THEN
    RAISE EXCEPTION 'SalesOrder % has payment_status %, cannot release (must be at least Deposit Paid)', p_sales_order_id, v_so.payment_status;
  END IF;

  -- Generate MO number (prefer get_next_sequential_number, fallback to get_next_counter_value)
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_next_sequential_number') THEN
      SELECT public.get_next_sequential_number('ManufacturingOrders', 'manufacturing_order_no', 'MO-')
      INTO v_mo_number;
    ELSE
      v_mo_number := 'MO-' || LPAD(
        public.get_next_counter_value(v_so.organization_id, 'manufacturing_order')::text, 6, '0');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    SELECT 'MO-' || LPAD((COALESCE(MAX(
      (regexp_match(manufacturing_order_no, 'MO-(\d+)'))[1]::int
    ), 0) + 1)::text, 6, '0') INTO v_mo_number
    FROM public."ManufacturingOrders"
    WHERE organization_id = v_so.organization_id AND deleted = false;
  END;

  -- Create ManufacturingOrder
  INSERT INTO public."ManufacturingOrders" (
    organization_id, sales_order_id, manufacturing_order_no,
    mo_type, production_status, priority_code, priority_rank, dealer_id,
    created_by, updated_by
  )
  VALUES (
    v_so.organization_id, p_sales_order_id, v_mo_number,
    'PRIMARY', 'Pending Review',
    COALESCE(v_so.priority_code::text, 'Normal')::priority_code_enum,
    v_so.priority_rank, v_so.dealer_id,
    p_user_id, p_user_id
  )
  RETURNING id INTO v_mo_id;

  -- Create ManufacturingOrderLines from SalesOrderLines
  FOR v_sol IN
    SELECT sol.id, sol.quote_line_id, sol.quantity, sol.qty, sol.computed_qty, sol.organization_id,
           ql.configured_product_id
    FROM public."SalesOrderLines" sol
    LEFT JOIN public."QuoteLines" ql ON ql.id = sol.quote_line_id
    WHERE sol.sales_order_id = p_sales_order_id
      AND COALESCE(sol.deleted, false) = false
  LOOP
    INSERT INTO public."ManufacturingOrderLines" (
      manufacturing_order_id, sales_order_line_id, organization_id,
      configured_product_id, quantity, status
    )
    VALUES (
      v_mo_id, v_sol.id, COALESCE(v_sol.organization_id, v_so.organization_id),
      v_sol.configured_product_id,
      COALESCE(v_sol.quantity, v_sol.qty, v_sol.computed_qty, 1),
      'planned'
    );
  END LOOP;

  -- Insert MO status history
  INSERT INTO public."ManufacturingOrderStatusHistory" (
    manufacturing_order_id, from_status, to_status, reason, changed_by_user_id, source
  )
  VALUES (v_mo_id, NULL, 'Pending Review', 'Created via release_sales_order_to_manufacturing', p_user_id, 'api');

  RETURN QUERY SELECT v_mo_id, v_mo_number;
END;
$$;

COMMENT ON FUNCTION public.release_sales_order_to_manufacturing IS
'Creates a ManufacturingOrder from a SalesOrder. Validates order_status and payment_status. Copies lines to ManufacturingOrderLines.';

-- ====================================================
-- STEP 3: History triggers
-- ====================================================

CREATE OR REPLACE FUNCTION public.trg_so_order_status_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_source text := 'ui';
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.order_status IS DISTINCT FROM NEW.order_status THEN
    IF NEW.order_status_reason IS NOT NULL AND (
      NEW.order_status_reason ILIKE '%paid in full%' OR
      NEW.order_status_reason ILIKE '%all MOs delivered%'
    ) THEN
      v_source := 'system';
    END IF;
    INSERT INTO public."SalesOrderStatusHistory" (
      sales_order_id, from_status, to_status, reason,
      changed_by_user_id, source
    )
    VALUES (
      NEW.id, OLD.order_status::text, NEW.order_status::text, NEW.order_status_reason,
      NEW.order_status_changed_by_user_id, v_source
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_so_order_status_history ON public."SalesOrders";
CREATE TRIGGER trg_so_order_status_history
  AFTER UPDATE OF order_status ON public."SalesOrders"
  FOR EACH ROW
  WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
  EXECUTE FUNCTION public.trg_so_order_status_history();

CREATE OR REPLACE FUNCTION public.trg_so_payment_status_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
    INSERT INTO public."SalesOrderPaymentStatusHistory" (
      sales_order_id, from_status, to_status, reason,
      changed_by_user_id, source
    )
    VALUES (
      NEW.id, OLD.payment_status::text, NEW.payment_status::text, NEW.payment_status_reason,
      NEW.payment_status_changed_by_user_id, 'ui'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_so_payment_status_history ON public."SalesOrders";
CREATE TRIGGER trg_so_payment_status_history
  AFTER UPDATE OF payment_status ON public."SalesOrders"
  FOR EACH ROW
  WHEN (OLD.payment_status IS DISTINCT FROM NEW.payment_status)
  EXECUTE FUNCTION public.trg_so_payment_status_history();

CREATE OR REPLACE FUNCTION public.trg_mo_production_status_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.production_status IS DISTINCT FROM NEW.production_status THEN
    INSERT INTO public."ManufacturingOrderStatusHistory" (
      manufacturing_order_id, from_status, to_status, reason,
      changed_by_user_id, source
    )
    VALUES (
      NEW.id, OLD.production_status::text, NEW.production_status::text, NEW.production_status_reason,
      NEW.status_changed_by_user_id, 'ui'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mo_production_status_history ON public."ManufacturingOrders";
CREATE TRIGGER trg_mo_production_status_history
  AFTER UPDATE OF production_status ON public."ManufacturingOrders"
  FOR EACH ROW
  WHEN (OLD.production_status IS DISTINCT FROM NEW.production_status)
  EXECUTE FUNCTION public.trg_mo_production_status_history();

-- ====================================================
-- STEP 4: Automation — All MOs Delivered → SO Completed
-- ====================================================

CREATE OR REPLACE FUNCTION public.trg_mo_all_delivered_set_so_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_so_id uuid;
  v_all_delivered boolean;
  v_so_order_status order_status_so;
BEGIN
  v_so_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);
  IF v_so_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  IF NEW.production_status = 'Delivered' THEN
    SELECT bool_and(mo.production_status = 'Delivered')
    INTO v_all_delivered
    FROM public."ManufacturingOrders" mo
    WHERE mo.sales_order_id = v_so_id AND mo.deleted = false;

    IF v_all_delivered THEN
      SELECT order_status INTO v_so_order_status FROM public."SalesOrders" WHERE id = v_so_id AND deleted = false;
      IF v_so_order_status IS DISTINCT FROM 'Completed' AND v_so_order_status IS DISTINCT FROM 'Closed' THEN
        UPDATE public."SalesOrders"
        SET order_status = 'Completed',
            order_status_changed_at = now(),
            order_status_reason = 'All MOs delivered'
        WHERE id = v_so_id AND deleted = false;
        INSERT INTO public."SalesOrderStatusHistory" (sales_order_id, from_status, to_status, reason, source)
        VALUES (v_so_id, v_so_order_status::text, 'Completed', 'All MOs delivered', 'system');
      END IF;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_mo_all_delivered_set_so_completed ON public."ManufacturingOrders";
CREATE TRIGGER trg_mo_all_delivered_set_so_completed
  AFTER UPDATE OF production_status ON public."ManufacturingOrders"
  FOR EACH ROW
  WHEN (NEW.production_status = 'Delivered')
  EXECUTE FUNCTION public.trg_mo_all_delivered_set_so_completed();

-- ====================================================
-- STEP 5: Automation — Paid in Full → SO Closed
-- ====================================================

CREATE OR REPLACE FUNCTION public.trg_so_paid_in_full_set_closed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.payment_status = 'Paid in Full' AND (OLD.payment_status IS NULL OR OLD.payment_status <> 'Paid in Full') THEN
    IF NEW.order_status IS DISTINCT FROM 'Closed' THEN
      NEW.order_status := 'Closed';
      NEW.order_status_reason := 'Paid in full';
      NEW.order_status_changed_at := now();
      -- trg_so_order_status_history will insert with source='system' when reason ILIKE '%paid in full%'
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_so_paid_in_full_set_closed ON public."SalesOrders";
CREATE TRIGGER trg_so_paid_in_full_set_closed
  BEFORE UPDATE OF payment_status ON public."SalesOrders"
  FOR EACH ROW
  WHEN (NEW.payment_status = 'Paid in Full' AND OLD.payment_status IS DISTINCT FROM 'Paid in Full')
  EXECUTE FUNCTION public.trg_so_paid_in_full_set_closed();

-- ====================================================
-- STEP 6: MO Locking — is_mo_locked function
-- ====================================================

CREATE OR REPLACE FUNCTION public.is_mo_locked(p_mo_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public."ManufacturingOrders"
    WHERE id = p_mo_id AND deleted = false
      AND production_status IN ('Ready for Pickup', 'Delivered')
  );
$$;

-- ====================================================
-- STEP 7: MO Locking — block changes when locked
-- ====================================================

CREATE OR REPLACE FUNCTION public.trg_mo_enforce_lock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF public.is_mo_locked(COALESCE(NEW.id, OLD.id)) THEN
    IF TG_OP = 'UPDATE' THEN
      IF OLD.production_status = 'Ready for Pickup' AND NEW.production_status = 'Delivered' THEN
        RETURN NEW;
      END IF;
      RAISE EXCEPTION 'ManufacturingOrder is locked (Ready for Pickup or Delivered). Create REWORK MO for corrections.';
    ELSIF TG_OP = 'DELETE' THEN
      RAISE EXCEPTION 'Cannot delete locked ManufacturingOrder.';
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_mo_enforce_lock ON public."ManufacturingOrders";
CREATE TRIGGER trg_mo_enforce_lock
  BEFORE UPDATE OR DELETE ON public."ManufacturingOrders"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_mo_enforce_lock();

CREATE OR REPLACE FUNCTION public.trg_mol_enforce_mo_lock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF public.is_mo_locked(COALESCE(NEW.manufacturing_order_id, OLD.manufacturing_order_id)) THEN
    RAISE EXCEPTION 'ManufacturingOrder is locked. Cannot modify ManufacturingOrderLines. Create REWORK MO for corrections.';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_mol_enforce_mo_lock ON public."ManufacturingOrderLines";
CREATE TRIGGER trg_mol_enforce_mo_lock
  BEFORE INSERT OR UPDATE OR DELETE ON public."ManufacturingOrderLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_mol_enforce_mo_lock();
