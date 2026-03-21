-- ============================================================================
-- Propagate MO status changes to the linked SalesOrder
-- ============================================================================
-- When ANY MO -> in_production:    SO -> in_production  (if currently early stage)
-- When ALL  MOs -> ready_for_pickup+: SO -> ready_for_delivery
-- When ALL  MOs -> delivered/completed: SO -> delivered
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.trg_mo_status_propagate_to_so()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_so_id        uuid;
  v_so_status    text;
  v_all_ready    boolean;
  v_all_delivered boolean;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_so_id := NEW.sales_order_id;
  IF v_so_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_so_status
  FROM "SalesOrders"
  WHERE id = v_so_id AND deleted = false;

  IF v_so_status IS NULL THEN
    RETURN NEW;
  END IF;

  -- MO entered production: advance SO if it's still in an early stage
  IF NEW.status = 'in_production'
     AND v_so_status IN ('draft', 'confirmed', 'on_hold') THEN
    UPDATE "SalesOrders"
    SET status = 'in_production', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  -- MO reached ready_for_pickup: check if ALL non-cancelled MOs are at least ready
  IF NEW.status = 'ready_for_pickup' THEN
    SELECT bool_and(mo.status IN ('ready_for_pickup', 'delivered', 'completed'))
    INTO v_all_ready
    FROM "ManufacturingOrders" mo
    WHERE mo.sales_order_id = v_so_id
      AND mo.deleted = false
      AND mo.status <> 'cancelled';

    IF v_all_ready IS TRUE AND v_so_status NOT IN ('delivered', 'closed') THEN
      UPDATE "SalesOrders"
      SET status = 'ready_for_delivery', updated_at = now()
      WHERE id = v_so_id AND deleted = false;
    END IF;
    RETURN NEW;
  END IF;

  -- MO delivered: check if ALL non-cancelled MOs are delivered/completed
  IF NEW.status IN ('delivered', 'completed') THEN
    SELECT bool_and(mo.status IN ('delivered', 'completed'))
    INTO v_all_delivered
    FROM "ManufacturingOrders" mo
    WHERE mo.sales_order_id = v_so_id
      AND mo.deleted = false
      AND mo.status <> 'cancelled';

    IF v_all_delivered IS TRUE AND v_so_status <> 'delivered' THEN
      UPDATE "SalesOrders"
      SET status = 'delivered', updated_at = now()
      WHERE id = v_so_id AND deleted = false;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mo_status_propagate_to_so ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_status_propagate_to_so
  AFTER UPDATE OF status ON "ManufacturingOrders"
  FOR EACH ROW
  EXECUTE FUNCTION trg_mo_status_propagate_to_so();
