-- Parent component placement sections for cut-side routing:
-- cuttable | drive | passive | shared

ALTER TABLE public."BOMComponents"
  ADD COLUMN IF NOT EXISTS placement_section text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'bomcomponents_placement_section_chk'
      AND conrelid = 'public."BOMComponents"'::regclass
  ) THEN
    ALTER TABLE public."BOMComponents"
      ADD CONSTRAINT bomcomponents_placement_section_chk
      CHECK (
        placement_section IS NULL
        OR placement_section IN ('cuttable', 'drive', 'passive', 'shared')
      );
  END IF;
END$$;

COMMENT ON COLUMN public."BOMComponents".placement_section
IS 'Parent-side placement section for cut deductions: cuttable, drive, passive, shared.';

CREATE OR REPLACE FUNCTION public.save_bom_component_placement_sections(
  p_organization_id uuid,
  p_bom_template_id uuid,
  p_rows jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_row jsonb;
  v_updated integer := 0;
  v_row_count integer := 0;
BEGIN
  FOR v_row IN SELECT jsonb_array_elements(COALESCE(p_rows, '[]'::jsonb))
  LOOP
    UPDATE public."BOMComponents" bc
       SET placement_section = NULLIF(TRIM(COALESCE(v_row ->> 'placement_section', '')), ''),
           updated_at = now()
     WHERE bc.organization_id = p_organization_id
       AND bc.bom_template_id = p_bom_template_id
       AND bc.parent_component_id IS NULL
       AND bc.deleted = false
       AND bc.archived = false
       AND bc.component_item_id IS NOT DISTINCT FROM (v_row ->> 'component_item_id')::uuid
       AND COALESCE(bc.component_role, '') = COALESCE(v_row ->> 'component_role', '')
       AND COALESCE(bc.sort_order, 0) = COALESCE((v_row ->> 'sort_order')::int, 0)
       AND COALESCE(bc.condition_key, '') = COALESCE(v_row ->> 'condition_key', '')
       AND COALESCE(bc.condition_value, '') = COALESCE(v_row ->> 'condition_value', '');

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    v_updated := v_updated + v_row_count;
  END LOOP;

  RETURN v_updated;
END;
$$;

COMMENT ON FUNCTION public.save_bom_component_placement_sections(uuid, uuid, jsonb)
IS 'Persists placement_section for parent BOM components after batch save, matching by stable parent identity fields.';
