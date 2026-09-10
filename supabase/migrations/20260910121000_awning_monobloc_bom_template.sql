-- ─────────────────────────────────────────────────────────────────────────────
-- Awning Monobloc (Epsylon) — Phase 2: BOM templates + components
--
-- MONOBLOC (extensible) cut rules from PDF "Instrucciones Monobloc Epsylon v3":
--   tube / load profile cut = Line − 117 (manual gear) or Line − 105 (motor)
--     → modeled as conditional deductors (condition_key = 'operating_type',
--       which is the config_snapshot key written by the configurator)
--     → deltas live on CatalogItems.delta_x_mm (manual gear 117, motor 105)
--   square bar cut = Line − 10 → 2 end caps × delta_x_mm 5 (per_item scope)
--   arms: CEIL(line/3250), min 2 (2 ≤6.5m / 3 ≤10m / 4 ≤13m; provisional)
--   front/ceiling supports: 2 per arm → two per_spacing 3250 rows
--   currón (center roller support): from 6 m line → per_joint spacing 5999
--     (5999 instead of 6000 so a line of exactly 6.00 m gets 1 currón)
--
-- Fabric/lona is NOT a BOM component: it flows as a roll (roll_catalog_item_id)
-- so roll cost = width × height(projection) × price. Seams/panel estimate is
-- computed in the configurator Review step (frontend, provisional constants).
--
-- Also creates a minimal VERTICAL awning template (drop screen) so the
-- awning_vertical flow can complete (template selection + labor + preview).
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  org record;
  v_tpl uuid;
