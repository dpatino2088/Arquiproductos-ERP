-- ============================================================================
-- FIX: BOM Template Matching según filtros correctos
-- ============================================================================
-- El matching debe ser:
-- 1. ProductType (primer filtro) - product_type_id
-- 2. Color (segundo filtro) - color (hardware_color)
-- 3. Comparar selecciones SKU del usuario (QuoteLineComponents kind='selection')
--    con slots del BOMTemplate (BOMTemplateSlots)
-- 4. El que más coincidencias tenga, gana
-- ============================================================================

CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_quote_line"(
  "p_org_id" uuid,
  "p_product_type_id" uuid,
  "p_quote_line_id" uuid
) RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_color text;
  v_selected_roles text[];
  v_best_template_id uuid;
  v_best_score int := -1;
  v_candidate RECORD;
  v_match_score int;
  v_user_roles text[];
BEGIN
  -- 1. Obtener hardware_color (segundo filtro)
  SELECT qlc.payload->>'hardware_color' INTO v_color
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.component_role = 'hardware_color'
    AND qlc.kind = 'option'
    AND qlc.deleted = false
  LIMIT 1;

  -- 2. Obtener roles seleccionados por el usuario (kind='selection')
  SELECT ARRAY_AGG(DISTINCT qlc.component_role) INTO v_user_roles
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection' -- Solo selecciones SKU directas
    AND qlc.deleted = false;

  -- Si no hay roles seleccionados, usar array vacío
  v_user_roles := COALESCE(v_user_roles, ARRAY[]::text[]);

  -- 3. Buscar templates que coincidan con product_type_id y color
  FOR v_candidate IN
    SELECT 
      bt.id,
      bt.color,
      bt.updated_at,
      COALESCE((bt.metadata->>'priority')::int, 0) AS priority
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id -- ✅ PRIMER FILTRO: ProductType
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
      -- ✅ SEGUNDO FILTRO: Color (si se especificó)
      AND (
        v_color IS NULL 
        OR bt.color IS NULL 
        OR LOWER(TRIM(bt.color)) = LOWER(TRIM(v_color))
      )
    ORDER BY 
      -- Priorizar templates con color exacto (si se especificó color)
      CASE WHEN v_color IS NOT NULL AND LOWER(TRIM(bt.color)) = LOWER(TRIM(v_color)) THEN 0 ELSE 1 END,
      priority DESC,
      bt.updated_at DESC
  LOOP
    -- 4. Calcular score: contar cuántos slots del template coinciden con selecciones del usuario
    -- ✅ FIX: BOMTemplateSlots NO tiene columna "deleted"
    SELECT COUNT(*) INTO v_match_score
    FROM public."BOMTemplateSlots" slots
    WHERE slots.organization_id = p_org_id
      AND slots.bom_template_id = v_candidate.id
      AND slots.item_role = ANY(v_user_roles);

    -- 5. Si este template tiene mejor score que el anterior, actualizar
    IF v_match_score > v_best_score THEN
      v_best_score := v_match_score;
      v_best_template_id := v_candidate.id;
    END IF;
  END LOOP;

  -- 6. Si no encontramos ninguno con matches, usar el primero que coincida con product_type + color
  IF v_best_template_id IS NULL THEN
    SELECT bt.id INTO v_best_template_id
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
      AND (
        v_color IS NULL 
        OR bt.color IS NULL 
        OR LOWER(TRIM(bt.color)) = LOWER(TRIM(v_color))
      )
    ORDER BY 
      CASE WHEN v_color IS NOT NULL AND LOWER(TRIM(bt.color)) = LOWER(TRIM(v_color)) THEN 0 ELSE 1 END,
      COALESCE((bt.metadata->>'priority')::int, 0) DESC,
      bt.updated_at DESC
    LIMIT 1;
  END IF;

  RETURN v_best_template_id;
END;
$$;

-- ============================================================================
-- ACTUALIZAR generate_bom_from_slots para usar la nueva función de matching
-- ============================================================================

CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots"(
  "p_org_id" uuid,
  "p_quote_line_id" uuid,
  "p_product_type_id" uuid
) RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_template_id uuid;
  v_instance_id uuid;
  v_ql public."QuoteLines";
  v_slot RECORD;
  v_component RECORD;
  v_resolved_item uuid;
  v_qty numeric(12,4);
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_unit_cost numeric(12,4);
  v_unit_uom text; -- ✅ FIX: BOMTemplateSlots NO tiene columna "uom"
  v_child RECORD;
  v_has_component_rules boolean;
