-- Relax Work Order execution guards (Manufacturing Orders simplification):
-- 1) Operator assignment is now OPTIONAL and never blocks starting/completing a task.
-- 2) Calendar date (planned_start_at) is OPTIONAL: if a task is started without a
--    planned start, the system defaults it to now() instead of rejecting.
--    An explicitly scheduled FUTURE date still prevents starting early.
--
-- This supersedes the operator/schedule checks from
-- 20260725060000_workorder_execution_sequence_guards.sql. The WO-insert guard
-- (MO must be confirmed) and the line-completion guard remain unchanged.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.enforce_workorder_task_operator_assignment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Operator is optional and never blocks (no assignment check).
  -- Schedule is optional: default to now() when starting without a planned date.
  IF COALESCE(NEW.deleted, false) = false
     AND NEW.status::text = 'in_progress' THEN
    IF NEW.planned_start_at IS NULL THEN
      NEW.planned_start_at := now();
    ELSIF NEW.planned_start_at > now() THEN
      RAISE EXCEPTION 'Cannot start task before its planned start date/time.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger definition already exists; recreate to be idempotent.
DROP TRIGGER IF EXISTS trg_enforce_workorder_task_operator_assignment ON public."WorkOrderTasks";

CREATE TRIGGER trg_enforce_workorder_task_operator_assignment
BEFORE INSERT OR UPDATE ON public."WorkOrderTasks"
FOR EACH ROW
EXECUTE FUNCTION public.enforce_workorder_task_operator_assignment();
