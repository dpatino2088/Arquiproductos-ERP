-- Create FabricRules for Dual Shade and Triple Shade so they use the
-- consumption engine (tube_width + panel_multiplier) instead of legacy fallback.

INSERT INTO "FabricRules" (
  organization_id, product_type_id, style_code, formula_code,
  height_multiplier, width_multiplier, fullness_factor,
  extra_height_m, extra_width_m, pricing_output_uom,
  waste_pct, round_to_increment, min_qty,
  is_active, top_hem_cm, bottom_hem_cm, side_hem_cm,
  fabric_orientation, fabric_width_source,
  tube_wrap_mm, bottom_wrap_mm, safety_margin_mm, panel_multiplier
)
SELECT
  fr.organization_id,
  pt.id,
  NULL, 'ROLLER_DROPS',
  1, 1, 1,
  0, 0, 'm',
  0.15, 0.10, 0,
  true, 0, 0, 0,
  'vertical', 'tube_width',
  35, 0, 20,
  CASE pt.code WHEN 'dual_shade' THEN 2 WHEN 'triple_shade' THEN 3 END
FROM "ProductTypes" pt
CROSS JOIN (SELECT organization_id FROM "FabricRules" WHERE is_active = true LIMIT 1) fr
WHERE pt.code IN ('dual_shade', 'triple_shade')
  AND NOT EXISTS (
    SELECT 1 FROM "FabricRules" fr2
    WHERE fr2.product_type_id = pt.id AND fr2.is_active = true
  );
