-- ============================================================
-- Poblar BOMComponents según tabla Excel / Coulisse
-- - Resolución de sufijos: RCA-04→RCA-04-W/RCA-04-A, PU12→PU12-0400-MW,
--   CC1017→CC1017-W/CC1017-BK, CC1011→CC1011-W/CC1011-BK
-- - RC2013-M (bracket interm cassette) en templates DOBLE
-- - Roles canónicos en minúsculas
-- Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
-- ============================================================
BEGIN;
DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_template_id uuid;
  v_item uuid;
  v_sort int;
BEGIN

-- ==================== ROLLER_MANUAL_M (ROLLER_MANUAL_SINGLE) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_M' AND deleted=false LIMIT 1;
IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found: ROLLER_MANUAL_M'; END IF;
v_sort := 0;

-- drive RC3001-W 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='drive' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'drive', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- accessory/adapter RC3026 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3026' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- end_cap RC3005-W 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3005-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- idler RC2003-W 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2003-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- bracket RC3006-W 2
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- end_cap RC3007-W 2, RC3008-W 2, RCA-21-W 2
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- bottom_bar RCA-04 → RCA-04-W, else RCA-04-A
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- tube: user-selectable (NULL) o RTU-42/KTU-42 si existe
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 ELSE 1 END LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
END IF;

-- ==================== ROLLER_MANUAL_DOBLE_M (ROLLER_MANUAL_DOUBLE_M) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MANUAL_DOBLE_M' AND deleted=false LIMIT 1;
IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found: ROLLER_MANUAL_DOBLE_M'; END IF;
v_sort := 0;
-- drive RC3001-W 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='drive' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'drive', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- idler RC3085-W 1, RC3018 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- end_cap RCA-21-W 4, RC3007-W 2, RC3008-W 3, RCU-27 1, RCU-15 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- bracket RC3006-W 2, RC2013-M 1 (bracket interm cassette - destacado)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- bottom_bar RCA-04-W/RCA-04-A, tube
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 ELSE 1 END LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
END IF;

-- ==================== ROLLER_MOTORIZADA_M (ROLLER_MOTOR_SINGLE_M) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_M' AND deleted=false LIMIT 1;
IF v_template_id IS NULL THEN RAISE EXCEPTION 'Template not found: ROLLER_MOTORIZADA_M'; END IF;
v_sort := 0;
-- motor (user-selectable, NULL)
IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND component_item_id IS NULL AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- accessory RC3045-ABC 1, RC3044 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- idler RC3085-W 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- end_cap RCA-21-W 2, RC3007-W 2, RC3008-W 2, RCU-27 1, RCU-15 1
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- bracket RC3006-W 2, RC2011 1 (bracket interm metal M - SINGLE)
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND (sku='RC2011' OR sku='RC2011-W') AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
-- bottom_bar RCA-04-W/RCA-04-A, tube
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id IS NOT DISTINCT FROM v_item AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
END IF;
SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 ELSE 1 END LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
  INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
  VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
END IF;

-- ==================== ROLLER_MOTORIZADA_DOBLE_M (ROLLER_MOTOR_DOUBLE - Excel) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='ROLLER_MOTORIZADA_DOBLE_M' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- accessory RC3045-ABC 1, RC3044 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 4, RC3007-W 2, RC3008-W 3, RCU-27 1, RCU-15 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2013-M 1 (bracket interm cassette - doble)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A, tube
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 ELSE 1 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

RAISE NOTICE 'BOMComponents: ROLLER_MANUAL_M, ROLLER_MANUAL_DOBLE_M, ROLLER_MOTORIZADA_M, ROLLER_MOTORIZADA_DOBLE_M listos.';

