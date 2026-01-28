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
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3001-W for template ROLLER_MANUAL_M role drive'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='drive' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'drive', 'fixed', 1.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3026 for template ROLLER_MANUAL_M role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3005-W for template ROLLER_MANUAL_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2003-W for template ROLLER_MANUAL_M role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MANUAL_M role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MANUAL_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MANUAL_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MANUAL_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04-W or RCA-04-A for template ROLLER_MANUAL_M role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 90, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: ROLLER_MANUAL_DOBLE_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_DOBLE_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MANUAL_DOBLE_M'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3001-W for template ROLLER_MANUAL_DOBLE_M role drive'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='drive' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'drive', 'fixed', 1.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template ROLLER_MANUAL_DOBLE_M role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MANUAL_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MANUAL_DOBLE_M role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MANUAL_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MANUAL_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template ROLLER_MANUAL_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template ROLLER_MANUAL_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template ROLLER_MANUAL_DOBLE_M role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template ROLLER_MANUAL_DOBLE_M role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 100, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04-W or RCA-04-A for template ROLLER_MANUAL_DOBLE_M role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: ROLLER_MOTORIZADA_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MOTORIZADA_M'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template ROLLER_MOTORIZADA_M role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template ROLLER_MOTORIZADA_M role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template ROLLER_MOTORIZADA_M role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MOTORIZADA_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MOTORIZADA_M role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MOTORIZADA_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MOTORIZADA_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 80, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04-W or RCA-04-A for template ROLLER_MOTORIZADA_M role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: ROLLER_MOTORIZADA_DOBLE_M
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_DOBLE_M' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: ROLLER_MOTORIZADA_DOBLE_M'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template ROLLER_MOTORIZADA_DOBLE_M role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template ROLLER_MOTORIZADA_DOBLE_M role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template ROLLER_MOTORIZADA_DOBLE_M role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template ROLLER_MOTORIZADA_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3006-W for template ROLLER_MOTORIZADA_DOBLE_M role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3007-W for template ROLLER_MOTORIZADA_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3008-W for template ROLLER_MOTORIZADA_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template ROLLER_MOTORIZADA_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template ROLLER_MOTORIZADA_DOBLE_M role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template ROLLER_MOTORIZADA_DOBLE_M role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template ROLLER_MOTORIZADA_DOBLE_M role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 120, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04-W or RCA-04-A for template ROLLER_MOTORIZADA_DOBLE_M role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 130, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: MOTORIZADA_SENCILLA_L
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_SENCILLA_L' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: MOTORIZADA_SENCILLA_L'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4023-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4023-ABC for template MOTORIZADA_SENCILLA_L role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template MOTORIZADA_SENCILLA_L role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template MOTORIZADA_SENCILLA_L role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template MOTORIZADA_SENCILLA_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4004-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4004-W for template MOTORIZADA_SENCILLA_L role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4005-W for template MOTORIZADA_SENCILLA_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4006-W for template MOTORIZADA_SENCILLA_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template MOTORIZADA_SENCILLA_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-13-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-13-W for template MOTORIZADA_SENCILLA_L role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 2.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 100, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04-W or RCA-04-A for template MOTORIZADA_SENCILLA_L role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: MOTORIZADA_DOBLE_L
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_DOBLE_L' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: MOTORIZADA_DOBLE_L'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4023-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4023-ABC for template MOTORIZADA_DOBLE_L role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template MOTORIZADA_DOBLE_L role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template MOTORIZADA_DOBLE_L role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-21-W for template MOTORIZADA_DOBLE_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4004-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4004-W for template MOTORIZADA_DOBLE_L role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4005-W for template MOTORIZADA_DOBLE_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4006-W for template MOTORIZADA_DOBLE_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-13-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-13-W for template MOTORIZADA_DOBLE_L role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 4.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template MOTORIZADA_DOBLE_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template MOTORIZADA_DOBLE_L role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template MOTORIZADA_DOBLE_L role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC4014-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC4014-W for template MOTORIZADA_DOBLE_L role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 120, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 130, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCA-04-W or RCA-04-A for template MOTORIZADA_DOBLE_L role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 140, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: DOBLE_SHADE_MOTORIZADA
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE_MOTORIZADA' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: DOBLE_SHADE_MOTORIZADA'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template DOBLE_SHADE_MOTORIZADA role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template DOBLE_SHADE_MOTORIZADA role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template DOBLE_SHADE_MOTORIZADA role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template DOBLE_SHADE_MOTORIZADA role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-03-W for template DOBLE_SHADE_MOTORIZADA role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-05-W for template DOBLE_SHADE_MOTORIZADA role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-07-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-07-W for template DOBLE_SHADE_MOTORIZADA role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 110, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template DOBLE_SHADE_MOTORIZADA role headbox'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='headbox' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'headbox', 'fixed', 1.0, 'linear', 120, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 130, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template DOBLE_SHADE_MOTORIZADA role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 140, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template DOBLE_SHADE_MOTORIZADA role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 150, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template DOBLE_SHADE_MOTORIZADA role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 160, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 170, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template DOBLE_SHADE_MOTORIZADA role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 180, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 4.0, 'ea', 190, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 4.0, 'ea', 200, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-03-W for template DOBLE_SHADE_MOTORIZADA role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', 210, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template DOBLE_SHADE_MOTORIZADA role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 220, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template DOBLE_SHADE_MOTORIZADA role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 230, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 240, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template DOBLE_SHADE_MOTORIZADA role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 250, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-05-W for template DOBLE_SHADE_MOTORIZADA role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 260, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-07-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-07-W for template DOBLE_SHADE_MOTORIZADA role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 270, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 280, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template DOBLE_SHADE_MOTORIZADA role headbox'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='headbox' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'headbox', 'fixed', 1.0, 'linear', 290, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: TRIPLE_SHADE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: TRIPLE_SHADE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template TRIPLE_SHADE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template TRIPLE_SHADE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template TRIPLE_SHADE role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template TRIPLE_SHADE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template TRIPLE_SHADE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template TRIPLE_SHADE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template TRIPLE_SHADE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 80, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template TRIPLE_SHADE role headbox'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='headbox' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'headbox', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: TRIPLE_SHADE_DOBLE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE_DOBLE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: TRIPLE_SHADE_DOBLE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3045-ABC for template TRIPLE_SHADE_DOBLE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3044 for template TRIPLE_SHADE_DOBLE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3085-W for template TRIPLE_SHADE_DOBLE role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template TRIPLE_SHADE_DOBLE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template TRIPLE_SHADE_DOBLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template TRIPLE_SHADE_DOBLE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 4.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template TRIPLE_SHADE_DOBLE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 4.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-27 for template TRIPLE_SHADE_DOBLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RCU-15 for template TRIPLE_SHADE_DOBLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3018 for template TRIPLE_SHADE_DOBLE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2013-M for template TRIPLE_SHADE_DOBLE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', 110, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 120, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template TRIPLE_SHADE_DOBLE role headbox'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='headbox' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'headbox', 'fixed', 1.0, 'linear', 130, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: PA_O_FIJO_RIPPLE_Y_PLEAT
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='PA_O_FIJO_RIPPLE_Y_PLEAT' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: PA_O_FIJO_RIPPLE_Y_PLEAT'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1023-W for template PA_O_FIJO_RIPPLE_Y_PLEAT role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017-W or CC1017-BK for template PA_O_FIJO_RIPPLE_Y_PLEAT role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template PA_O_FIJO_RIPPLE_Y_PLEAT role track'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MANUAL_RIPPLE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_RIPPLE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MANUAL_RIPPLE'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1023-W for template RIEL_MANUAL_RIPPLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017-W or CC1017-BK for template RIEL_MANUAL_RIPPLE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1025-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1025-W for template RIEL_MANUAL_RIPPLE role carrier'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='carrier' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'carrier', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1026-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1026-W for template RIEL_MANUAL_RIPPLE role carrier'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='carrier' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'carrier', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU12-0400-MW' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU12-0400-MW for template RIEL_MANUAL_RIPPLE role wand'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='wand' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'wand', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU14-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU14-TR for template RIEL_MANUAL_RIPPLE role wand'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='wand' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'wand', 'fixed', 4.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MANUAL_RIPPLE role track'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MANUAL_PLEAT
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_PLEAT' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MANUAL_PLEAT'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1023-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1023-W for template RIEL_MANUAL_PLEAT role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017-W or CC1017-BK for template RIEL_MANUAL_PLEAT role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1011-W or CC1011-BK for template RIEL_MANUAL_PLEAT role carrier'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='carrier' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'carrier', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU12-0400-MW' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU12-0400-MW for template RIEL_MANUAL_PLEAT role wand'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='wand' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'wand', 'fixed', 2.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='PU14-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code PU14-TR for template RIEL_MANUAL_PLEAT role wand'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='wand' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'wand', 'fixed', 4.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MANUAL_PLEAT role track'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MOTORIZADO_RIPPLE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_RIPPLE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MOTORIZADO_RIPPLE'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017-W or CC1017-BK for template RIEL_MOTORIZADO_RIPPLE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1025-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1025-W for template RIEL_MOTORIZADO_RIPPLE role carrier'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='carrier' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'carrier', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1026-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1026-W for template RIEL_MOTORIZADO_RIPPLE role carrier'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='carrier' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'carrier', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1002' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1002 for template RIEL_MOTORIZADO_RIPPLE role belt'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='belt' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'belt', 'fixed', 1.0, 'linear', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1009' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1009 for template RIEL_MOTORIZADO_RIPPLE role belt_connector'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='belt_connector' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'belt_connector', 'fixed', 1.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 50, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1019-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1019-W for template RIEL_MOTORIZADO_RIPPLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1006-W for template RIEL_MOTORIZADO_RIPPLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1005-W for template RIEL_MOTORIZADO_RIPPLE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1032-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1032-TR for template RIEL_MOTORIZADO_RIPPLE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 2.0, 'ea', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MOTORIZADO_RIPPLE role track'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: RIEL_MOTORIZADO_PLEAT
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_PLEAT' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: RIEL_MOTORIZADO_PLEAT'; END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1017-W or CC1017-BK for template RIEL_MOTORIZADO_PLEAT role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 0, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-W' LIMIT 1;
  IF v_item IS NULL THEN
    SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-BK' LIMIT 1;
  END IF;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1011-W or CC1011-BK for template RIEL_MOTORIZADO_PLEAT role carrier'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='carrier' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'carrier', 'fixed', 2.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1002' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1002 for template RIEL_MOTORIZADO_PLEAT role belt'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='belt' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'belt', 'fixed', 1.0, 'linear', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1009' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1009 for template RIEL_MOTORIZADO_PLEAT role belt_connector'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='belt_connector' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'belt_connector', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 40, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1019-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1019-W for template RIEL_MOTORIZADO_PLEAT role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1006-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1006-W for template RIEL_MOTORIZADO_PLEAT role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1005-W for template RIEL_MOTORIZADO_PLEAT role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1007-TR' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1007-TR for template RIEL_MOTORIZADO_PLEAT role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 2.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1001-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code CC1001-W for template RIEL_MOTORIZADO_PLEAT role track'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  -- Template: DOBLE_SHADE
  SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE' LIMIT 1;
  IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found after insert: DOBLE_SHADE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', 0, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3026 for template DOBLE_SHADE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 10, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3005-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3005-W for template DOBLE_SHADE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', 20, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC2003-W for template DOBLE_SHADE role idler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', 30, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3025' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3025 for template DOBLE_SHADE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 40, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3052-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3052-W for template DOBLE_SHADE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 50, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3024-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3024-W for template DOBLE_SHADE role bracket'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', 60, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3048-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3048-W for template DOBLE_SHADE role accessory'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 2.0, 'ea', 70, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-03-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-03-W for template DOBLE_SHADE role end_cap'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', 80, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-05-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-05-W for template DOBLE_SHADE role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 90, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='DRC-07-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code DRC-07-W for template DOBLE_SHADE role bottom_bar'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', 100, true, 'ROLE_AND_COLOR', false, false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND component_item_id IS NULL) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'tube', 'fixed', 1.0, 'linear', 110, false, 'ROLE_AND_COLOR', false, false);
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3051-W' LIMIT 1;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Missing CatalogItems SKU/code RC3051-W for template DOBLE_SHADE role headbox'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='headbox' AND component_item_id=v_item) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'headbox', 'fixed', 1.0, 'linear', 120, true, 'ROLE_AND_COLOR', false, false);
  END IF;

END;
$$;
COMMIT;

-- Verify templates and component counts
select bt.code, bt.name, count(bc.id) as components
from public."BOMTemplates" bt
left join public."BOMComponents" bc on bc.bom_template_id=bt.id and bc.deleted=false
where bt.organization_id='3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
group by bt.code, bt.name
order by bt.code;