BEGIN
  FOR org IN
    SELECT pt.organization_id,
           pt.id AS awning_type_id,
           (SELECT id FROM public."ProductTypes" v
             WHERE v.organization_id = pt.organization_id AND v.code = 'awning_vertical') AS vertical_type_id
    FROM public."ProductTypes" pt
    WHERE pt.code = 'awning'
  LOOP
    -- ── MONOBLOC extensible template ────────────────────────────────────────
    SELECT id INTO v_tpl FROM public."BOMTemplates"
    WHERE organization_id = org.organization_id AND code = 'AWNING_MONOBLOC_EPSYLON';

    IF v_tpl IS NULL THEN
      INSERT INTO public."BOMTemplates"
        (organization_id, product_type_id, code, name, description, manufacturer, is_active, panel_count_min, panel_count_max)
      VALUES
        (org.organization_id, org.awning_type_id, 'AWNING_MONOBLOC_EPSYLON',
         'Monobloc Extensible Awning (Epsylon)',
         'Folding-arm monobloc awning. Cut rules per Epsylon v3 PDF: tube/load profile = Line − 117 manual / − 105 motor; square bar = Line − 10.',
         'Cazorla', true, 1, 1)
      RETURNING id INTO v_tpl;

      INSERT INTO public."BOMComponents"
        (organization_id, bom_template_id, component_item_id, component_role, component_sub_role,
         qty_type, qty_value, qty_spacing_mm, qty_min, uom, placement_section,
         affects_role, condition_key, condition_value, cut_delta_scope, sort_order)
      SELECT org.organization_id, v_tpl, i.id, x.role, x.sub,
             x.qtype, x.qval, x.spacing, x.qmin, x.uom, x.placement,
             x.affects, x.ckey, x.cval, x.dscope, x.sort
      FROM (VALUES
        -- Cuttables (cut along the line/width axis)
        ('AWN-TUBE-70',       'tube',           'diam_70'::text,       'per_width', 1::numeric, NULL::int, NULL::int, 'm',  'cuttable'::text, NULL::text,            NULL::text,       NULL::text,   NULL::text,     10),
        ('AWN-TUBE-80',       'tube',           'diam_80',             'per_width', 1, NULL, NULL, 'm',  'cuttable', NULL,                  NULL,             NULL,         NULL,           11),
        ('AWN-LOAD-BAR',      'bottom_bar',     'load_profile',        'per_width', 1, NULL, NULL, 'm',  'cuttable', NULL,                  NULL,             NULL,         NULL,           20),
        ('AWN-SQBAR-40',      'square_bar',     NULL,                  'per_width', 1, NULL, NULL, 'm',  'cuttable', NULL,                  NULL,             NULL,         NULL,           30),
        -- Drive deductors (conditional on operating type; deltas on CatalogItems)
        ('AWN-DRIVE-MANUAL',  'drive',          'manual_gear',         'fixed',     1, NULL, NULL, 'ea', 'drive',    'tube,bottom_bar',     'operating_type', 'manual',     'per_item',     40),
        ('AWN-MOTOR',         'motor',          NULL,                  'fixed',     1, NULL, NULL, 'ea', 'drive',    'tube,bottom_bar',     'operating_type', 'motor',      'per_item',     41),
        -- Square bar end caps: 2 × 5 mm = Line − 10
        ('AWN-BAR-CAP',       'square_bar_cap', NULL,                  'fixed',     2, NULL, NULL, 'ea', NULL,       'square_bar',          NULL,             NULL,         'per_item',     42),
        -- Tube end caps (no cut effect; delta 0 on items)
        ('AWN-CAP-TIP',       'end_cap',        'tube_tip',            'fixed',     1, NULL, NULL, 'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           50),
        ('AWN-CAP-DRIVE',     'end_cap',        'tube_drive',          'fixed',     1, NULL, NULL, 'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           51),
        -- Wall/ceiling supports: 2 per arm → two per_spacing rows (provisional)
        ('AWN-SUPPORT-FRONT', 'bracket',        'front_support_a',     'per_spacing', 1, 3250, 2,  'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           60),
        ('AWN-SUPPORT-FRONT', 'bracket',        'front_support_b',     'per_spacing', 1, 3250, 2,  'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           61),
        -- Roller supports + covers
        ('AWN-SUPPORT-ROLL',  'bracket',        'roller_support',      'fixed',     2, NULL, NULL, 'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           62),
        ('AWN-SUPPORT-CAP',   'bracket_cover',  NULL,                  'fixed',     2, NULL, NULL, 'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           63),
        -- Currón: 1 from 6 m line, 2 from ~12 m (per_joint = CEIL(w/spacing) − 1)
        ('AWN-CURRON',        'bracket',        'curron',              'per_joint', 1, 5999, NULL, 'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           64),
        -- Arms: CEIL(line/3250) min 2, plus one support + one terminal per arm
        ('AWN-ARM-SUPPORT',   'arm_support',    NULL,                  'per_spacing', 1, 3250, 2,  'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           70),
        ('AWN-ARM',           'arm',            NULL,                  'per_spacing', 1, 3250, 2,  'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           71),
        ('AWN-ARM-TERMINAL',  'arm_terminal',   NULL,                  'per_spacing', 1, 3250, 2,  'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           72),
        -- Load profile end caps
        ('AWN-LOADBAR-CAP',   'bottom_bar_cap', NULL,                  'fixed',     2, NULL, NULL, 'ea', NULL,       NULL,                  NULL,             NULL,         NULL,           73)
      ) AS x(sku, role, sub, qtype, qval, spacing, qmin, uom, placement, affects, ckey, cval, dscope, sort)
      JOIN public."CatalogItems" i
        ON i.organization_id = org.organization_id AND i.sku = x.sku;
    END IF;

    -- ── VERTICAL awning (drop screen) minimal template ──────────────────────
    IF org.vertical_type_id IS NOT NULL THEN
      SELECT id INTO v_tpl FROM public."BOMTemplates"
      WHERE organization_id = org.organization_id AND code = 'AWNING_VERTICAL_BASIC';

      IF v_tpl IS NULL THEN
        INSERT INTO public."BOMTemplates"
          (organization_id, product_type_id, code, name, description, manufacturer, is_active, panel_count_min, panel_count_max)
        VALUES
          (org.organization_id, org.vertical_type_id, 'AWNING_VERTICAL_BASIC',
           'Vertical Awning (drop screen, basic)',
           'Vertical drop screen. Provisional despiece reusing Monobloc roller parts; cut deductions: tube/load bar = Width − 117 manual / − 105 motor.',
           'Cazorla', true, 1, 1)
        RETURNING id INTO v_tpl;

        INSERT INTO public."BOMComponents"
          (organization_id, bom_template_id, component_item_id, component_role, component_sub_role,
           qty_type, qty_value, qty_spacing_mm, qty_min, uom, placement_section,
           affects_role, condition_key, condition_value, cut_delta_scope, sort_order)
        SELECT org.organization_id, v_tpl, i.id, x.role, x.sub,
               x.qtype, x.qval, x.spacing, x.qmin, x.uom, x.placement,
               x.affects, x.ckey, x.cval, x.dscope, x.sort
        FROM (VALUES
          ('AWN-TUBE-70',      'tube',       'diam_70'::text,  'per_width', 1::numeric, NULL::int, NULL::int, 'm',  'cuttable'::text, NULL::text,        NULL::text,       NULL::text, NULL::text, 10),
          ('AWN-TUBE-80',      'tube',       'diam_80',        'per_width', 1, NULL, NULL, 'm',  'cuttable', NULL,              NULL,             NULL,       NULL,       11),
          ('AWN-LOAD-BAR',     'bottom_bar', 'load_profile',   'per_width', 1, NULL, NULL, 'm',  'cuttable', NULL,              NULL,             NULL,       NULL,       20),
          ('AWN-DRIVE-MANUAL', 'drive',      'manual_gear',    'fixed',     1, NULL, NULL, 'ea', 'drive',    'tube,bottom_bar', 'operating_type', 'manual',   'per_item', 40),
          ('AWN-MOTOR',        'motor',      NULL,             'fixed',     1, NULL, NULL, 'ea', 'drive',    'tube,bottom_bar', 'operating_type', 'motor',    'per_item', 41),
          ('AWN-CAP-TIP',      'end_cap',    'tube_tip',       'fixed',     1, NULL, NULL, 'ea', NULL,       NULL,              NULL,             NULL,       NULL,       50),
          ('AWN-CAP-DRIVE',    'end_cap',    'tube_drive',     'fixed',     1, NULL, NULL, 'ea', NULL,       NULL,              NULL,             NULL,       NULL,       51),
          ('AWN-SUPPORT-ROLL', 'bracket',    'roller_support', 'fixed',     2, NULL, NULL, 'ea', NULL,       NULL,              NULL,             NULL,       NULL,       60),
          ('AWN-LOADBAR-CAP',  'bottom_bar_cap', NULL,         'fixed',     2, NULL, NULL, 'ea', NULL,       NULL,              NULL,             NULL,       NULL,       70)
        ) AS x(sku, role, sub, qtype, qval, spacing, qmin, uom, placement, affects, ckey, cval, dscope, sort)
        JOIN public."CatalogItems" i
          ON i.organization_id = org.organization_id AND i.sku = x.sku;
      END IF;
    END IF;
  END LOOP;
END $$;