-- ==================== MOTORIZADA_SENCILLA_L (ROLLER_MOTOR_L) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_SENCILLA_L' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- accessory RC3045-ABC 1, RC3044 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 2, RC3007-W 2, RC3008-W 2, RCU-27 1, RCU-15 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2011-L o RC2011 (bracket interm L)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND (sku='RC2011-L' OR sku='RC2011') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RC2011-L' THEN 0 ELSE 1 END LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A, tube RTU-65 (L size)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RTU-65' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== MOTORIZADA_DOBLE_L (ROLLER_MOTOR_L_DOUBLE) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='MOTORIZADA_DOBLE_L' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- accessory RC3045-ABC 1, RC3044 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 4, RC3007-W 2, RC3008-W 3, RCU-27 1, RCU-15 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2013-L o RC2013-M (bracket interm L)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND (sku='RC2013-L' OR sku='RC2013-M') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RC2013-L' THEN 0 ELSE 1 END LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A, tube RTU-65
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 1.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RTU-65' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

RAISE NOTICE 'BOMComponents: Roller M y L (Manual y Motor, Single y Double) listos.';
RAISE NOTICE 'Continúa con Dual, Triple y Drapery...';
END;
$$;
COMMIT;

-- ============================================================
-- PARTE 2: DUAL, TRIPLE Y DRAPERY
-- ============================================================
BEGIN;
DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_template_id uuid;
  v_item uuid;
  v_sort int;
BEGIN

-- ==================== DOBLE_SHADE (DUAL_MANUAL) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- drive RC3001-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='drive' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'drive', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1, RC3018 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 4, RC3007-W 2, RC3008-W 3, RCU-27 1, RCU-15 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2013-M 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A (2 para dual), tube RTU-42 o RTU-65 (user-selectable)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 2.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','RTU-65','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 WHEN sku='RTU-65' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 2.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== DOBLE_SHADE_MOTORIZADA (DUAL_MOTOR) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='DOBLE_SHADE_MOTORIZADA' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable, NULL)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- accessory RC3045-ABC 1, RC3044 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 4, RC3007-W 2, RC3008-W 3, RCU-27 1, RCU-15 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2013-M 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A (2 para dual), tube
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 2.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','RTU-65','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 WHEN sku='RTU-65' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 2.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

RAISE NOTICE 'BOMComponents: Dual (Manual y Motor) listos.';
END;
$$;
COMMIT;

-- ============================================================
-- PARTE 3: TRIPLE SHADE
-- ============================================================
BEGIN;
DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_template_id uuid;
  v_item uuid;
  v_sort int;
BEGIN

-- ==================== TRIPLE_SHADE (TRIPLE_MANUAL) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- drive RC3001-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3001-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='drive' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'drive', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1, RC3018 2 (triple necesita más idlers)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3018' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 6 (3 shades x 2), RC3007-W 3, RC3008-W 4, RCU-27 2, RCU-15 2
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 6.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2013-M 2 (triple necesita 2 brackets intermedios)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A (3 para triple), tube (3 para triple)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 3.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','RTU-65','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 WHEN sku='RTU-65' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 3.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== TRIPLE_SHADE_DOBLE (TRIPLE_MOTOR) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='TRIPLE_SHADE_DOBLE' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- accessory RC3045-ABC 1, RC3044 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3045-ABC' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3044' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- idler RC3085-W 1
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3085-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='idler' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'idler', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- end_cap RCA-21-W 6, RC3007-W 3, RC3008-W 4, RCU-27 2, RCU-15 2
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-21-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 6.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3007-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 3.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3008-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 4.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-27' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCU-15' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='end_cap' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'end_cap', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bracket RC3006-W 2, RC2013-M 2
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC3006-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RC2013-M' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bracket' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bracket', 'fixed', 2.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- bottom_bar RCA-04-W/RCA-04-A (3 para triple), tube (3)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='RCA-04-A' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='bottom_bar' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'bottom_bar', 'fixed', 3.0, 'linear', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('RTU-42','RTU-65','KTU-42') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='RTU-42' THEN 0 WHEN sku='RTU-65' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='tube' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'tube', 'fixed', 3.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

RAISE NOTICE 'BOMComponents: Triple (Manual y Motor) listos.';
END;
$$;
COMMIT;

