-- Schedule Changelog: audit trail for scheduling changes
-- Tracks all modifications to planned_start_at / planned_end_at on WorkOrderTasks and ManufacturingOrders

CREATE TABLE IF NOT EXISTS public.schedule_changelog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  work_order_task_id uuid REFERENCES public."WorkOrderTasks"(id) ON DELETE CASCADE,
  field_changed varchar(60) NOT NULL,
  old_value text,
  new_value text,
  changed_by uuid,
  changed_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  change_source varchar(20) NOT NULL DEFAULT 'system'
    CHECK (change_source IN ('manual','auto_schedule','drag_drop','system'))
);

CREATE INDEX idx_changelog_mo_date ON public.schedule_changelog (manufacturing_order_id, changed_at DESC);
CREATE INDEX idx_changelog_task_date ON public.schedule_changelog (work_order_task_id, changed_at DESC)
  WHERE work_order_task_id IS NOT NULL;

ALTER TABLE public.schedule_changelog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can read changelog" ON public.schedule_changelog
  FOR SELECT USING (
    manufacturing_order_id IN (
      SELECT id FROM public."ManufacturingOrders"
      WHERE organization_id = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'organization_id')::uuid
    )
  );

CREATE POLICY "authenticated can insert changelog" ON public.schedule_changelog
  FOR INSERT WITH CHECK (true);

-- Trigger: log WorkOrderTasks schedule changes
CREATE OR REPLACE FUNCTION public.trg_fn_changelog_work_order_tasks()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.planned_start_at IS DISTINCT FROM NEW.planned_start_at THEN
    INSERT INTO public.schedule_changelog
      (manufacturing_order_id, work_order_task_id, field_changed, old_value, new_value, changed_by, change_source)
    VALUES
      (NEW.manufacturing_order_id, NEW.id, 'planned_start_at',
       OLD.planned_start_at::text, NEW.planned_start_at::text,
       NULLIF(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid,
       'system');
  END IF;

  IF OLD.planned_end_at IS DISTINCT FROM NEW.planned_end_at THEN
    INSERT INTO public.schedule_changelog
      (manufacturing_order_id, work_order_task_id, field_changed, old_value, new_value, changed_by, change_source)
    VALUES
      (NEW.manufacturing_order_id, NEW.id, 'planned_end_at',
       OLD.planned_end_at::text, NEW.planned_end_at::text,
       NULLIF(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid,
       'system');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_changelog_work_order_tasks ON public."WorkOrderTasks";
CREATE TRIGGER trg_changelog_work_order_tasks
  AFTER UPDATE ON public."WorkOrderTasks"
  FOR EACH ROW
  WHEN (OLD.planned_start_at IS DISTINCT FROM NEW.planned_start_at
     OR OLD.planned_end_at IS DISTINCT FROM NEW.planned_end_at)
  EXECUTE FUNCTION public.trg_fn_changelog_work_order_tasks();

-- Trigger: log ManufacturingOrders schedule changes
CREATE OR REPLACE FUNCTION public.trg_fn_changelog_manufacturing_orders()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.planned_start_at IS DISTINCT FROM NEW.planned_start_at THEN
    INSERT INTO public.schedule_changelog
      (manufacturing_order_id, field_changed, old_value, new_value, changed_by, change_source)
    VALUES
      (NEW.id, 'mo_planned_start_at',
       OLD.planned_start_at::text, NEW.planned_start_at::text,
       NULLIF(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid,
       'system');
  END IF;

  IF OLD.planned_end_at IS DISTINCT FROM NEW.planned_end_at THEN
    INSERT INTO public.schedule_changelog
      (manufacturing_order_id, field_changed, old_value, new_value, changed_by, change_source)
    VALUES
      (NEW.id, 'mo_planned_end_at',
       OLD.planned_end_at::text, NEW.planned_end_at::text,
       NULLIF(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid,
       'system');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_changelog_manufacturing_orders ON public."ManufacturingOrders";
CREATE TRIGGER trg_changelog_manufacturing_orders
  AFTER UPDATE ON public."ManufacturingOrders"
  FOR EACH ROW
  WHEN (OLD.planned_start_at IS DISTINCT FROM NEW.planned_start_at
     OR OLD.planned_end_at IS DISTINCT FROM NEW.planned_end_at)
  EXECUTE FUNCTION public.trg_fn_changelog_manufacturing_orders();
