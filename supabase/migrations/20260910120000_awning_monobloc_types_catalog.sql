-- ─────────────────────────────────────────────────────────────────────────────
-- Awning Monobloc (Epsylon) — Phase 1: product types + catalog despiece + canvas
--
-- 1) New ProductType `awning_vertical` (Vertical Awning) per organization that
--    already has the `awning` (extensible) type.
-- 2) Monobloc despiece CatalogItems (provisional cost 0, manufacturer Cazorla).
--    Cut deductions live on the items as delta_x_mm (width axis):
--      - Manual gear (máquina):  LT − 117 mm  → delta_x_mm = 117
--      - Motor (with support):   LT − 105 mm  → delta_x_mm = 105
--      - Square bar end cap:     5 mm each (qty 2 → LT − 10 mm)
-- 3) Demo awning canvas (lona) roll: 1.20 m usable width, linked ONLY to the
--    awning product types via CatalogItemProductTypes (never roller).
-- 4) LaborRule for awning_vertical (clone of the existing awning rule).
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  org record;
  v_vertical_id uuid;
  v_lona_id uuid;
BEGIN
  FOR org IN
    SELECT organization_id, id AS awning_type_id
    FROM public."ProductTypes"
    WHERE code = 'awning'
  LOOP
    -- 1) ProductType awning_vertical
    INSERT INTO public."ProductTypes" (organization_id, code, name, sort_order, status, fulfillment_type)
    VALUES (org.organization_id, 'awning_vertical', 'Vertical Awning', 55, 'active', 'manufacture')
    ON CONFLICT (organization_id, code) DO NOTHING;

    SELECT id INTO v_vertical_id
    FROM public."ProductTypes"
    WHERE organization_id = org.organization_id AND code = 'awning_vertical';

    -- 2) Monobloc despiece (Epsylon refs) — provisional cost 0
    INSERT INTO public."CatalogItems"
      (organization_id, sku, name, unit_of_measure, measure_basis, cost_exw, manufacturer, is_active, delta_x_mm, delta_y_mm)
    SELECT org.organization_id, x.sku, x.name, x.uom, x.basis, 0, 'Cazorla', true, x.dx, 0
    FROM (VALUES
      ('AWN-TUBE-70',       'Awning Roller Tube Ø70 (ref 9080)',                    'm',  'linear', 0),
      ('AWN-TUBE-80',       'Awning Roller Tube Ø80 (ref 9080-80)',                 'm',  'linear', 0),
      ('AWN-LOAD-BAR',      'Awning Load Profile / Perfil de carga (ref 3499)',     'm',  'linear', 0),
      ('AWN-SQBAR-40',      'Awning Square Bar 40x40x1.5 (ref 6300)',               'm',  'linear', 0),
      ('AWN-SQBAR-40M',     'Awning Square Bar 40x40x3 Magnum steel (ref 9086)',    'm',  'linear', 0),
      ('AWN-DRIVE-MANUAL',  'Awning Manual Gear / Máquina (ref 711100)',            'ea', 'unit',   117),
      ('AWN-MOTOR',         'Awning Tubular Motor (torque per abaco)',              'ea', 'unit',   105),
      ('AWN-CAP-TIP',       'Awning Tube End Cap / Casquillo punta (ref 70308000)', 'ea', 'unit',   0),
      ('AWN-CAP-DRIVE',     'Awning Tube Drive Cap / Casquillo máquina (ref 70027000)', 'ea', 'unit', 0),
      ('AWN-SUPPORT-FRONT', 'Awning Front/Ceiling Support (ref 610300)',            'ea', 'unit',   0),
      ('AWN-SUPPORT-ROLL',  'Awning Roller Support / Soporte enrolle (ref 630230)', 'ea', 'unit',   0),
      ('AWN-SUPPORT-CAP',   'Awning Roller Support Cover (ref D1334)',              'ea', 'unit',   0),
      ('AWN-BAR-CAP',       'Awning Square Bar End Cap / Tapón barra (ref 620100)', 'ea', 'unit',   5),
      ('AWN-CURRON',        'Awning Center Roller Support / Currón (ref 610400)',   'ea', 'unit',   0),
      ('AWN-ARM-SUPPORT',   'Awning Arm Support / Soporte brazos (ref 610900)',     'ea', 'unit',   0),
      ('AWN-ARM',           'Awning Folding Arm Epsylon (ref 3170)',                'ea', 'unit',   0),
      ('AWN-ARM-TERMINAL',  'Awning Arm Terminal (ref 306000)',                     'ea', 'unit',   0),
      ('AWN-LOADBAR-CAP',   'Awning Load Profile End Cap / Tapón perfil (ref 300799)', 'ea', 'unit', 0)
    ) AS x(sku, name, uom, basis, dx)
    WHERE NOT EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.organization_id = org.organization_id AND ci.sku = x.sku
    );

    -- 3) Demo awning canvas (lona) roll — 1.20 m usable width (provisional)
    INSERT INTO public."CatalogItems"
      (organization_id, sku, name, unit_of_measure, measure_basis, cost_exw, manufacturer, is_active,
       is_roll, roll_width_m, roll_length_m, roll_width, collection_name, variant_name, purchase_unit)
    SELECT org.organization_id, 'AWN-LONA-ACR-120', 'Awning Canvas Acrylic 120 cm (demo)', 'm2', 'area', 0, 'Cazorla', true,
           true, 1.20, 50, 1.20, 'Awning Canvas', 'Acrylic Natural', 'roll'
    WHERE NOT EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.organization_id = org.organization_id AND ci.sku = 'AWN-LONA-ACR-120'
    );

    SELECT id INTO v_lona_id
    FROM public."CatalogItems"
    WHERE organization_id = org.organization_id AND sku = 'AWN-LONA-ACR-120';

    -- Link the canvas to BOTH awning product types (and only those)
    INSERT INTO public."CatalogItemProductTypes" (organization_id, catalog_item_id, product_type_id, catalog_item_sku, catalog_item_name)
    SELECT org.organization_id, v_lona_id, t.pt_id, 'AWN-LONA-ACR-120', 'Awning Canvas Acrylic 120 cm (demo)'
    FROM (VALUES (org.awning_type_id), (v_vertical_id)) AS t(pt_id)
    WHERE t.pt_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."CatalogItemProductTypes" cpt
        WHERE cpt.organization_id = org.organization_id
          AND cpt.catalog_item_id = v_lona_id
          AND cpt.product_type_id = t.pt_id
      );

    -- 4) LaborRule for awning_vertical (clone of the awning rule; provisional)
    INSERT INTO public."LaborRules"
      (organization_id, product_type_id, display_name, priority, is_active, calc_mode,
       pct_materials, fixed_amount, rate_per_m2, rate_motor_addon, min_charge)
    SELECT lr.organization_id, v_vertical_id, 'Labor Vertical Awning v1 (clone of awning)', lr.priority, true, lr.calc_mode,
           lr.pct_materials, lr.fixed_amount, lr.rate_per_m2, lr.rate_motor_addon, lr.min_charge
    FROM public."LaborRules" lr
    WHERE lr.organization_id = org.organization_id
      AND lr.product_type_id = org.awning_type_id
      AND lr.is_active = true
      AND v_vertical_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."LaborRules" x
        WHERE x.organization_id = org.organization_id AND x.product_type_id = v_vertical_id
      )
    LIMIT 1;
  END LOOP;
END $$;
