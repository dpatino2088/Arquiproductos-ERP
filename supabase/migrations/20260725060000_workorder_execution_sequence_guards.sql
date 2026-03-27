-- Enforce WO execution sequence:
-- 1) Work Orders can be generated only when MO is in confirmed.
-- 2) Task cannot move to in_progress/completed without operator assignment.
-- 3) Task cannot move to in_progress before planned_start_at and scheduled time.
-- 4) Task lines cannot be marked completed unless task is in_progress.

SET search_path = public;

-- ---------------------------------------------------------------------------
-- 1) Insert guard for WO generation stage
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_workorder_insert_on_confirmed_mo()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT mo.status::text
  INTO v_status
  FROM public."ManufacturingOrders" mo
  WHERE mo.id = NEW.manufacturing_order_id
    AND mo.deleted = false;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Manufacturing Order not found for Work Order task.';
  END IF;

  IF v_status <> 'confirmed' THEN
    RAISE EXCEPTION 'Work Orders can only be generated when MO status is confirmed (current: %).', v_status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_workorder_insert_on_confirmed_mo ON public."WorkOrderTasks";

CREATE TRIGGER trg_enforce_workorder_insert_on_confirmed_mo
BEFORE INSERT ON public."WorkOrderTasks"
FOR EACH ROW
EXECUTE FUNCTION public.enforce_workorder_insert_on_confirmed_mo();

-- ---------------------------------------------------------------------------
-- 2) Update existing operator-assignment guard with schedule checks
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_workorder_task_operator_assignment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF COALESCE(NEW.deleted, false) = false
     AND NEW.status::text IN ('in_progress', 'completed')
     AND NEW.assigned_to_user_id IS NULL THEN
    RAISE EXCEPTION 'Operator assignment is required before moving a Work Order task to %.', NEW.status::text;
  END IF;

  IF COALESCE(NEW.deleted, false) = false
     AND NEW.status::text = 'in_progress' THEN
    IF NEW.planned_start_at IS NULL THEN
      RAISE EXCEPTION 'Task schedule is required before starting Work Order task.';
    END IF;
    IF NEW.planned_start_at > now() THEN
      RAISE EXCEPTION 'Cannot start task before its planned start date/time.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- trigger already exists from previous migration; keep idempotent
DROP TRIGGER IF EXISTS trg_enforce_workorder_task_operator_assignment ON public."WorkOrderTasks";

CREATE TRIGGER trg_enforce_workorder_task_operator_assignment
BEFORE INSERT OR UPDATE ON public."WorkOrderTasks"
FOR EACH ROW
EXECUTE FUNCTION public.enforce_workorder_task_operator_assignment();

-- ---------------------------------------------------------------------------
-- 3) Line completion guard: only allowed when parent task is in_progress
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_workorder_line_completion_flow()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_task_status text;
BEGIN
  IF COALESCE(NEW.completed, false) = true THEN
    SELECT t.status::text
    INTO v_task_status
    FROM public."WorkOrderTasks" t
    WHERE t.id = NEW.task_id
      AND t.deleted = false;

    IF COALESCE(v_task_status, '') <> 'in_progress' THEN
      RAISE EXCEPTION 'Task line can only be completed when task is in_progress.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_workorder_line_completion_flow ON public."WorkOrderTaskLines";

CREATE TRIGGER trg_enforce_workorder_line_completion_flow
BEFORE INSERT OR UPDATE ON public."WorkOrderTaskLines"
FOR EACH ROW
EXECUTE FUNCTION public.enforce_workorder_line_completion_flow();