-- ============================================================
-- PARTE 4: DRAPERY (RIEL)
-- ============================================================
BEGIN;
DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_template_id uuid;
  v_item uuid;
  v_sort int;
BEGIN

-- ==================== RIEL_MANUAL_RIPPLE (Drapery Manual Ripple) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_RIPPLE' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- drapery specific components: carritos, riel, etc. usando SKUs comunes
  -- carritos CC1017 → CC1017-W, else CC1017-BK
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- riel (track) - user-selectable o PU12 → PU12-0400-MW, PU12-TR
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('PU12-0400-MW','PU12-TR','PU12') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='PU12-0400-MW' THEN 0 WHEN sku='PU12-TR' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- cadena/chain (para manual)
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='chain' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'chain', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== RIEL_MANUAL_PLEAT (Drapery Manual Pleat) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MANUAL_PLEAT' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- Similar a RIPPLE pero con variaciones específicas de pleat
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('PU12-0400-MW','PU12-TR','PU12') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='PU12-0400-MW' THEN 0 WHEN sku='PU12-TR' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1011-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='chain' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'chain', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== RIEL_MOTORIZADO_RIPPLE (Drapery Motor Ripple) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_RIPPLE' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable, NULL)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- carritos CC1017-W/CC1017-BK
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- riel PU12-0400-MW/PU12-TR/PU12
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('PU12-0400-MW','PU12-TR','PU12') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='PU12-0400-MW' THEN 0 WHEN sku='PU12-TR' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== RIEL_MOTORIZADO_PLEAT (Drapery Motor Pleat) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='RIEL_MOTORIZADO_PLEAT' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- motor (user-selectable)
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='motor' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, NULL, 'motor', 'fixed', 1.0, 'ea', v_sort, false, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- carritos CC1017-W/CC1017-BK
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  -- riel PU12-0400-MW/PU12-TR/PU12
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('PU12-0400-MW','PU12-TR','PU12') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='PU12-0400-MW' THEN 0 WHEN sku='PU12-TR' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

-- ==================== PA_O_FIJO_RIPPLE_Y_PLEAT (Drapery Fixed) ====================
SELECT id INTO v_template_id FROM public."BOMTemplates" WHERE organization_id=v_org AND code='PA_O_FIJO_RIPPLE_Y_PLEAT' AND deleted=false LIMIT 1;
IF v_template_id IS NOT NULL THEN
  v_sort := 0;
  -- Similar a los otros drapery pero sin motor ni chain
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-W' AND (is_active IS NULL OR is_active=true) LIMIT 1;
  IF v_item IS NULL THEN SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku='CC1017-BK' AND (is_active IS NULL OR is_active=true) LIMIT 1; END IF;
  IF v_item IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='accessory' AND component_item_id=v_item AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'accessory', 'fixed', 1.0, 'ea', v_sort, true, 'ROLE_AND_COLOR', false, false); v_sort := v_sort + 10;
  END IF;
  SELECT id INTO v_item FROM public."CatalogItems" WHERE organization_id=v_org AND sku IN ('PU12-0400-MW','PU12-TR','PU12') AND (is_active IS NULL OR is_active=true) ORDER BY CASE WHEN sku='PU12-0400-MW' THEN 0 WHEN sku='PU12-TR' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT EXISTS (SELECT 1 FROM public."BOMComponents" WHERE organization_id=v_org AND bom_template_id=v_template_id AND component_role='track' AND deleted=false) THEN
    INSERT INTO public."BOMComponents"(organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived)
    VALUES (v_org, v_template_id, v_item, 'track', 'fixed', 1.0, 'linear', v_sort, (v_item IS NOT NULL), 'ROLE_AND_COLOR', false, false);
  END IF;
END IF;

RAISE NOTICE '✅ BOMComponents completados para todos los templates: Roller (M y L), Dual, Triple y Drapery.';
END;
$$;
COMMIT;
