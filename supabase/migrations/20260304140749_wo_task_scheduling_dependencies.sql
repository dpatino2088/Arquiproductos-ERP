ALTER TABLE public."WorkOrderTasks"
  ADD COLUMN IF NOT EXISTS estimated_duration_hours numeric NOT NULL DEFAULT 8,
  ADD COLUMN IF NOT EXISTS planned_start_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS planned_end_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS depends_on_task_ids uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS dependency_type text NOT NULL DEFAULT 'finish_to_start';

ALTER TABLE public."WorkOrderTasks"
  DROP CONSTRAINT IF EXISTS wot_dependency_type_check;
ALTER TABLE public."WorkOrderTasks"
  ADD CONSTRAINT wot_dependency_type_check
  CHECK (dependency_type IN ('finish_to_start', 'start_to_start'));

ALTER TABLE public."WorkOrderTasks"
  DROP CONSTRAINT IF EXISTS wot_planned_end_after_start;
ALTER TABLE public."WorkOrderTasks"
  ADD CONSTRAINT wot_planned_end_after_start
  CHECK (planned_end_at IS NULL OR planned_start_at IS NULL OR planned_end_at >= planned_start_at);

COMMENT ON COLUMN public."WorkOrderTasks".estimated_duration_hours IS 'Estimated hours for this operation (8 = 1 working day)';
COMMENT ON COLUMN public."WorkOrderTasks".depends_on_task_ids IS 'Array of WOT ids that must finish/start before this task';
COMMENT ON COLUMN public."WorkOrderTasks".dependency_type IS 'finish_to_start or start_to_start';

NOTIFY pgrst, 'reload schema';;
