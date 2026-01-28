/**
 * Migración AUTOMÁTICA: V3 → V4 (PADRE-HIJO)
 * 
 * Lee tus BOMComponents existentes y los migra al nuevo formato:
 * - PADRES → BOMTemplateSlots (con catalog_item_id si está definido)
 * - HIJOS detectados → CatalogItemComponents
 * - Reglas qty → BOMComponents (sin catalog_item_id)
 * 
 * Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
 */

BEGIN;

DO $$
DECLARE
  v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
  v_template RECORD;
  v_comp RECORD;
  v_is_padre boolean;
  v_padres_roles text[] := ARRAY[
    'motor', 'drive', 'bracket', 'tube', 'bottom_bar', 'bottom_rail', 'headbox',
    'cassette', 'side_channel', 'bottom_channel', 'track', 'carrier', 'belt', 'wand'
  ];
  v_hijos_roles text[] := ARRAY[
    'idler', 'end_cap', 'adapter', 'accessory', 'chain', 'chain_stop',
    'chain_tensioner', 'screw', 'fastener', 'end_plug', 'filler', 'belt_connector',
    'washer', 'nut', 'bolt', 'clip', 'pin'
  ];
  v_migrated_slots integer := 0;
  v_migrated_children integer := 0;
  v_slot_exists boolean;
  v_role_norm text;
BEGIN

RAISE NOTICE '========================================';
RAISE NOTICE 'Migración Automática V3 → V4';
RAISE NOTICE '========================================';

-- Iterar sobre cada template existente
FOR v_template IN 
  SELECT * FROM public."BOMTemplates" 
  WHERE organization_id = v_org 
    AND deleted = false
  ORDER BY code
LOOP
  RAISE NOTICE 'Migrando template: % (%)', v_template.code, v_template.name;
  
  -- Iterar sobre componentes del template
  FOR v_comp IN
    SELECT * FROM public."BOMComponents"
    WHERE organization_id = v_org
      AND bom_template_id = v_template.id
      AND deleted = false
      AND archived = false
    ORDER BY sort_order ASC
  LOOP
    -- Determinar si es PADRE o HIJO
    v_role_norm := regexp_replace(lower(coalesce(v_comp.component_role, '')), '[^a-z0-9]+', '_', 'g');
    v_is_padre := v_role_norm = ANY(v_padres_roles);
    -- Si tiene SKU y no es rol HIJO, también es PADRE
    IF (v_comp.component_item_id IS NOT NULL) AND (NOT (v_role_norm = ANY(v_hijos_roles))) THEN
      v_is_padre := true;
    END IF;
    
    IF v_is_padre THEN
      -- ✅ Es PADRE → Crear BOMTemplateSlot
      
      -- Verificar si ya existe el slot
      SELECT EXISTS (
        SELECT 1 FROM public."BOMTemplateSlots"
        WHERE organization_id = v_org
          AND bom_template_id = v_template.id
          AND item_role = v_role_norm
      ) INTO v_slot_exists;
      
      IF NOT v_slot_exists THEN
        INSERT INTO public."BOMTemplateSlots" (
          organization_id,
          bom_template_id,
          item_role,
          required,
          catalog_item_id,
          qty,
          notes
        ) VALUES (
          v_org,
          v_template.id,
          v_role_norm,
          true,
          v_comp.component_item_id, -- Puede ser NULL (usuario elige)
          v_comp.qty_value,
          'Migrated from BOMComponents'
        );
        
        v_migrated_slots := v_migrated_slots + 1;
        
        RAISE NOTICE '  → Slot: % (SKU: %)', 
          v_role_norm, 
          CASE WHEN v_comp.component_item_id IS NOT NULL 
            THEN (SELECT sku FROM public."CatalogItems" WHERE id = v_comp.component_item_id LIMIT 1)
            ELSE 'user choice'
          END;
      ELSE
        -- Si existe slot pero sin SKU, actualizarlo
        IF v_comp.component_item_id IS NOT NULL THEN
          UPDATE public."BOMTemplateSlots"
          SET catalog_item_id = v_comp.component_item_id
          WHERE organization_id = v_org
            AND bom_template_id = v_template.id
            AND item_role = v_role_norm
            AND catalog_item_id IS NULL;
        END IF;
      END IF;
      
      -- Si tiene reglas de qty/corte interesantes (per_width, per_area), preservarlas en BOMComponents
      -- Si es solo fixed=1, no hace falta duplicar
      IF v_comp.qty_type != 'fixed' OR v_comp.qty_value != 1 OR v_comp.cut_axis IS NOT NULL THEN
        -- Mantener el BOMComponent para las reglas
        RAISE NOTICE '    ↳ Preserving qty rule: qty_type=%, qty_value=%', v_comp.qty_type, v_comp.qty_value;
      ELSE
        -- Borrar BOMComponent redundante (ya está en slot)
        -- Comentado por seguridad - puedes habilitarlo si quieres cleanup
        -- UPDATE public."BOMComponents" SET deleted = true WHERE id = v_comp.id;
      END IF;
      
    ELSE
      -- ❌ Es HIJO → Convertir a CatalogItemComponent
      
      -- Buscar el PADRE de este HIJO (el componente anterior en sort_order que sea PADRE)
      DECLARE
        v_parent_comp RECORD;
        v_parent_item_id uuid;
      BEGIN
        -- Buscar PADRE más cercano en el mismo template
        SELECT * INTO v_parent_comp
        FROM public."BOMComponents"
        WHERE organization_id = v_org
          AND bom_template_id = v_template.id
          AND sort_order < v_comp.sort_order
          AND regexp_replace(lower(coalesce(component_role, '')), '[^a-z0-9]+', '_', 'g') = ANY(v_padres_roles)
          AND deleted = false
        ORDER BY sort_order DESC
        LIMIT 1;
        
        IF v_parent_comp.id IS NOT NULL AND v_parent_comp.component_item_id IS NOT NULL THEN
          v_parent_item_id := v_parent_comp.component_item_id;
          
          -- Insertar relación PADRE → HIJO
          IF v_comp.component_item_id IS NOT NULL AND v_role_norm = ANY(v_hijos_roles) THEN
            INSERT INTO public."CatalogItemComponents" (
              organization_id,
              parent_item_id,
              child_item_id,
              child_role,
              qty,
              uom,
              required,
              sort_order,
              notes
            ) VALUES (
              v_org,
              v_parent_item_id,
              v_comp.component_item_id,
              v_role_norm,
              v_comp.qty_value,
              v_comp.uom,
              true,
              v_comp.sort_order,
              CONCAT('Migrated from ', v_template.code, ' template')
            )
            ON CONFLICT (organization_id, parent_item_id, child_item_id) 
            WHERE deleted = false DO NOTHING;
            
            v_migrated_children := v_migrated_children + 1;
            
            RAISE NOTICE '  → Child: % (qty=%) linked to % (%)', 
              v_role_norm,
              v_comp.qty_value,
              v_parent_comp.component_role,
              (SELECT sku FROM public."CatalogItems" WHERE id = v_parent_item_id LIMIT 1);
          END IF;
        ELSE
          RAISE NOTICE '  ⚠ Child % sin PADRE identificado - skipping', v_comp.component_role;
        END IF;
      END;
    END IF;
    
  END LOOP;
  
  RAISE NOTICE '';
  
