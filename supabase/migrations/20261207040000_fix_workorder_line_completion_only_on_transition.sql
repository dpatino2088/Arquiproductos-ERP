-- Fix WorkOrderTaskLines completion guard:
--  * Only enforce parent-task status check on the actual transition (false -> true).
--    Idempotent updates that keep completed = true must not raise (e.g. UI marking a
--    SKU group where one of the WOTLs is already completed).
--  * Allow the parent task to be either 'in_progress' OR 'completed'. Once a task is
--    closed, its lines must remain valid (and may be re-touched by bulk updates).
--
-- Symptom this fixes:
--   "Task line can only be completed when task is in_progress."
-- raised by Cut Optimization > Mark Cut when one of the WOTLs in the SKU group
-- belongs to a Profile Cut task that is already 'completed'.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.enforce_workorder_line_completion_flow()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_task_status text;
  v_is_transition boolean;
BEGIN
  v_is_transition := COALESCE(NEW.completed, false) = true
    AND (TG_OP = 'INSERT' OR COALESCE(OLD.completed, false) IS DISTINCT FROM true);

  IF v_is_transition THEN
    SELECT t.status::text
    INTO v_task_status
    FROM public."WorkOrderTasks" t
    WHERE t.id = NEW.task_id
      AND t.deleted = false;

    IF COALESCE(v_task_status, '') NOT IN ('in_progress', 'completed') THEN
      RAISE EXCEPTION 'Task line can only be completed when task is in_progress (current: %).',
        COALESCE(v_task_status, 'unknown');
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
