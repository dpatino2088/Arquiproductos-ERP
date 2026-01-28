-- ============================================================
-- Poblar BOMTemplates con Fingerprints y BOMTemplateSlots
-- Basado en: bom_templates_optionA_fixed_v3.sql
-- Esquema: backups/2026-01-17_V3full.sql
-- 
-- Este script:
-- 1. Actualiza BOMTemplates existentes con fingerprints
-- 2. Crea BOMTemplateSlots para cada template
-- 3. Mantiene BOMComponents existentes para compatibilidad
-- ============================================================
BEGIN;

DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_pt_roller uuid;
  v_pt_dual uuid;
  v_pt_triple uuid;
  v_pt_drapery uuid;
  v_template_id uuid;
  v_item uuid;
  v_slot_id uuid;
BEGIN

-- ============================================================
-- STEP 1: Get ProductTypes
-- ============================================================
SELECT id INTO v_pt_roller FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
IF v_pt_roller IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;

SELECT id INTO v_pt_dual FROM public."ProductTypes" WHERE organization_id=v_org AND code='dual_shade' LIMIT 1;
IF v_pt_dual IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=dual_shade'; END IF;

SELECT id INTO v_pt_triple FROM public."ProductTypes" WHERE organization_id=v_org AND code='triple_shade' LIMIT 1;
IF v_pt_triple IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=triple_shade'; END IF;

SELECT id INTO v_pt_drapery FROM public."ProductTypes" WHERE organization_id=v_org AND code='drapery' LIMIT 1;
IF v_pt_drapery IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=drapery'; END IF;

-- ============================================================
-- ROLLER SHADE TEMPLATES
-- ============================================================

-- Template: ROLLER_MANUAL_M
-- Fingerprint: roller, none, m, white, none, manual
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_roller, 'ROLLER_MANUAL_M', 'Roller Manual M', 'Roller shade manual, size M, no cassette, no side channel',
  'roller', 'none', 'm', 'white', 'none', 'manual',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}, "rules": {"cassette_requires_system_size": "m"}, "pricing": {"bottom_bar_wrapped_pct": 0.08}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for ROLLER_MANUAL_M
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
  VALUES (v_org, v_template_id, 'drive', true, v_item, 1.0, 'Manual drive mechanism')
  ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
  VALUES (v_org, v_template_id, 'accessory', false, v_item, 1.0, 'Accessory')
  ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3005-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 1.0, 'End cap')
  ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0, 'Idler')
  ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0, 'Brackets (2 units)')
  ON CONFLICT DO NOTHING;
END IF;

-- Bottom bar with fallback
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
IF v_item IS NULL THEN
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0, 'Bottom bar (linear, cut to width)')
  ON CONFLICT DO NOTHING;
END IF;

-- Tube (user-selectable, no fixed SKU)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0, 'Tube (user selects, or default from metadata)')
ON CONFLICT DO NOTHING;

-- ============================================================

-- Template: ROLLER_MANUAL_DOBLE_M (with side channels)
-- Fingerprint: roller, none, m, white, side_plus_bottom, manual
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_roller, 'ROLLER_MANUAL_DOBLE_M', 'Roller Manual Doble M', 'Roller shade manual, size M, with side and bottom channels',
  'roller', 'none', 'm', 'white', 'side_plus_bottom', 'manual',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}, "rules": {"bottom_channel_requires_side_channel": true}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for ROLLER_MANUAL_DOBLE_M (similar to ROLLER_MANUAL_M + side/bottom channels)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'drive', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 4.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Bottom bar
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Side channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'side_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Bottom channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================

-- Template: ROLLER_MOTORIZADA_M
-- Fingerprint: roller, none, m, white, none, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_roller, 'ROLLER_MOTORIZADA_M', 'Roller Motorizada M', 'Roller shade motorized, size M, no cassette, no side channel',
  'roller', 'none', 'm', 'white', 'none', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for ROLLER_MOTORIZADA_M
