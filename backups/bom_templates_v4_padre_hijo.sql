/**
 * BOM Templates V4 - Formato PADRE-HIJO
 * 
 * Basado en: bom_templates_optionA_fixed_v3.sql
 * Nuevo formato:
 * - BOMTemplateSlots: Define roles PADRE que el usuario elige
 * - BOMComponents: Solo reglas de qty/corte (opcional)
 * - CatalogItemComponents: Relación SKU → HIJOS
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
  v_drive_rc3001 uuid;
  v_bracket_rc3006 uuid;
BEGIN

-- ============================================================================
-- 1. SOFT-DELETE TEMPLATES EXISTENTES (para regenerar limpio)
-- ============================================================================
UPDATE public."BOMTemplates" 
SET deleted = true 
WHERE organization_id = v_org 
  AND code IN (
    'ROLLER_MANUAL_M', 'ROLLER_MANUAL_DOBLE_M', 'ROLLER_MOTORIZADA_M', 
    'ROLLER_MOTORIZADA_DOBLE_M', 'MOTORIZADA_SENCILLA_L', 'MOTORIZADA_DOBLE_L',
    'DOBLE_SHADE_MOTORIZADA', 'TRIPLE_SHADE', 'TRIPLE_SHADE_DOBLE',
    'PA_O_FIJO_RIPPLE_Y_PLEAT', 'RIEL_MANUAL_RIPPLE', 'RIEL_MANUAL_PLEAT',
    'RIEL_MOTORIZADO_RIPPLE', 'RIEL_MOTORIZADO_PLEAT', 'DOBLE_SHADE'
  );

-- ============================================================================
-- 2. CREAR TEMPLATES ROLLER SHADE
-- ============================================================================

SELECT id INTO v_pt FROM public."ProductTypes" 
WHERE organization_id = v_org AND code = 'roller_shade' LIMIT 1;

IF v_pt IS NULL THEN 
  RAISE EXCEPTION 'Missing ProductTypes.code=roller_shade'; 
END IF;

-- Template: ROLLER_MANUAL_M
INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
VALUES (v_org, v_pt, 'ROLLER_MANUAL_M', 'Roller Manual M', true, false, false)
RETURNING id INTO v_template_id;

-- ✅ Crear SLOTS (PADRES)
INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
VALUES 
  (v_org, v_template_id, 'drive', true, 1),
  (v_org, v_template_id, 'bracket', true, 2),
  (v_org, v_template_id, 'bottom_bar', true, 1),
  (v_org, v_template_id, 'tube', true, 1);

-- ✅ Crear COMPONENTS para reglas de qty/corte (opcional)
INSERT INTO public."BOMComponents" (
  organization_id, bom_template_id, component_item_id, component_role, 
  qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
  deleted, archived
) VALUES 
  (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
  (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

-- ✅ HIJOS: Drive RC3001-W → Idler, End Caps, Accessory
SELECT id INTO v_drive_rc3001 FROM public."CatalogItems" 
WHERE organization_id = v_org AND sku = 'RC3001-W' LIMIT 1;

SELECT id INTO v_bracket_rc3006 FROM public."CatalogItems" 
WHERE organization_id = v_org AND sku = 'RC3006-W' LIMIT 1;

IF v_drive_rc3001 IS NOT NULL THEN
  -- Drive → Idler RC2003-W
  SELECT id INTO v_item_id FROM public."CatalogItems" 
  WHERE organization_id = v_org AND sku = 'RC2003-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (
      organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
    ) VALUES (v_org, v_drive_rc3001, v_item_id, 'idler', 1, 'ea', true, 0)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Drive → Accessory RC3026 (Tube adapter)
  SELECT id INTO v_item_id FROM public."CatalogItems" 
  WHERE organization_id = v_org AND sku = 'RC3026' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (
      organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
    ) VALUES (v_org, v_drive_rc3001, v_item_id, 'adapter', 1, 'ea', true, 1)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Drive → End Cap RC3005-W
  SELECT id INTO v_item_id FROM public."CatalogItems" 
  WHERE organization_id = v_org AND sku = 'RC3005-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (
      organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
    ) VALUES (v_org, v_drive_rc3001, v_item_id, 'end_cap', 1, 'ea', true, 2)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;
END IF;

IF v_bracket_rc3006 IS NOT NULL THEN
  -- Bracket RC3006-W → End Caps RC3007-W (×2)
  SELECT id INTO v_item_id FROM public."CatalogItems" 
  WHERE organization_id = v_org AND sku = 'RC3007-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (
      organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
    ) VALUES (v_org, v_bracket_rc3006, v_item_id, 'end_cap', 2, 'ea', true, 0)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Bracket RC3006-W → End Caps RC3008-W (×2)
  SELECT id INTO v_item_id FROM public."CatalogItems" 
  WHERE organization_id = v_org AND sku = 'RC3008-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (
      organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
    ) VALUES (v_org, v_bracket_rc3006, v_item_id, 'end_cap', 2, 'ea', true, 1)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;

  -- Bracket RC3006-W → End Cap RCA-21-W (×2)
  SELECT id INTO v_item_id FROM public."CatalogItems" 
  WHERE organization_id = v_org AND sku = 'RCA-21-W' LIMIT 1;
  IF v_item_id IS NOT NULL THEN
    INSERT INTO public."CatalogItemComponents" (
      organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
    ) VALUES (v_org, v_bracket_rc3006, v_item_id, 'end_cap', 2, 'ea', true, 2)
    ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
  END IF;
END IF;

-- ============================================================================
-- 3. Template: ROLLER_MANUAL_DOBLE_M (Doble con Drive)
-- ============================================================================

INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
VALUES (v_org, v_pt, 'ROLLER_MANUAL_DOBLE_M', 'Roller Manual Doble M', true, false, false)
RETURNING id INTO v_template_id;

INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
VALUES 
  (v_org, v_template_id, 'drive', true, 1),
  (v_org, v_template_id, 'bracket', true, 2),
  (v_org, v_template_id, 'bottom_bar', true, 2), -- Doble = 2 bottom bars
  (v_org, v_template_id, 'tube', true, 2); -- Doble = 2 tubes

INSERT INTO public."BOMComponents" (
  organization_id, bom_template_id, component_item_id, component_role, 
  qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
  deleted, archived
) VALUES 
  (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
  (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

-- Bracket para doble: RC2013-M (tiene sus propios HIJOS)
SELECT id INTO v_item_id FROM public."CatalogItems" 
WHERE organization_id = v_org AND sku = 'RC2013-M' LIMIT 1;

IF v_item_id IS NOT NULL THEN
  -- RC2013-M → End Caps RCA-21-W (×4 para doble)
  DECLARE
    v_end_cap_id uuid;
  BEGIN
    SELECT id INTO v_end_cap_id FROM public."CatalogItems" 
    WHERE organization_id = v_org AND sku = 'RCA-21-W' LIMIT 1;
    IF v_end_cap_id IS NOT NULL THEN
      INSERT INTO public."CatalogItemComponents" (
        organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
      ) VALUES (v_org, v_item_id, v_end_cap_id, 'end_cap', 4, 'ea', true, 0)
      ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
    END IF;
  END;
END IF;

-- ============================================================================
-- 4. Templates MOTORIZADOS (Motor + Brackets + Tubes)
-- ============================================================================

-- ROLLER_MOTORIZADA_M
INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
VALUES (v_org, v_pt, 'ROLLER_MOTORIZADA_M', 'Roller Motorizada M', true, false, false)
RETURNING id INTO v_template_id;

INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
VALUES 
  (v_org, v_template_id, 'motor', true, 1),
  (v_org, v_template_id, 'bracket', true, 2),
  (v_org, v_template_id, 'bottom_bar', true, 1),
  (v_org, v_template_id, 'tube', true, 1);

INSERT INTO public."BOMComponents" (
  organization_id, bom_template_id, component_item_id, component_role, 
  qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
  deleted, archived
) VALUES 
  (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
  (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

-- Motor (sin SKU fijo - usuario elige) tiene accesorios:
-- Nota: Los HIJOS del motor se asignarán cuando se cree el SKU específico del motor

-- Bracket RC3006-W ya tiene sus HIJOS definidos arriba

-- ============================================================================
-- 5. DUAL SHADE Templates
-- ============================================================================

SELECT id INTO v_pt FROM public."ProductTypes" 
WHERE organization_id = v_org AND code = 'dual_shade' LIMIT 1;

IF v_pt IS NOT NULL THEN
  -- DOBLE_SHADE_MOTORIZADA
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'DOBLE_SHADE_MOTORIZADA', 'Doble Shade Motorizada', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'motor', true, 1),
    (v_org, v_template_id, 'bracket', true, 4), -- Dual = más brackets
    (v_org, v_template_id, 'bottom_bar', true, 2),
    (v_org, v_template_id, 'tube', true, 2),
    (v_org, v_template_id, 'headbox', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'headbox', 'per_width', 1.0, 'm', 3, false, 'ROLE_AND_COLOR', false, false);

  -- DOBLE_SHADE (sin motor)
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'DOBLE_SHADE', 'Doble Shade', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'motor', true, 1),
    (v_org, v_template_id, 'bracket', true, 2),
    (v_org, v_template_id, 'bottom_bar', true, 2),
    (v_org, v_template_id, 'tube', true, 2),
    (v_org, v_template_id, 'headbox', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'bottom_bar', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'headbox', 'per_width', 1.0, 'm', 3, false, 'ROLE_AND_COLOR', false, false);
END IF;

-- ============================================================================
-- 6. TRIPLE SHADE Templates
-- ============================================================================

SELECT id INTO v_pt FROM public."ProductTypes" 
WHERE organization_id = v_org AND code = 'triple_shade' LIMIT 1;

IF v_pt IS NOT NULL THEN
  -- TRIPLE_SHADE
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'TRIPLE_SHADE', 'Triple Shade', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'motor', true, 1),
    (v_org, v_template_id, 'bracket', true, 4),
    (v_org, v_template_id, 'tube', true, 1),
    (v_org, v_template_id, 'headbox', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'headbox', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);

  -- TRIPLE_SHADE_DOBLE
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'TRIPLE_SHADE_DOBLE', 'Triple Shade Doble', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'motor', true, 1),
    (v_org, v_template_id, 'bracket', true, 6),
    (v_org, v_template_id, 'tube', true, 1),
    (v_org, v_template_id, 'headbox', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'tube', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'headbox', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);
END IF;

-- ============================================================================
-- 7. DRAPERY Templates
-- ============================================================================

SELECT id INTO v_pt FROM public."ProductTypes" 
WHERE organization_id = v_org AND code = 'drapery' LIMIT 1;

IF v_pt IS NOT NULL THEN
  -- PA_O_FIJO_RIPPLE_Y_PLEAT (Paño Fijo)
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'PA_O_FIJO_RIPPLE_Y_PLEAT', 'Paño Fijo (Ripple y Pleat)', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'bracket', true, 2),
    (v_org, v_template_id, 'track', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'track', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false);

  -- Track CC1001-W → End Caps CC1023-W
  DECLARE
    v_track_id uuid;
    v_end_cap_id uuid;
  BEGIN
    SELECT id INTO v_track_id FROM public."CatalogItems" 
    WHERE organization_id = v_org AND sku = 'CC1001-W' LIMIT 1;
    
    SELECT id INTO v_end_cap_id FROM public."CatalogItems" 
    WHERE organization_id = v_org AND sku = 'CC1023-W' LIMIT 1;
    
    IF v_track_id IS NOT NULL AND v_end_cap_id IS NOT NULL THEN
      INSERT INTO public."CatalogItemComponents" (
        organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, sort_order
      ) VALUES (v_org, v_track_id, v_end_cap_id, 'end_cap', 2, 'ea', true, 0)
      ON CONFLICT (organization_id, parent_item_id, child_item_id) WHERE deleted = false DO NOTHING;
    END IF;
  END;

  -- RIEL_MANUAL_RIPPLE
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'RIEL_MANUAL_RIPPLE', 'Riel Manual (Ripple)', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'bracket', true, 2),
    (v_org, v_template_id, 'carrier', true, 2),
    (v_org, v_template_id, 'wand', true, 2),
    (v_org, v_template_id, 'track', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'track', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false);

  -- RIEL_MOTORIZADO_RIPPLE
  INSERT INTO public."BOMTemplates" (organization_id, product_type_id, code, name, active, deleted, archived)
  VALUES (v_org, v_pt, 'RIEL_MOTORIZADO_RIPPLE', 'Riel Motorizado (Ripple)', true, false, false)
  RETURNING id INTO v_template_id;

  INSERT INTO public."BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, qty)
  VALUES 
    (v_org, v_template_id, 'motor', true, 1),
    (v_org, v_template_id, 'bracket', true, 2),
    (v_org, v_template_id, 'carrier', true, 2),
    (v_org, v_template_id, 'belt', true, 1),
    (v_org, v_template_id, 'belt_connector', true, 1),
    (v_org, v_template_id, 'track', true, 1);

  INSERT INTO public."BOMComponents" (
    organization_id, bom_template_id, component_item_id, component_role, 
    qty_type, qty_value, uom, sort_order, auto_select, sku_resolution_rule, 
    deleted, archived
  ) VALUES 
    (v_org, v_template_id, NULL, 'belt', 'per_width', 1.0, 'm', 1, false, 'ROLE_AND_COLOR', false, false),
    (v_org, v_template_id, NULL, 'track', 'per_width', 1.0, 'm', 2, false, 'ROLE_AND_COLOR', false, false);
END IF;

-- ============================================================================
-- 8. VERIFICACIÓN FINAL
-- ============================================================================

RAISE NOTICE '========================================';
RAISE NOTICE 'BOM Templates V4 - PADRE-HIJO Created Successfully';
RAISE NOTICE '========================================';
RAISE NOTICE '';
RAISE NOTICE 'Templates created - verify in /catalog/bom';
RAISE NOTICE '';
RAISE NOTICE 'Next steps:';
RAISE NOTICE '1. Verify templates in /catalog/bom';
RAISE NOTICE '2. Click green button 📦 to manage child components';
RAISE NOTICE '3. Add children (adapters, end_caps, screws) for each parent SKU';

END;
$$;

-- ============================================================================
-- VERIFICACIÓN: Contar Slots y Components
-- ============================================================================

SELECT 
  bt.code,
  bt.name,
  COUNT(DISTINCT bts.id) as slots_count,
  COUNT(DISTINCT bc.id) as components_count,
  STRING_AGG(DISTINCT bts.item_role, ', ' ORDER BY bts.item_role) as parent_roles
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
LEFT JOIN public."BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
GROUP BY bt.code, bt.name
ORDER BY bt.code;

COMMIT;

-- ============================================================================
-- NOTAS FINALES
-- ============================================================================

-- ✅ Templates creados con:
--   - BOMTemplateSlots: Define roles PADRE (drive, motor, bracket, tube, etc)
--   - BOMComponents: Solo reglas de qty/corte (per_width, etc)
--   - SIN catalog_item_id fijo (usuario elige en configurador)

-- ✅ Próximos pasos MANUALES (usar UI o SQL):
--   1. Asignar HIJOS a SKUs PADRE específicos via CatalogItemComponents
--   2. Ejemplo: Drive RC3001-W → Idler, Adapter, End Caps
--   3. Usar botón verde 📦 en BOM Templates UI

-- ✅ Ejemplo de asignación manual:
/*
-- Ver SKUs PADRE
SELECT id, sku, name, item_role FROM "CatalogItems" 
WHERE item_role IN ('drive', 'motor', 'bracket') AND is_active = true;

-- Asignar HIJOS a Drive RC3001-W
INSERT INTO "CatalogItemComponents" (
  organization_id, parent_item_id, child_item_id, child_role, qty, uom
) VALUES 
  ('3acbb54c...', 'ID_RC3001_W', 'ID_IDLER', 'idler', 1, 'ea'),
  ('3acbb54c...', 'ID_RC3001_W', 'ID_ADAPTER', 'adapter', 1, 'ea'),
  ('3acbb54c...', 'ID_RC3001_W', 'ID_END_CAP', 'end_cap', 1, 'ea');
*/
