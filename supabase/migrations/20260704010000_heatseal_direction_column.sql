BEGIN;

-- Add heatseal_direction to FabricRules
ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS heatseal_direction text NOT NULL DEFAULT 'none';

ALTER TABLE "public"."FabricRules"
  ADD CONSTRAINT chk_heatseal_direction
  CHECK (heatseal_direction IN ('horizontal', 'vertical', 'none'));

COMMENT ON COLUMN "public"."FabricRules".heatseal_direction IS
  'Direction of heatseal/join seam: horizontal (roller), vertical (drapery sew), none (dual/triple - no join).';

-- Backfill from ProductTypes
UPDATE "public"."FabricRules" fr
SET heatseal_direction = 'horizontal'
FROM "public"."ProductTypes" pt
WHERE pt.id = fr.product_type_id
  AND pt.code = 'roller';

UPDATE "public"."FabricRules" fr
SET heatseal_direction = 'vertical'
FROM "public"."ProductTypes" pt
WHERE pt.id = fr.product_type_id
  AND pt.code = 'drapery';

-- dual_shade and triple_shade stay 'none' (the default)

COMMIT;
