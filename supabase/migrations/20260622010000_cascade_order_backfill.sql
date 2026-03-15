-- Cascade Order Backfill
-- Updates sort_order and depends_on_role for existing BOMComponents based on
-- canonical cascade priority. This ensures consistent resolution order.
--
-- CASCADE PRIORITY:
--   10: headbox, cassette, top_rail  (base: width_mm)
--   20: tube, track                  (base: width_mm)
--   30: bottom_bar, hem_weight       (depends_on: tube)
--   40: fabric                       (depends_on: tube)
--   50: side_channel                 (base: height_mm)
--   60: bottom_channel               (depends_on: bottom_bar)
--   70: chain, belt                  (base: height_mm)
--   75: brush                        (depends_on: side_channel)
--   80: bracket, end_cap, idler      (unit items)
--   85: drive, motor, wand           (unit items)
--   86: carrier, hook                (unit items)
--   88: adapter, filler, tape        (unit items)
--   90: consumable, fastener         (unit items)
--   95: accessory                    (unit items)

-- 1. Backfill sort_order based on component_role
UPDATE "BOMComponents" SET sort_order = 10
WHERE component_role IN ('headbox', 'cassette', 'top_rail')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 20
WHERE component_role IN ('tube', 'track')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 30
WHERE component_role IN ('bottom_bar', 'hem_weight')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 40
WHERE component_role = 'fabric'
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 50
WHERE component_role = 'side_channel'
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 60
WHERE component_role = 'bottom_channel'
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 70
WHERE component_role IN ('chain', 'belt')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 75
WHERE component_role = 'brush'
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 80
WHERE component_role IN ('bracket', 'end_cap', 'idler')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 85
WHERE component_role IN ('drive', 'motor', 'wand')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 86
WHERE component_role IN ('carrier', 'hook')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 88
WHERE component_role IN ('adapter', 'filler', 'tape')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 90
WHERE component_role IN ('consumable', 'fastener')
  AND deleted = false AND parent_component_id IS NULL;

UPDATE "BOMComponents" SET sort_order = 95
WHERE component_role = 'accessory'
  AND deleted = false AND parent_component_id IS NULL;

-- 2. Backfill depends_on_role for known cascade dependencies
-- bottom_bar depends on tube
UPDATE "BOMComponents" SET depends_on_role = 'tube'
WHERE component_role = 'bottom_bar'
  AND depends_on_role IS NULL
  AND deleted = false AND parent_component_id IS NULL;

-- hem_weight depends on tube
UPDATE "BOMComponents" SET depends_on_role = 'tube'
WHERE component_role = 'hem_weight'
  AND depends_on_role IS NULL
  AND deleted = false AND parent_component_id IS NULL;

-- fabric depends on tube
UPDATE "BOMComponents" SET depends_on_role = 'tube'
WHERE component_role = 'fabric'
  AND depends_on_role IS NULL
  AND deleted = false AND parent_component_id IS NULL;

-- bottom_channel depends on bottom_bar
UPDATE "BOMComponents" SET depends_on_role = 'bottom_bar'
WHERE component_role = 'bottom_channel'
  AND depends_on_role IS NULL
  AND deleted = false AND parent_component_id IS NULL;

-- brush depends on side_channel
UPDATE "BOMComponents" SET depends_on_role = 'side_channel'
WHERE component_role = 'brush'
  AND depends_on_role IS NULL
  AND deleted = false AND parent_component_id IS NULL;