-- Motor (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'accessory', false, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'accessory', false, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Bottom bar
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================

-- Template: ROLLER_MOTORIZADA_DOBLE_M (with side channels)
-- Fingerprint: roller, none, m, white, side_plus_bottom, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_roller, 'ROLLER_MOTORIZADA_DOBLE_M', 'Roller Motorizada Doble M', 'Roller shade motorized, size M, with side and bottom channels',
  'roller', 'none', 'm', 'white', 'side_plus_bottom', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for ROLLER_MOTORIZADA_DOBLE_M (motor + side/bottom channels)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 4.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Bottom bar
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Side channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'side_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Bottom channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================

-- Template: MOTORIZADA_SENCILLA_L
-- Fingerprint: roller, none, l, white, none, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_roller, 'MOTORIZADA_SENCILLA_L', 'Motorizada Sencilla L', 'Roller shade motorized, size L, no cassette, no side channel',
  'roller', 'none', 'l', 'white', 'none', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-65"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for MOTORIZADA_SENCILLA_L
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4023-ABC' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'accessory', false, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4004-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Bottom bar
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================

-- Template: MOTORIZADA_DOBLE_L (with side channels)
-- Fingerprint: roller, none, l, white, side_plus_bottom, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_roller, 'MOTORIZADA_DOBLE_L', 'Motorizada Doble L', 'Roller shade motorized, size L, with side and bottom channels',
  'roller', 'none', 'l', 'white', 'side_plus_bottom', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-65"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for MOTORIZADA_DOBLE_L
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 4.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4004-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Bottom bar
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Side channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'side_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Bottom channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================
-- DUAL SHADE TEMPLATES
-- ============================================================

-- Template: DOBLE_SHADE_MOTORIZADA
-- Fingerprint: dual, cassette, m, white, none, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_dual, 'DOBLE_SHADE_MOTORIZADA', 'Doble Shade Motorizada', 'Dual shade motorized with cassette',
  'dual', 'cassette', 'm', 'white', 'none', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}, "rules": {"cassette_requires_system_size": "m"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for DOBLE_SHADE_MOTORIZADA
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Headbox (cassette - user-selectable)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'headbox', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================
-- TRIPLE SHADE TEMPLATES
-- ============================================================

-- Template: TRIPLE_SHADE
-- Fingerprint: triple, cassette, m, white, none, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_triple, 'TRIPLE_SHADE', 'Triple Shade', 'Triple shade motorized with cassette',
  'triple', 'cassette', 'm', 'white', 'none', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}, "rules": {"cassette_requires_system_size": "m"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for TRIPLE_SHADE
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Headbox (cassette)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'headbox', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================
-- DRAPERY TEMPLATES
-- ============================================================

-- Template: RIEL_MANUAL_RIPPLE
-- Fingerprint: drapery, none, m, white, none, manual
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_drapery, 'RIEL_MANUAL_RIPPLE', 'Riel Manual (Ripple)', 'Drapery manual ripple track system',
  'drapery', 'none', 'm', 'white', 'none', 'manual',
  true, false, false, 
  '{"style": "ripple"}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for RIEL_MANUAL_RIPPLE
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1025-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'carrier', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU12-0400-MW' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'wand', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'track', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- ============================================================

-- Template: RIEL_MOTORIZADO_RIPPLE
-- Fingerprint: drapery, none, m, white, none, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_drapery, 'RIEL_MOTORIZADO_RIPPLE', 'Riel Motorizado (Ripple)', 'Drapery motorized ripple track system',
  'drapery', 'none', 'm', 'white', 'none', 'motor',
  true, false, false, 
  '{"style": "ripple"}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for RIEL_MOTORIZADO_RIPPLE
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1025-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'carrier', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1002' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'belt', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1009' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'belt_connector', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'track', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- ============================================================

-- Template: RIEL_MANUAL_PLEAT
-- Fingerprint: drapery, none, m, black, none, manual (Changed color to avoid duplicate)
-- Use different color to distinguish from RIEL_MANUAL_RIPPLE
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_drapery, 'RIEL_MANUAL_PLEAT', 'Riel Manual (Pleat)', 'Drapery manual pleat track system',
  'drapery', 'none', 'm', 'black', 'none', 'manual',
  true, false, false, 
  '{"style": "pleat", "priority": 10, "allows_color_override": true}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for RIEL_MANUAL_PLEAT
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'carrier', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU12-0400-MW' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'wand', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'track', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- ============================================================

-- Template: RIEL_MOTORIZADO_PLEAT
-- Fingerprint: drapery, none, m, black, none, motor (Changed color to avoid duplicate)
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_drapery, 'RIEL_MOTORIZADO_PLEAT', 'Riel Motorizado (Pleat)', 'Drapery motorized pleat track system',
  'drapery', 'none', 'm', 'black', 'none', 'motor',
  true, false, false, 
  '{"style": "pleat", "priority": 10, "allows_color_override": true}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for RIEL_MOTORIZADO_PLEAT
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'carrier', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1002' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'belt', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1009' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'belt_connector', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1019-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'track', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- ============================================================

-- Template: PA_O_FIJO_RIPPLE_Y_PLEAT (Fixed Panel)
-- Fingerprint: drapery, none, s, white, none, manual (Changed system_size to 's' to avoid duplicate)
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_drapery, 'PA_O_FIJO_RIPPLE_Y_PLEAT', 'Paño Fijo (Ripple y Pleat)', 'Fixed panel for ripple and pleat',
  'drapery', 'none', 's', 'white', 'none', 'manual',
  true, false, false, 
  '{"style": "fixed", "priority": 5}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for PA_O_FIJO_RIPPLE_Y_PLEAT
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1; END IF;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'track', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- ============================================================

-- Template: DOBLE_SHADE
-- Fingerprint: dual, none, m, white, none, motor (Changed headbox_type to 'none' to avoid duplicate)
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_dual, 'DOBLE_SHADE', 'Doble Shade', 'Dual shade motorized without cassette',
  'dual', 'none', 'm', 'white', 'none', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}, "priority": 5}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for DOBLE_SHADE
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'accessory', false, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bottom_bar', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Headbox (cassette)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'headbox', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================