END LOOP;

RAISE NOTICE '========================================';
RAISE NOTICE 'Migración completada:';
RAISE NOTICE '- Slots creados: %', v_migrated_slots;
RAISE NOTICE '- Children migrados: %', v_migrated_children;
RAISE NOTICE '========================================';
RAISE NOTICE '';
RAISE NOTICE 'Verificar en:';
RAISE NOTICE '1. /catalog/bom → Ver templates con slots';
RAISE NOTICE '2. Click 📦 verde → Ver HIJOS por SKU';

END;
$$;

COMMIT;

-- ============================================================================
-- VERIFICACIÓN: Ver templates con sus slots
-- ============================================================================

SELECT 
  bt.code as template_code,
  bt.name as template_name,
  COUNT(DISTINCT bts.id) as slots_count,
  STRING_AGG(
    DISTINCT CONCAT(
      bts.item_role,
      CASE WHEN bts.catalog_item_id IS NOT NULL 
        THEN ' [' || COALESCE((SELECT sku FROM public."CatalogItems" WHERE id = bts.catalog_item_id LIMIT 1), 'N/A') || ']'
        ELSE ' [user choice]'
      END
    ),
    ', '
    ORDER BY CONCAT(
      bts.item_role,
      CASE WHEN bts.catalog_item_id IS NOT NULL 
        THEN ' [' || COALESCE((SELECT sku FROM public."CatalogItems" WHERE id = bts.catalog_item_id LIMIT 1), 'N/A') || ']'
        ELSE ' [user choice]'
      END
    )
  ) as slots_detail
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
GROUP BY bt.id, bt.code, bt.name
ORDER BY bt.code;

-- ============================================================================
-- VERIFICACIÓN: Ver HIJOS por SKU PADRE
-- ============================================================================

SELECT 
  parent.sku as padre_sku,
  parent.name as padre_name,
  parent.item_role as padre_role,
  COUNT(cic.id) as children_count,
  STRING_AGG(
    CONCAT(cic.child_role, ' (', cic.qty, ' ', cic.uom, ')'),
    ', '
    ORDER BY cic.sort_order
  ) as children_detail
FROM public."CatalogItems" parent
LEFT JOIN public."CatalogItemComponents" cic ON cic.parent_item_id = parent.id AND cic.deleted = false
WHERE parent.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND parent.item_role = ANY(ARRAY['drive', 'motor', 'bracket', 'track'])
  AND parent.is_active = true
GROUP BY parent.id, parent.sku, parent.name, parent.item_role
HAVING COUNT(cic.id) > 0
ORDER BY parent.item_role, parent.sku;