BEGIN
  -- 1. Obtener QuoteLine
  SELECT * INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id AND organization_id = p_org_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  -- 2. ✅ NUEVO: Seleccionar mejor template usando la función correcta
  --    Filtra por product_type_id, color, y compara selecciones SKU
  v_template_id := public.select_best_bom_template_for_quote_line(
    p_org_id, 
    p_product_type_id, 
    p_quote_line_id
  );

  IF v_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %, quote_line %', 
      p_org_id, p_product_type_id, p_quote_line_id;
  END IF;

  -- 3. Soft-delete instancias previas (idempotencia)
  UPDATE public."BOMInstances"
    SET deleted = true
  WHERE organization_id = p_org_id
    AND quote_line_id = p_quote_line_id
    AND deleted = false;

  -- 4. Crear nueva instancia
  INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id)
  VALUES (p_org_id, p_quote_line_id, v_template_id)
  RETURNING id INTO v_instance_id;

  v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
  v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

  -- ✅ NUEVO: Iterar BOMTemplateSlots (PADRES), no BOMComponents
  -- ✅ FIX: BOMTemplateSlots NO tiene columna "deleted"
  FOR v_slot IN
    SELECT *
    FROM public."BOMTemplateSlots"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
    ORDER BY item_role ASC
  LOOP
    -- ✅ PASO 1: Resolver SKU PADRE desde QuoteLineComponents (elección del usuario)
    -- Buscar si el usuario eligió un SKU para este role
    SELECT qlc.catalog_item_id INTO v_resolved_item
    FROM public."QuoteLineComponents" qlc
    WHERE qlc.organization_id = p_org_id
      AND qlc.quote_line_id = p_quote_line_id
      AND qlc.component_role = v_slot.item_role
      AND qlc.kind = 'selection' -- ✅ SKUs elegidos por el usuario
      AND qlc.deleted = false
    LIMIT 1;

    -- Si no eligió, usar catalog_item_id fijo del slot (si existe)
    IF v_resolved_item IS NULL THEN
      v_resolved_item := v_slot.catalog_item_id;
    END IF;

    -- ✅ PASO 2: Obtener reglas de qty/corte desde BOMComponents (si existen)
    -- BOMComponents ahora solo sirve para definir reglas de cálculo, NO para resolución de SKU
    SELECT * INTO v_component
    FROM public."BOMComponents"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
      AND component_role = v_slot.item_role
      AND deleted = false
    LIMIT 1;

    v_has_component_rules := (v_component.id IS NOT NULL);

    -- ✅ PASO 3: Calcular cantidad
    IF v_has_component_rules THEN
      -- Usar lógica de qty_type del componente
      IF v_component.qty_type = 'fixed' THEN
        v_qty := v_component.qty_value;
      ELSIF v_component.qty_type = 'per_width' THEN
        v_qty := ((v_width_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
      ELSIF v_component.qty_type = 'per_height' THEN
        v_qty := ((v_height_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
      ELSIF v_component.qty_type = 'per_area' THEN
        v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_component.qty_value;
      ELSE
        v_qty := v_component.qty_value;
      END IF;

      -- Aplicar waste_pct
      IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
        v_qty := v_qty * (1 + v_component.waste_pct);
      END IF;
    ELSE
      -- Fallback: cantidad del slot
      v_qty := v_slot.qty;
    END IF;

    -- ✅ PASO 4: Obtener costo y UOM (solo si hay SKU resuelto)
    -- ✅ FIX: CatalogItems usa "unit_of_measure" (no "uom")
    IF v_resolved_item IS NOT NULL THEN
      SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
      FROM public."CatalogItems" ci
      WHERE ci.id = v_resolved_item;
      
      v_unit_cost := COALESCE(v_unit_cost, 0);
      v_unit_uom := COALESCE(v_unit_uom, 'ea'); -- Fallback a 'ea' si no tiene UOM
    ELSE
      v_unit_cost := 0;
      v_unit_uom := 'ea'; -- Default UOM para líneas sin SKU
    END IF;

    -- ✅ PASO 5: Insertar línea del BOM (PADRE)
    -- ✅ FIX: La columna de costo es unit_cost_exw (no unit_cost)
    -- ✅ Mantener organization_id y deleted (se agregarán con migration)
    IF v_resolved_item IS NOT NULL OR v_qty > 0 THEN
      INSERT INTO public."BOMInstanceLines"(
        organization_id,
        bom_instance_id,
        resolved_part_id,
        part_role,
        qty,
        uom,
        unit_cost_exw,
        deleted
      ) VALUES (
        p_org_id,
        v_instance_id,
        v_resolved_item, -- Puede ser NULL si no hay SKU
        v_slot.item_role,
        v_qty,
        v_unit_uom, -- ✅ FIX: Usar UOM del CatalogItem (no v_slot.uom)
        v_unit_cost,
        false
      );
    END IF;

    -- ✅ PASO 6: Si hay SKU resuelto, agregar HIJOS desde CatalogItemComponents
    IF v_resolved_item IS NOT NULL THEN
      FOR v_child IN
        SELECT 
          cic.child_item_id,
          cic.child_role,
          cic.qty, -- ✅ FIX: CatalogItemComponents usa "qty" (no "qty_value")
          cic.uom, -- ✅ FIX: CatalogItemComponents usa "uom" (no "child_uom")
          COALESCE(ci.cost_exw, 0) AS child_cost
        FROM public."CatalogItemComponents" cic
        JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
        WHERE cic.organization_id = p_org_id
          AND cic.parent_item_id = v_resolved_item
          AND cic.deleted = false
        ORDER BY cic.sort_order ASC
      LOOP
        -- ✅ FIX: La columna de costo es unit_cost_exw (no unit_cost)
        INSERT INTO public."BOMInstanceLines"(
          organization_id,
          bom_instance_id,
          resolved_part_id,
          part_role,
          qty,
          uom,
          unit_cost_exw,
          deleted
        ) VALUES (
          p_org_id,
          v_instance_id,
          v_child.child_item_id,
          v_child.child_role,
          v_qty * v_child.qty, -- ✅ Cantidad del padre × cantidad del hijo (cic.qty)
          v_child.uom, -- ✅ UOM del hijo (cic.uom)
          v_child.child_cost,
          false
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN v_instance_id;
END;
$$;

-- ============================================================================
-- COMENTARIOS
-- ============================================================================
COMMENT ON FUNCTION "public"."select_best_bom_template_for_quote_line" IS 
'Selecciona el mejor BOMTemplate basado en:
1. ProductType (primer filtro)
2. Color (hardware_color, segundo filtro)
3. Comparación de selecciones SKU del usuario con slots del template (más coincidencias = mejor)';

COMMENT ON FUNCTION "public"."generate_bom_from_slots" IS 
'Genera BOMInstance desde BOMTemplateSlots y selecciones SKU del usuario.
Usa select_best_bom_template_for_quote_line para encontrar el template correcto.';
