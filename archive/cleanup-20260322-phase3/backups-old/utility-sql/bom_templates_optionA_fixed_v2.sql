-- ============================================================
-- Generated from BOM Template.xlsx (Proyectos 2025)
-- - Creates/Upserts BOMTemplates
-- - Inserts BOMComponents (fixed schema: BOMComponents.component_item_id / qty_type / qty_value)
-- Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
-- ============================================================
BEGIN;
DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_pt uuid;
  v_template_id uuid;
  v_item uuid;
BEGIN
-- Upsert templates
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_M') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'ROLLER_MANUAL_M', 'Roller Manual M', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_DOBLE_M') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'ROLLER_MANUAL_DOBLE_M', 'Roller Manual Doble M', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_M') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'ROLLER_MOTORIZADA_M', 'Roller Motorizada M', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_DOBLE_M') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'ROLLER_MOTORIZADA_DOBLE_M', 'Roller Motorizada doble M', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_SENCILLA_L') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'MOTORIZADA_SENCILLA_L', 'Motorizada Sencilla L', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='roller_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_DOBLE_L') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'MOTORIZADA_DOBLE_L', 'Motorizada Doble L', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='dual_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=dual_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE_MOTORIZADA') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'DOBLE_SHADE_MOTORIZADA', 'Doble Shade Motorizada', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='triple_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=triple_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'TRIPLE_SHADE', 'Triple Shade', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='triple_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=triple_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE_DOBLE') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'TRIPLE_SHADE_DOBLE', 'Triple Shade Doble', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='drapery' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=drapery'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='PA_O_FIJO_RIPPLE_Y_PLEAT') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'PA_O_FIJO_RIPPLE_Y_PLEAT', 'Paño Fijo (Ripple y Pleat)', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='drapery' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=drapery'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_RIPPLE') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'RIEL_MANUAL_RIPPLE', 'Riel Manual (Ripple)', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='drapery' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=drapery'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_PLEAT') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'RIEL_MANUAL_PLEAT', 'Riel Manual (Pleat)', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='drapery' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=drapery'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_RIPPLE') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'RIEL_MOTORIZADO_RIPPLE', 'Riel Motorizado (Ripple)', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='drapery' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=drapery'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_PLEAT') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'RIEL_MOTORIZADO_PLEAT', 'Riel Motorizado (Pleat)', true, false, false);
  END IF;
  SELECT id INTO v_pt FROM public."ProductTypes" WHERE organization_id=v_org AND code='dual_shade' LIMIT 1;
  IF v_pt IS NULL THEN RAISE EXCEPTION 'Missing ProductTypes.code=dual_shade'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE') THEN
    INSERT INTO public."BOMTemplates"(organization_id, product_type_id, code, name, active, deleted, archived)
    VALUES (v_org, v_pt, 'DOBLE_SHADE', 'Doble Shade', true, false, false);
  END IF;

  -- Insert components per template
  -- Template: ROLLER_MANUAL_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MANUAL_M'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3001-W for template ROLLER_MANUAL_M role DRIVE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='DRIVE' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'DRIVE', 'fixed', 1.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3026 for template ROLLER_MANUAL_M role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3005-W for template ROLLER_MANUAL_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2003-W for template ROLLER_MANUAL_M role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MANUAL_M role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MANUAL_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MANUAL_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MANUAL_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04 for template ROLLER_MANUAL_M role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 90, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: ROLLER_MANUAL_DOBLE_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_DOBLE_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MANUAL_DOBLE_M'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3001-W for template ROLLER_MANUAL_DOBLE_M role DRIVE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='DRIVE' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'DRIVE', 'fixed', 1.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template ROLLER_MANUAL_DOBLE_M role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MANUAL_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 4.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MANUAL_DOBLE_M role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MANUAL_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MANUAL_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 3.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template ROLLER_MANUAL_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template ROLLER_MANUAL_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template ROLLER_MANUAL_DOBLE_M role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template ROLLER_MANUAL_DOBLE_M role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 100, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04 for template ROLLER_MANUAL_DOBLE_M role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: ROLLER_MOTORIZADA_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MOTORIZADA_M'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template ROLLER_MOTORIZADA_M role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template ROLLER_MOTORIZADA_M role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template ROLLER_MOTORIZADA_M role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MOTORIZADA_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MOTORIZADA_M role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MOTORIZADA_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MOTORIZADA_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 80, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04 for template ROLLER_MOTORIZADA_M role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: ROLLER_MOTORIZADA_DOBLE_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_DOBLE_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MOTORIZADA_DOBLE_M'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template ROLLER_MOTORIZADA_DOBLE_M role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template ROLLER_MOTORIZADA_DOBLE_M role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template ROLLER_MOTORIZADA_DOBLE_M role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MOTORIZADA_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 4.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MOTORIZADA_DOBLE_M role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MOTORIZADA_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MOTORIZADA_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 3.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template ROLLER_MOTORIZADA_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template ROLLER_MOTORIZADA_DOBLE_M role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template ROLLER_MOTORIZADA_DOBLE_M role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template ROLLER_MOTORIZADA_DOBLE_M role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 120, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04 for template ROLLER_MOTORIZADA_DOBLE_M role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 130, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: MOTORIZADA_SENCILLA_L
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_SENCILLA_L' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: MOTORIZADA_SENCILLA_L'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4023-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4023-ABC for template MOTORIZADA_SENCILLA_L role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template MOTORIZADA_SENCILLA_L role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template MOTORIZADA_SENCILLA_L role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template MOTORIZADA_SENCILLA_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4004-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4004-W for template MOTORIZADA_SENCILLA_L role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4005-W for template MOTORIZADA_SENCILLA_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4006-W for template MOTORIZADA_SENCILLA_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template MOTORIZADA_SENCILLA_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-13-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-13-W for template MOTORIZADA_SENCILLA_L role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 2.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 100, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04 for template MOTORIZADA_SENCILLA_L role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: MOTORIZADA_DOBLE_L
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_DOBLE_L' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: MOTORIZADA_DOBLE_L'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4023-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4023-ABC for template MOTORIZADA_DOBLE_L role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template MOTORIZADA_DOBLE_L role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template MOTORIZADA_DOBLE_L role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template MOTORIZADA_DOBLE_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 4.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4004-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4004-W for template MOTORIZADA_DOBLE_L role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4005-W for template MOTORIZADA_DOBLE_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4006-W for template MOTORIZADA_DOBLE_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 3.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-13-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-13-W for template MOTORIZADA_DOBLE_L role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 4.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template MOTORIZADA_DOBLE_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template MOTORIZADA_DOBLE_L role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template MOTORIZADA_DOBLE_L role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4014-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4014-W for template MOTORIZADA_DOBLE_L role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 120, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 130, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04 for template MOTORIZADA_DOBLE_L role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 140, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: DOBLE_SHADE_MOTORIZADA
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE_MOTORIZADA' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: DOBLE_SHADE_MOTORIZADA'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template DOBLE_SHADE_MOTORIZADA role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template DOBLE_SHADE_MOTORIZADA role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template DOBLE_SHADE_MOTORIZADA role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template DOBLE_SHADE_MOTORIZADA role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-03-W for template DOBLE_SHADE_MOTORIZADA role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-05-W for template DOBLE_SHADE_MOTORIZADA role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-07-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-07-W for template DOBLE_SHADE_MOTORIZADA role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 110, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template DOBLE_SHADE_MOTORIZADA role HEADBOX'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='HEADBOX' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'HEADBOX', 'fixed', 1.0, 'linear', 120, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 130, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template DOBLE_SHADE_MOTORIZADA role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 140, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template DOBLE_SHADE_MOTORIZADA role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 150, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template DOBLE_SHADE_MOTORIZADA role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 160, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 170, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template DOBLE_SHADE_MOTORIZADA role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 180, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 4.0, 'ea', 190, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 4.0, 'ea', 200, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-03-W for template DOBLE_SHADE_MOTORIZADA role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 4.0, 'ea', 210, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template DOBLE_SHADE_MOTORIZADA role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 220, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template DOBLE_SHADE_MOTORIZADA role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 230, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 240, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template DOBLE_SHADE_MOTORIZADA role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 250, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-05-W for template DOBLE_SHADE_MOTORIZADA role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 260, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-07-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-07-W for template DOBLE_SHADE_MOTORIZADA role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 270, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 280, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template DOBLE_SHADE_MOTORIZADA role HEADBOX'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='HEADBOX' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'HEADBOX', 'fixed', 1.0, 'linear', 290, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: TRIPLE_SHADE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: TRIPLE_SHADE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template TRIPLE_SHADE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template TRIPLE_SHADE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template TRIPLE_SHADE role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template TRIPLE_SHADE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template TRIPLE_SHADE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template TRIPLE_SHADE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template TRIPLE_SHADE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 80, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template TRIPLE_SHADE role HEADBOX'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='HEADBOX' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'HEADBOX', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: TRIPLE_SHADE_DOBLE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE_DOBLE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: TRIPLE_SHADE_DOBLE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template TRIPLE_SHADE_DOBLE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template TRIPLE_SHADE_DOBLE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template TRIPLE_SHADE_DOBLE role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template TRIPLE_SHADE_DOBLE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template TRIPLE_SHADE_DOBLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template TRIPLE_SHADE_DOBLE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 4.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template TRIPLE_SHADE_DOBLE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 4.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template TRIPLE_SHADE_DOBLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template TRIPLE_SHADE_DOBLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template TRIPLE_SHADE_DOBLE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template TRIPLE_SHADE_DOBLE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 1.0, 'ea', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 120, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template TRIPLE_SHADE_DOBLE role HEADBOX'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='HEADBOX' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'HEADBOX', 'fixed', 1.0, 'linear', 130, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: PA_O_FIJO_RIPPLE_Y_PLEAT
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='PA_O_FIJO_RIPPLE_Y_PLEAT' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: PA_O_FIJO_RIPPLE_Y_PLEAT'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1023-W for template PA_O_FIJO_RIPPLE_Y_PLEAT role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017 for template PA_O_FIJO_RIPPLE_Y_PLEAT role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template PA_O_FIJO_RIPPLE_Y_PLEAT role TRACK'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TRACK' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'TRACK', 'fixed', 1.0, 'linear', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MANUAL_RIPPLE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_RIPPLE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MANUAL_RIPPLE'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1023-W for template RIEL_MANUAL_RIPPLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017 for template RIEL_MANUAL_RIPPLE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1025 for template RIEL_MANUAL_RIPPLE role CARRIER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='CARRIER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'CARRIER', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1026' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1026 for template RIEL_MANUAL_RIPPLE role CARRIER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='CARRIER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'CARRIER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU12' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU12 for template RIEL_MANUAL_RIPPLE role WAND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='WAND' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'WAND', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU14-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU14-TR for template RIEL_MANUAL_RIPPLE role WAND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='WAND' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'WAND', 'fixed', 4.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MANUAL_RIPPLE role TRACK'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TRACK' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'TRACK', 'fixed', 1.0, 'linear', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MANUAL_PLEAT
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_PLEAT' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MANUAL_PLEAT'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1023-W for template RIEL_MANUAL_PLEAT role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017 for template RIEL_MANUAL_PLEAT role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1011 for template RIEL_MANUAL_PLEAT role CARRIER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='CARRIER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'CARRIER', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU12' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU12 for template RIEL_MANUAL_PLEAT role WAND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='WAND' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'WAND', 'fixed', 2.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU14-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU14-TR for template RIEL_MANUAL_PLEAT role WAND'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='WAND' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'WAND', 'fixed', 4.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MANUAL_PLEAT role TRACK'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TRACK' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'TRACK', 'fixed', 1.0, 'linear', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MOTORIZADO_RIPPLE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_RIPPLE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MOTORIZADO_RIPPLE'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017 for template RIEL_MOTORIZADO_RIPPLE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1025 for template RIEL_MOTORIZADO_RIPPLE role CARRIER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='CARRIER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'CARRIER', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1026' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1026 for template RIEL_MOTORIZADO_RIPPLE role CARRIER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='CARRIER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'CARRIER', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1002' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1002 for template RIEL_MOTORIZADO_RIPPLE role BELT'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BELT' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BELT', 'fixed', 1.0, 'linear', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1009' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1009 for template RIEL_MOTORIZADO_RIPPLE role BELT_CONNECTOR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BELT_CONNECTOR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BELT_CONNECTOR', 'fixed', 1.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 50, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1019-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1019-W for template RIEL_MOTORIZADO_RIPPLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1006-W for template RIEL_MOTORIZADO_RIPPLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1005-W for template RIEL_MOTORIZADO_RIPPLE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1032-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1032-TR for template RIEL_MOTORIZADO_RIPPLE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 2.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MOTORIZADO_RIPPLE role TRACK'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TRACK' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'TRACK', 'fixed', 1.0, 'linear', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MOTORIZADO_PLEAT
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_PLEAT' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MOTORIZADO_PLEAT'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017 for template RIEL_MOTORIZADO_PLEAT role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1011 for template RIEL_MOTORIZADO_PLEAT role CARRIER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='CARRIER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'CARRIER', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1002' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1002 for template RIEL_MOTORIZADO_PLEAT role BELT'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BELT' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BELT', 'fixed', 1.0, 'linear', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1009' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1009 for template RIEL_MOTORIZADO_PLEAT role BELT_CONNECTOR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BELT_CONNECTOR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BELT_CONNECTOR', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 40, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1019-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1019-W for template RIEL_MOTORIZADO_PLEAT role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1006-W for template RIEL_MOTORIZADO_PLEAT role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1005-W for template RIEL_MOTORIZADO_PLEAT role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 1.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1007-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1007-TR for template RIEL_MOTORIZADO_PLEAT role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 2.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MOTORIZADO_PLEAT role TRACK'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TRACK' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'TRACK', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: DOBLE_SHADE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: DOBLE_SHADE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='MOTOR' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'MOTOR', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3026 for template DOBLE_SHADE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3005-W for template DOBLE_SHADE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2003-W for template DOBLE_SHADE role IDLER'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='IDLER' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'IDLER', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template DOBLE_SHADE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template DOBLE_SHADE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template DOBLE_SHADE role BRACKET'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BRACKET' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BRACKET', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template DOBLE_SHADE role ACCESSORY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='ACCESSORY' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'ACCESSORY', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-03-W for template DOBLE_SHADE role END_CAP'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='END_CAP' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'END_CAP', 'fixed', 2.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-05-W for template DOBLE_SHADE role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-07-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-07-W for template DOBLE_SHADE role BOTTOM_BAR'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='BOTTOM_BAR' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'BOTTOM_BAR', 'fixed', 1.0, 'linear', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='TUBE' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'TUBE', 'fixed', 1.0, 'linear', 110, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template DOBLE_SHADE role HEADBOX'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='HEADBOX' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'HEADBOX', 'fixed', 1.0, 'linear', 120, true, 'ROLE_AND_COLOR', false, false);
  END IF;

  -- RoleOptions: TUBE M/L rule
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RTU-42' LIMIT 1;
  IF v_item IS NOT NULL THEN
      VALUES (v_org, 'TUBE', v_item, 'M (42mm)', 0, '{"max_width_m": 3.0, "label": "M (42mm)"}'::jsonb);
    END IF;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RTU-65' LIMIT 1;
  IF v_item IS NOT NULL THEN
      VALUES (v_org, 'TUBE', v_item, 'L (65mm)', 10, '{"max_width_m": 4.5, "label": "L (65mm)"}'::jsonb);
    END IF;
  END IF;

  -- RoleOptions: MOTOR (from excel SKUs; selectable injection)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CM-09-C120' LIMIT 1;
  IF v_item IS NOT NULL THEN
      VALUES (v_org, 'MOTOR', v_item, 'CM-09-C120', 0, '{"source": "excel"}'::jsonb);
    END IF;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CM-35-120' LIMIT 1;
  IF v_item IS NOT NULL THEN
      VALUES (v_org, 'MOTOR', v_item, 'CM-35-120', 10, '{"source": "excel"}'::jsonb);
    END IF;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' LIMIT 1;
  IF v_item IS NOT NULL THEN
      VALUES (v_org, 'MOTOR', v_item, 'RC3001-W', 20, '{"source": "excel"}'::jsonb);
    END IF;
  END IF;
END $$;
COMMIT;

-- Verify templates and component counts
select bt.code, bt.name, count(bc.id) as components
from public."BOMTemplates" bt
left join public."BOMComponents" bc on bc.bom_template_id=bt.id and bc.deleted=false
where bt.organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
group by bt.code, bt.name
order by bt.code;