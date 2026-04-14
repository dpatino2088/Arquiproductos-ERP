-- Enforce operator assignment before task execution.
-- Pending tasks may exist unassigned, but in_progress/completed cannot.

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

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_workorder_task_operator_assignment ON public."WorkOrderTasks";

CREATE TRIGGER trg_enforce_workorder_task_operator_assignment
BEFORE INSERT OR UPDATE ON public."WorkOrderTasks"
FOR EACH ROW
EXECUTE FUNCTION public.enforce_workorder_task_operator_assignment();;
