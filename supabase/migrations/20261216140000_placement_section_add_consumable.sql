-- Add 'consumable' as a valid placement_section so BOM templates can group
-- items like tape, screw caps, fasteners, glue, etc. into their own section.
--
-- Items in this section are NOT cut deductors and are NOT cuttables — they
-- are purely organizational (visible in the BOM components table) and do
-- not participate in compute_cut_breakdown_core (the existing logic only
-- treats `drive | passive | shared` as fallback deductors and explicitly
-- excludes `cuttable`, so `consumable` is a no-op for cut calculations).

ALTER TABLE public."BOMComponents"
  DROP CONSTRAINT IF EXISTS bomcomponents_placement_section_chk;

ALTER TABLE public."BOMComponents"
  ADD CONSTRAINT bomcomponents_placement_section_chk
  CHECK (
    placement_section IS NULL
    OR placement_section = ANY (ARRAY['cuttable', 'drive', 'passive', 'shared', 'consumable']::text[])
  );

COMMENT ON CONSTRAINT bomcomponents_placement_section_chk ON public."BOMComponents" IS
  'Allowed placement sections: cuttable | drive | passive | shared | consumable. Consumables are organizational only and do not affect cut breakdown.';
