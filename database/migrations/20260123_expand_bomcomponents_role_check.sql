-- Expand BOMComponents role constraints to match app canonical roles

BEGIN;

ALTER TABLE public."BOMComponents"
  DROP CONSTRAINT IF EXISTS bomcomponents_component_role_check;

ALTER TABLE public."BOMComponents"
  ADD CONSTRAINT bomcomponents_component_role_check
  CHECK (component_role = ANY (ARRAY[
    'tube',
    'track',
    'bottom_bar',
    'bottom_channel',
    'hem_weight',
    'side_channel',
    'top_rail',
    'headbox',
    'bracket',
    'idler',
    'drive',
    'motor',
    'chain',
    'chain_stop',
    'chain_tensioner',
    'wand',
    'end_cap',
    'filler',
    'tape',
    'consumable',
    'fastener',
    'accessory',
    'carrier',
    'belt',
    'belt_connector',
    'hook',
    'brush',
    'fabric',
    'adapter',
    'bearing',
    'connector',
    'guide',
    'rail_connector',
    'spring',
    'stopper',
    'mounting_clip',
    'end_plug'
  ]));

ALTER TABLE public."BOMComponents"
  DROP CONSTRAINT IF EXISTS bomcomponents_depends_on_role_check;

ALTER TABLE public."BOMComponents"
  ADD CONSTRAINT bomcomponents_depends_on_role_check
  CHECK ((depends_on_role IS NULL) OR (depends_on_role = ANY (ARRAY[
    'tube',
    'track',
    'bottom_bar',
    'bottom_channel',
    'hem_weight',
    'side_channel',
    'top_rail',
    'headbox',
    'bracket',
    'idler',
    'drive',
    'motor',
    'chain',
    'chain_stop',
    'chain_tensioner',
    'wand',
    'end_cap',
    'filler',
    'tape',
    'consumable',
    'fastener',
    'accessory',
    'carrier',
    'belt',
    'belt_connector',
    'hook',
    'brush',
    'fabric',
    'adapter',
    'bearing',
    'connector',
    'guide',
    'rail_connector',
    'spring',
    'stopper',
    'mounting_clip',
    'end_plug'
  ])));

COMMIT;