-- Template: TRIPLE_SHADE_DOBLE (with side channels)
-- Fingerprint: triple, cassette, m, white, side_plus_bottom, motor
INSERT INTO public."BOMTemplates"(
  organization_id, product_type_id, code, name, description,
  product_type, headbox_type, system_size, color, side_channel_mode, operating_system,
  active, deleted, archived, metadata
) VALUES (
  v_org, v_pt_triple, 'TRIPLE_SHADE_DOBLE', 'Triple Shade Doble', 'Triple shade motorized with side and bottom channels',
  'triple', 'cassette', 'm', 'white', 'side_plus_bottom', 'motor',
  true, false, false, 
  '{"defaults": {"tube_type": "RTU-42"}}'::jsonb
)
ON CONFLICT (organization_id, code) DO UPDATE SET
  product_type = EXCLUDED.product_type,
  headbox_type = EXCLUDED.headbox_type,
  system_size = EXCLUDED.system_size,
  color = EXCLUDED.color,
  side_channel_mode = EXCLUDED.side_channel_mode,
  operating_system = EXCLUDED.operating_system,
  metadata = EXCLUDED.metadata,
  active = EXCLUDED.active
RETURNING id INTO v_template_id;

-- Slots for TRIPLE_SHADE_DOBLE (similar to TRIPLE_SHADE + channels)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'motor', true, NULL, 1.0) ON CONFLICT DO NOTHING;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'idler', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'bracket', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'end_cap', true, v_item, 2.0) ON CONFLICT DO NOTHING;
END IF;

-- Headbox (cassette)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
IF v_item IS NOT NULL THEN
  INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
  VALUES (v_org, v_template_id, 'headbox', true, v_item, 1.0) ON CONFLICT DO NOTHING;
END IF;

-- Tube
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Side channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'side_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- Bottom channel (user-selectable)
INSERT INTO public."BOMTemplateSlots"(organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_channel', true, NULL, 1.0) ON CONFLICT DO NOTHING;

-- ============================================================

RAISE NOTICE 'Successfully populated BOMTemplates with fingerprints and BOMTemplateSlots';

END;
$$;

COMMIT;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Verify templates with fingerprints
SELECT 
  code, 
  name, 
  product_type,
  headbox_type,
  system_size,
  color,
  side_channel_mode,
  operating_system,
  active
FROM public."BOMTemplates"
WHERE organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND deleted=false
ORDER BY product_type, operating_system, system_size, side_channel_mode;

-- Verify slots per template
SELECT 
  bt.code as template_code,
  bt.name as template_name,
  COUNT(bts.id) as slots_count
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMTemplateSlots" bts ON bts.bom_template_id=bt.id
WHERE bt.organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted=false
GROUP BY bt.code, bt.name
ORDER BY bt.code;

-- Verify components per template (existing)
SELECT 
  bt.code as template_code,
  bt.name as template_name,
  COUNT(bc.id) as components_count
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMComponents" bc ON bc.bom_template_id=bt.id AND bc.deleted=false
WHERE bt.organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted=false
GROUP BY bt.code, bt.name
ORDER BY bt.code;
