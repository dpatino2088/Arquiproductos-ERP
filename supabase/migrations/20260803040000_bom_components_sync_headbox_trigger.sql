-- Auto-sync BOMTemplates.headbox from BOMComponents.is_required
-- Keeps backward compatibility: BOMTemplates.headbox = true when at least one
-- non-deleted component with role 'headbox' or 'cassette' has is_required = true.

CREATE OR REPLACE FUNCTION public.sync_bom_template_headbox()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_template_id uuid;
  v_has_required_headbox boolean;
BEGIN
  -- Determine which template was affected
  IF TG_OP = 'DELETE' THEN
    v_template_id := OLD.bom_template_id;
  ELSE
    v_template_id := NEW.bom_template_id;
  END IF;

  -- Also handle UPDATE that changes bom_template_id
  IF TG_OP = 'UPDATE' AND OLD.bom_template_id IS DISTINCT FROM NEW.bom_template_id THEN
    -- Re-sync the OLD template too
    SELECT EXISTS (
      SELECT 1 FROM public."BOMComponents"
      WHERE bom_template_id = OLD.bom_template_id
        AND component_role IN ('headbox', 'cassette')
        AND is_required = true
        AND deleted = false
        AND archived = false
        AND parent_component_id IS NULL
    ) INTO v_has_required_headbox;

    UPDATE public."BOMTemplates"
    SET headbox = v_has_required_headbox
    WHERE id = OLD.bom_template_id
      AND headbox IS DISTINCT FROM v_has_required_headbox;
  END IF;

  -- Sync the current template
  SELECT EXISTS (
    SELECT 1 FROM public."BOMComponents"
    WHERE bom_template_id = v_template_id
      AND component_role IN ('headbox', 'cassette')
      AND is_required = true
      AND deleted = false
      AND archived = false
      AND parent_component_id IS NULL
  ) INTO v_has_required_headbox;

  UPDATE public."BOMTemplates"
  SET headbox = v_has_required_headbox
  WHERE id = v_template_id
    AND headbox IS DISTINCT FROM v_has_required_headbox;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bom_components_sync_headbox ON public."BOMComponents";
CREATE TRIGGER trg_bom_components_sync_headbox
  AFTER INSERT OR UPDATE OF component_role, is_required, deleted, archived, bom_template_id
  OR DELETE
  ON public."BOMComponents"
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_bom_template_headbox();

-- Backfill: sync all existing templates
UPDATE public."BOMTemplates" bt
SET headbox = (
  SELECT EXISTS (
    SELECT 1 FROM public."BOMComponents" bc
    WHERE bc.bom_template_id = bt.id
      AND bc.component_role IN ('headbox', 'cassette')
      AND bc.is_required = true
      AND bc.deleted = false
      AND bc.archived = false
      AND bc.parent_component_id IS NULL
  )
);
