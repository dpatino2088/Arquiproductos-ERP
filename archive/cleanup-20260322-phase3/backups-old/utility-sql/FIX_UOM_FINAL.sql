-- ============================================================================
-- FIX COMPLETO: generate_bom_from_slots - Corrección de UOM
-- ============================================================================
-- Fecha: 2026-01-20
-- Problema: CatalogItems usa "unit_of_measure" (no "uom")
-- Objetivo: Corregir todas las referencias a ci.uom -> ci.unit_of_measure
-- ============================================================================

-- Reemplazar función generate_bom_from_slots con UOM corregido
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
  v_unit_uom text; -- ✅ FIX: CatalogItems usa "unit_of_measure" (no "uom")
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
-- ✅ CatalogItems usa "unit_of_measure" (no "uom") - CORREGIDO
-- ✅ CatalogItemComponents usa "qty" (no "qty_value") y "uom" (no "child_uom") - CORREGIDO
-- ✅ BOMTemplateSlots NO tiene columna "uom" - CORREGIDO (obtener desde CatalogItem)
-- ✅ Usa unit_cost_exw (no unit_cost) según esquema real
-- ✅ Mantiene organization_id y deleted (se agregaron con migration previa)
