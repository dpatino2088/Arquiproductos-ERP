-- Backfill by ProductType name
UPDATE "public"."FabricRules" fr
SET fabric_width_source = 'tube_width',
    formula_code = 'ROLLER_DROPS',
    pricing_output_uom = 'm',
    tube_wrap_mm = CASE WHEN fr.tube_wrap_mm > 0 THEN fr.tube_wrap_mm ELSE 35 END,
    bottom_wrap_mm = CASE
      WHEN fr.bottom_wrap_mm > 0 THEN fr.bottom_wrap_mm
      WHEN lower(pt.name) LIKE '%roller%' OR lower(pt.name) LIKE '%zip%' THEN 50
      ELSE 0
    END,
    safety_margin_mm = CASE WHEN fr.safety_margin_mm > 0 THEN fr.safety_margin_mm ELSE 20 END,
    panel_multiplier = CASE
      WHEN lower(pt.name) LIKE '%triple%' THEN 3
      WHEN lower(pt.name) LIKE '%dual%' THEN 2
      ELSE 1
    END
FROM "public"."ProductTypes" pt
WHERE pt.id = fr.product_type_id
  AND fr.fabric_width_source != 'tube_width'
  AND (
    lower(pt.name) LIKE '%roller%'
    OR lower(pt.name) LIKE '%dual%'
    OR lower(pt.name) LIKE '%triple%'
    OR lower(pt.name) LIKE '%zip%'
  );

-- panel_index column
ALTER TABLE "public"."BOMInstanceLines"
  ADD COLUMN IF NOT EXISTS panel_index integer DEFAULT NULL;

-- Helper functions
CREATE OR REPLACE FUNCTION public.get_panel_cut_mm(
  p_dimension_outputs jsonb,
  p_role text,
  p_panel_index integer
) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_cuts_key text;
  v_width_key text;
  v_cuts jsonb;
  v_panel jsonb;
BEGIN
  IF p_dimension_outputs IS NULL THEN RETURN NULL; END IF;
  v_cuts_key := p_role || '_panel_cuts';
  v_width_key := p_role || '_width_mm';
  v_cuts := p_dimension_outputs->v_cuts_key;
  IF v_cuts IS NULL OR jsonb_typeof(v_cuts) != 'array' THEN RETURN NULL; END IF;
  FOR v_panel IN SELECT value FROM jsonb_array_elements(v_cuts) AS value LOOP
    IF (v_panel->>'index')::integer = p_panel_index THEN
      RETURN (v_panel->>v_width_key)::numeric;
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_dimension_panel_count(
  p_dimension_outputs jsonb
) RETURNS integer
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  IF p_dimension_outputs IS NULL THEN RETURN 1; END IF;
  RETURN COALESCE((p_dimension_outputs->>'panel_count')::integer, 1);
END;
$$;

NOTIFY pgrst, 'reload schema';;
