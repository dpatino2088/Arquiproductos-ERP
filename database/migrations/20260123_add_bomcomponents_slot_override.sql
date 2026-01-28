-- Add slot override support to BOMComponents

BEGIN;

ALTER TABLE public."BOMComponents"
  ADD COLUMN IF NOT EXISTS slot_id uuid NULL,
  ADD COLUMN IF NOT EXISTS component_scope text NOT NULL DEFAULT 'template';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bomcomponents_component_scope_check'
  ) THEN
    ALTER TABLE public."BOMComponents"
      ADD CONSTRAINT bomcomponents_component_scope_check
      CHECK (component_scope IN ('template', 'bom'));
  END IF;
END $$;

-- Ensure existing rows have a scope
UPDATE public."BOMComponents"
SET component_scope = 'template'
WHERE component_scope IS NULL;

-- FK to slot (optional)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'BOMComponents_slot_id_fkey'
  ) THEN
    ALTER TABLE public."BOMComponents"
      ADD CONSTRAINT "BOMComponents_slot_id_fkey"
      FOREIGN KEY (slot_id) REFERENCES public."BOMTemplateSlots"(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Unique override per slot
CREATE UNIQUE INDEX IF NOT EXISTS bomcomponents_unique_slot_override
  ON public."BOMComponents"(organization_id, bom_template_id, slot_id)
  WHERE slot_id IS NOT NULL;

COMMIT;
