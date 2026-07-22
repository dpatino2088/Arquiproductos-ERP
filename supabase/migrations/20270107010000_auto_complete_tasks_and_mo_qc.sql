-- Centralize production completion so it is consistent across every UI path
-- (Workstation, Cut Optimization, bulk "Mark as Assembled", etc.).
--
-- Problem: a task's lines could all be completed while the task stayed
-- 'in_progress', so the MO never advanced past in_production. This left MOs
-- that were 100% done still showing as "in production".
--
-- Fix (DB-enforced invariants):
--   1. A task auto-completes when ALL its lines are completed, and re-opens if
--      a line is later un-completed.
--   2. When ALL of an MO's tasks are completed, the MO advances to
--      quality_check (via transition_mo_status so the ActivityTimeline logs it);
--      if a task is later re-opened, the MO falls back to in_production.

SET search_path = public;

-- 1) Task completion follows its line completion.
CREATE OR REPLACE FUNCTION public.fn_task_autocomplete_from_lines()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task_id uuid;
  v_total   int;
  v_done    int;
  v_status  text;
BEGIN
  v_task_id := COALESCE(NEW.task_id, OLD.task_id);
  IF v_task_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT status::text INTO v_status
  FROM "WorkOrderTasks"
  WHERE id = v_task_id AND deleted = false;

  IF v_status IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT count(*), count(*) FILTER (WHERE completed)
    INTO v_total, v_done
  FROM "WorkOrderTaskLines"
  WHERE task_id = v_task_id;

  IF v_total > 0 AND v_done = v_total AND v_status = 'in_progress' THEN
    UPDATE "WorkOrderTasks"
    SET status = 'completed', completed_at = now(), updated_at = now()
    WHERE id = v_task_id;
  ELSIF v_done < v_total AND v_status = 'completed' THEN
    UPDATE "WorkOrderTasks"
    SET status = 'in_progress', completed_at = NULL, updated_at = now()
    WHERE id = v_task_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_task_autocomplete_from_lines ON public."WorkOrderTaskLines";
CREATE TRIGGER trg_task_autocomplete_from_lines
AFTER INSERT OR DELETE OR UPDATE OF completed ON public."WorkOrderTaskLines"
FOR EACH ROW
EXECUTE FUNCTION public.fn_task_autocomplete_from_lines();

-- 2) MO advances to QC when all its tasks complete (and falls back if re-opened).
CREATE OR REPLACE FUNCTION public.fn_mo_advance_on_tasks_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id     uuid;
  v_mo_status text;
  v_total     int;
  v_done      int;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_mo_id := NEW.manufacturing_order_id;
  IF v_mo_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status::text INTO v_mo_status
  FROM "ManufacturingOrders"
  WHERE id = v_mo_id AND deleted = false;
  IF v_mo_status IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE status = 'completed')
    INTO v_total, v_done
  FROM "WorkOrderTasks"
  WHERE manufacturing_order_id = v_mo_id AND deleted = false;

  IF v_total > 0 AND v_done = v_total AND v_mo_status = 'in_production' THEN
    PERFORM public.transition_mo_status(
      v_mo_id, 'quality_check',
      '00000000-0000-0000-0000-000000000000', 'System (all tasks complete)');
  ELSIF v_done < v_total AND v_mo_status = 'quality_check' THEN
    UPDATE "ManufacturingOrders"
    SET status = 'in_production', updated_at = now()
    WHERE id = v_mo_id AND deleted = false;

    INSERT INTO public."ActivityTimeline" (
      organization_id, entity_type, entity_id, action, description,
      user_id, user_name, metadata
    )
    SELECT organization_id, 'manufacturing_order', id, 'status_changed',
           'MO status changed: quality check -> in production',
           '00000000-0000-0000-0000-000000000000', 'System (task reopened)',
           jsonb_build_object('from', 'quality_check', 'to', 'in_production', 'source', 'task_reopen')
    FROM "ManufacturingOrders" WHERE id = v_mo_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mo_advance_on_tasks_complete ON public."WorkOrderTasks";
CREATE TRIGGER trg_mo_advance_on_tasks_complete
AFTER UPDATE OF status ON public."WorkOrderTasks"
FOR EACH ROW
EXECUTE FUNCTION public.fn_mo_advance_on_tasks_complete();

-- 3) Backfill: complete any task whose lines are already all done. The triggers
--    above then cascade each affected MO to quality_check where appropriate.
UPDATE public."WorkOrderTasks" t
SET status = 'completed', completed_at = now(), updated_at = now()
WHERE t.deleted = false
  AND t.status = 'in_progress'
  AND EXISTS (SELECT 1 FROM public."WorkOrderTaskLines" l WHERE l.task_id = t.id)
  AND NOT EXISTS (
    SELECT 1 FROM public."WorkOrderTaskLines" l
    WHERE l.task_id = t.id AND l.completed = false
  );
