-- Expand BOMTemplateSlots.item_role constraint to match app roles
-- Align with src/lib/bom/roles.ts CANONICAL_COMPONENT_ROLES

BEGIN;

ALTER TABLE public."BOMTemplateSlots"
  DROP CONSTRAINT IF EXISTS bomtemplateslots_item_role_check;

ALTER TABLE public."BOMTemplateSlots"
  ADD CONSTRAINT bomtemplateslots_item_role_check
  CHECK (item_role = ANY (ARRAY[
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

COMMIT;
