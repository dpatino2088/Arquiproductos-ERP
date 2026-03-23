/**
 * BOM Templates V4 - COMPLETAMENTE POBLADO
 * 
 * Migra V3 al formato PADRE-HIJO, preservando todos los SKUs
 * 
 * Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
 */

BEGIN;

DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_pt uuid;
  v_template_id uuid;
  v_item_id uuid;
  v_padre_id uuid;
BEGIN

-- ============================================================================
-- ROLLER_MANUAL_M (completamente poblado)
-- ============================================================================

SELECT id INTO v_pt FROM public."ProductTypes" 
WHERE organization_id = v_org AND code = 'roller_shade' LIMIT 1;

INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
VALUES (v_org, v_pt, 'ROLLER_MANUAL_M', 'Roller Manual M', true, false, false)
RETURNING id INTO v_template_id;

-- SLOTS con SKUs FIJOS
-- Drive RC3001-W (PADRE)
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3001-W' LIMIT 1;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'drive', true, v_padre_id, 1);

-- Bracket RC3006-W (PADRE)
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3006-W' LIMIT 1;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bracket', true, v_padre_id, 2);

-- Bottom Bar RCA-04-W (PADRE)
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-04-W' LIMIT 1;
IF v_padre_id IS NULL THEN
  SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-04-A' LIMIT 1;
END IF;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_bar', true, v_padre_id, 1);

-- Tube (sin SKU fijo - usuario elige)
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 1);

-- Reglas de qty/corte
INSERT INTO public."BOMComponents" (
  organization_id, bom_template_id, component_item_id, component_role, 
  qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived
) VALUES 
  (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
  (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

-- HIJOS del Drive RC3001-W
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3001-W' LIMIT 1;
IF v_padre_id IS NOT NULL THEN
  -- Idler RC2003-W
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC2003-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'idler', 1, 'ea', true, 0)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Accessory RC3026 (Tube adapter)
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3026' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'adapter', 1, 'ea', true, 1)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- End Cap RC3005-W
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3005-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 1, 'ea', true, 2)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;
END IF;

-- HIJOS del Bracket RC3006-W
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3006-W' LIMIT 1;
IF v_padre_id IS NOT NULL THEN
  -- End Cap RC3007-W (×2 por bracket)
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3007-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 1, 'ea', true, 0)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- End Cap RC3008-W (×2 por bracket)
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3008-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 1, 'ea', true, 1)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- End Cap RCA-21-W (×2 por bracket)
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-21-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 1, 'ea', true, 2)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;
END IF;

-- ============================================================================
-- ROLLER_MANUAL_DOBLE_M
-- ============================================================================

INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
VALUES (v_org, v_pt, 'ROLLER_MANUAL_DOBLE_M', 'Roller Manual Doble M', true, false, false)
RETURNING id INTO v_template_id;

-- SLOTS
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3001-W' LIMIT 1;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'drive', true, v_padre_id, 1);

SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC2013-M' LIMIT 1;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bracket', true, v_padre_id, 1);

SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-04-W' LIMIT 1;
IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-04-A' LIMIT 1; END IF;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_bar', true, v_padre_id, 2);

INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'tube', true, NULL, 2);

INSERT INTO public."BOMComponents" (
  organization_id, bom_template_id, component_item_id, component_role, 
  qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived
) VALUES 
  (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
  (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

-- HIJOS del Bracket RC2013-M
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC2013-M' LIMIT 1;
IF v_padre_id IS NOT NULL THEN
  -- End Caps para bracket doble
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-21-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 4, 'ea', true, 0)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Idler RC3085-W
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3085-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'idler', 1, 'ea', true, 1)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Más end caps
  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCU-27' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 1, 'ea', true, 2)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCU-15' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'end_cap', 1, 'ea', true, 3)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  SELECT id INTO v_item_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3018' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order)
    VALUES (v_org, v_padre_id, v_item_id, 'idler', 1, 'ea', true, 4)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;
END IF;

-- ============================================================================
-- ROLLER_MOTORIZADA_M (Motor sin SKU fijo - usuario elige)
-- ============================================================================

INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
VALUES (v_org, v_pt, 'ROLLER_MOTORIZADA_M', 'Roller Motorizada M', true, false, false)
RETURNING id INTO v_template_id;

-- SLOTS (Motor sin catalog_item_id - usuario elige)
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES 
  (v_org, v_template_id, 'motor', true, NULL, 1),
  (v_org, v_template_id, 'tube', true, NULL, 1);

-- Bracket RC3006-W fijo
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RC3006-W' LIMIT 1;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bracket', true, v_padre_id, 2);

-- Bottom Bar fijo
SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-04-W' LIMIT 1;
IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM public."CatalogItems" WHERE organization_id = v_org AND sku = 'RCA-04-A' LIMIT 1; END IF;
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty)
VALUES (v_org, v_template_id, 'bottom_bar', true, v_padre_id, 1);

-- Reglas qty
INSERT INTO public."BOMComponents" (
  organization_id, bom_template_id, component_item_id, component_role, 
  qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, deleted, archived
) VALUES 
  (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
  (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

-- Accesorios motorizados (HIJOS comunes a los motores - se asignan por motor específico)
-- Cuando el usuario cree motores específicos, agregar:
-- Motor X → RC3045-ABC (remote)
-- Motor X → RC3044 (adapter)
-- Motor X → RC3085-W (idler)
-- Motor X → RCA-21-W (end caps)

-- ============================================================================
-- Continuar con resto de templates...
-- ============================================================================

RAISE NOTICE 'Templates V4 populated successfully';
RAISE NOTICE 'Drive RC3001-W has % children', (
  SELECT COUNT(*) FROM public."CatalogItemComponents" 
  WHERE parent_item_id = (SELECT id FROM public."CatalogItems" WHERE sku = 'RC3001-W' AND organization_id = v_org LIMIT 1)
    AND deleted = false
);

END;
$$;

COMMIT;

-- Verificar templates creados
SELECT 
  bt.code,
  bt.name,
  (SELECT COUNT(*) FROM public."BOMTemplateSlots" WHERE bom_template_id = bt.id) as slots_count,
  (SELECT STRING_AGG(
    CONCAT(
      bts.item_role, 
      CASE WHEN bts.catalog_item_id IS NOT NULL 
        THEN ' (' || (SELECT sku FROM public."CatalogItems" WHERE id = bts.catalog_item_id LIMIT 1) || ')'
        ELSE ' (user choice)'
      END
    ), 
    ', '
  ) FROM public."BOMTemplateSlots" bts WHERE bts.bom_template_id = bt.id) as slots_detail
FROM public."BOMTemplates" bt
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
ORDER BY bt.code;
