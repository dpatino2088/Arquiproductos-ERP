BEGIN;

ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS allow_rotation boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN "public"."FabricRules".allow_rotation IS
  'Whether the 2D cut optimizer may rotate pieces for this product type. Dual/Triple Shade: always false.';

UPDATE "public"."FabricRules" fr
SET allow_rotation = false
FROM "public"."ProductTypes" pt
WHERE pt.id = fr.product_type_id
  AND pt.code IN ('dual_shade', 'triple_shade');

COMMIT;
