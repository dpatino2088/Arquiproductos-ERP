-- Backfill placement_section for active BOMComponents based on component_role.
--
-- Today, ~992 of 1034 active components have placement_section = NULL and the
-- breakdown engine relies on role-name heuristics. This migration writes
-- explicit placement_section for all well-known core roles, which:
--   1. Makes the data self-describing (grep-able, predictable).
--   2. Lets the engine use the section path instead of falling back to
--      string heuristics for every common case.
--   3. Keeps unknown roles (adapter, accessory, control, etc.) at NULL so
--      they remain "informational" by default and don't deduct unintentionally.
--
-- Idempotent: only writes where placement_section IS NULL.
-- Safe: no role mapping rewrites an existing value.

-- Cuttables (linear/area extrusions cut to size)
UPDATE public."BOMComponents"
SET placement_section = 'cuttable',
    updated_at        = now()
WHERE deleted = false
  AND archived = false
  AND placement_section IS NULL
  AND component_role IN (
    'tube',
    'bottom_bar',
    'bottom_channel',
    'side_channel',
    'fabric',
    'chain',
    'belt',
    'brush',
    'track',
    'cassette_tube',
    'rail'
  );

-- Drive side (motor / manual mechanism)
UPDATE public."BOMComponents"
SET placement_section = 'drive',
    updated_at        = now()
WHERE deleted = false
  AND archived = false
  AND placement_section IS NULL
  AND component_role IN (
    'motor',
    'drive',
    'chain_drive'
  );

-- Passive side (idler / opposite end)
UPDATE public."BOMComponents"
SET placement_section = 'passive',
    updated_at        = now()
WHERE deleted = false
  AND archived = false
  AND placement_section IS NULL
  AND component_role IN (
    'end_plug',
    'idler',
    'bearing'
  );

-- Shared edges (brackets at both edges, intermediates, headbox/cassette housings)
UPDATE public."BOMComponents"
SET placement_section = 'shared',
    updated_at        = now()
WHERE deleted = false
  AND archived = false
  AND placement_section IS NULL
  AND component_role IN (
    'bracket',
    'intermediate_bracket',
    'intermediate_connector',
    'headbox',
    'cassette',
    'rail_connector'
  );

-- Consumables (tapes, glues, screws-by-meter, etc.) — no deduction, no display
-- in the cut-formulas section.
UPDATE public."BOMComponents"
SET placement_section = 'consumable',
    updated_at        = now()
WHERE deleted = false
  AND archived = false
  AND placement_section IS NULL
  AND component_role IN (
    'tape',
    'consumable'
  );

-- Verification (run manually after migration if desired):
-- SELECT placement_section, count(*) FROM public."BOMComponents"
--  WHERE deleted = false AND archived = false GROUP BY 1 ORDER BY 1;
