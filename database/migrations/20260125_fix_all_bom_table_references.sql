-- ====================================================
-- MIGRATION: Corregir todas las referencias a tablas BOM old
-- Date: 2026-01-25
-- Description: Corrige todas las funciones SQL que usan BomInstances/BomInstanceLines
--              para usar BOMInstances/BOMInstanceLines (mayúsculas)
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Corregir calculate_configured_product_totals
-- ====================================================
-- (Ya corregida en 20260125_complete_configured_products_quote_lines_flow.sql)
-- Solo verificamos que esté correcta

-- ====================================================
-- 2. Corregir generate_bom_from_slots_for_configured_product
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_cp RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config_snapshot jsonb;
    v_selected_item_id uuid;
    v_selected_sku text;
    v_mounting_clip_qty numeric(12,4);
    v_mounting_clip_rule RECORD;
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id 
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    v_config_snapshot := v_cp.config_snapshot;
    v_template_id := v_cp.bom_template_id;

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'BOMTemplate not set in ConfiguredProduct %', p_configured_product_id;
    END IF;

    -- 2. Soft-delete instancias previas (idempotencia)
    -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND configured_product_id = p_configured_product_id
        AND deleted = false;

    -- 3. Crear nueva instancia
    IF p_configured_product_id IS NULL THEN
        RAISE EXCEPTION 'configured_product_id cannot be NULL for preview BOMInstance';
    END IF;

    BEGIN
        -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
        INSERT INTO public."BOMInstances"(
            organization_id, 
            configured_product_id, 
            bom_template_id,
            quote_line_id  -- NULL para preview
        )
        VALUES (p_org_id, p_configured_product_id, v_template_id, NULL)
        RETURNING id INTO v_instance_id;

        IF v_instance_id IS NULL THEN
            RAISE EXCEPTION 'Failed to create BOMInstance: RETURNING id returned NULL. ConfiguredProduct: %, Template: %', p_configured_product_id, v_template_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Failed to create BOMInstance for ConfiguredProduct %: %. Check XOR constraint and schema.', p_configured_product_id, SQLERRM;
    END;

    v_width_mm := COALESCE(v_cp.width_mm, 0);
    v_height_mm := COALESCE(v_cp.height_mm, 0);

    -- 4. Iterar BOMTemplateSlots (PADRES)
    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        -- PASO 1: Resolver SKU PADRE desde config_snapshot
        v_selected_item_id := NULL;
        v_selected_sku := NULL;
        
        CASE v_slot.item_role
            WHEN 'bottom_bar' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_bar_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_bar_sku';
            WHEN 'headbox' THEN
                v_selected_item_id := (v_config_snapshot->>'headbox_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'headbox_sku';
            WHEN 'side_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'side_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'side_channel_sku';
            WHEN 'bottom_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_channel_sku';
            WHEN 'motor' THEN
                v_selected_item_id := (v_config_snapshot->>'motor_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'motor_sku';
            WHEN 'drive' THEN
                v_selected_item_id := (v_config_snapshot->>'drive_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'drive_sku';
            WHEN 'tube' THEN
                v_selected_item_id := (v_config_snapshot->>'tube_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'tube_sku';
            ELSE
                v_selected_item_id := (v_config_snapshot->>(v_slot.item_role || '_item_id'))::uuid;
                v_selected_sku := v_config_snapshot->>(v_slot.item_role || '_sku');
        END CASE;

        -- Resolver item
        IF v_selected_sku IS NOT NULL AND v_slot.catalog_item_id IS NOT NULL THEN
            SELECT ci.sku INTO v_resolved_item
            FROM public."CatalogItems" ci
            WHERE ci.id = v_slot.catalog_item_id
                AND TRIM(ci.sku) = TRIM(v_selected_sku);
                
            IF v_resolved_item IS NOT NULL THEN
                v_resolved_item := v_slot.catalog_item_id;
            END IF;
        ELSIF v_selected_item_id IS NOT NULL THEN
            v_resolved_item := v_selected_item_id;
        ELSE
            v_resolved_item := v_slot.catalog_item_id;
        END IF;

        -- PASO 2: Obtener reglas de qty/corte desde BOMComponents
        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        -- PASO 3: Calcular cantidad
        IF v_has_component_rules THEN
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

            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        -- PASO 4: Obtener costo y UOM
        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        -- PASO 5: Insertar línea del BOM (PADRE)
        -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas)
        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
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
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        ELSIF v_resolved_item IS NULL AND v_qty > 0 THEN
            RAISE WARNING 'Skipping BOM line insertion for role %: qty=% but resolved_part_id is NULL', v_slot.item_role, v_qty;
        END IF;

        -- PASO 6: Si hay SKU resuelto, agregar HIJOS desde CatalogItemComponents
        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                SELECT 
                    cic.child_item_id,
                    cic.child_role,
                    cic.qty,
                    cic.uom,
                    COALESCE(ci.cost_exw, 0) AS child_cost
                FROM public."CatalogItemComponents" cic
                JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                WHERE cic.organization_id = p_org_id
                    AND cic.parent_item_id = v_resolved_item
                    AND cic.deleted = false
                ORDER BY cic.sort_order ASC
            LOOP
                -- REGLA ESPECIAL: mounting_clip con qty_type=per_width
                IF v_child.child_role = 'mounting_clip' THEN
                    SELECT * INTO v_mounting_clip_rule
                    FROM public."BOMComponents"
                    WHERE organization_id = p_org_id
                        AND bom_template_id = v_template_id
                        AND component_role = 'mounting_clip'
                        AND depends_on_role = v_slot.item_role
                        AND qty_type = 'per_width'
                        AND deleted = false
                    LIMIT 1;

                    IF v_mounting_clip_rule.id IS NOT NULL THEN
                        v_mounting_clip_qty := CEIL((v_width_mm / 1000.0) * v_mounting_clip_rule.qty_value);
                        IF v_mounting_clip_qty < 2 THEN
                            v_mounting_clip_qty := 2;
                        END IF;
                        v_child.qty := v_mounting_clip_qty * v_qty;
                        v_child.uom := 'ea';
                    END IF;
                END IF;

                -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas)
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
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;

COMMENT ON FUNCTION "public"."generate_bom_from_slots_for_configured_product" IS 
'Genera BOMInstance y BOMInstanceLines para un ConfiguredProduct.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).';

-- ====================================================
-- 3. Corregir generate_bom_instance_for_quote_line
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_config jsonb;
  v_template_id uuid;
  v_instance_id uuid;
  v_ql public."QuoteLines";
  v_comp public."BOMComponents";
  v_override_item uuid;
  v_item_id uuid;
  v_qty numeric(12,4);
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_unit_cost numeric(12,4);
BEGIN
  SELECT * INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id
    AND organization_id = p_org_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
  v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

  -- idempotency: soft-delete previous active instance
  -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
  UPDATE public."BOMInstances"
    SET deleted = true
  WHERE organization_id = p_org_id
    AND quote_line_id = p_quote_line_id
    AND deleted = false;

  -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
  INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id)
  VALUES (p_org_id, p_quote_line_id, v_template_id)
  RETURNING id INTO v_instance_id;

  v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
  v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

  FOR v_comp IN
    SELECT *
    FROM public."BOMComponents"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
      AND deleted = false
      AND archived = false
    ORDER BY (depends_on_role IS NOT NULL)::int, sort_order ASC
  LOOP
    -- override?
    SELECT qlc.catalog_item_id INTO v_override_item
    FROM public."QuoteLineComponents" qlc
    WHERE qlc.organization_id = p_org_id
      AND qlc.quote_line_id = p_quote_line_id
      AND qlc.component_role = v_comp.component_role
      AND qlc.kind = 'override'
      AND qlc.deleted = false
    LIMIT 1;

    -- qty calc
    IF v_comp.qty_type = 'fixed' THEN
      v_qty := v_comp.qty_value;
    ELSIF v_comp.qty_type = 'per_width' THEN
      v_qty := ((v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0) * v_comp.qty_value;
    ELSIF v_comp.qty_type = 'per_height' THEN
      v_qty := ((v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0) * v_comp.qty_value;
    ELSIF v_comp.qty_type = 'per_area' THEN
      v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_comp.qty_value;
    ELSE
      v_qty := v_comp.qty_value;
    END IF;

    IF v_comp.waste_pct IS NOT NULL AND v_comp.waste_pct > 0 THEN
      v_qty := v_qty * (1 + v_comp.waste_pct);
    END IF;

    -- resolve item
    v_item_id := COALESCE(v_override_item, v_comp.component_item_id);

    IF v_item_id IS NOT NULL AND v_qty > 0 THEN
      SELECT ci.cost_exw INTO v_unit_cost
      FROM public."CatalogItems" ci
      WHERE ci.id = v_item_id;
      
      v_unit_cost := COALESCE(v_unit_cost, 0);

      -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas)
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
        v_item_id,
        v_comp.component_role,
        v_qty,
        v_comp.uom,
        v_unit_cost,
        false
      );
    END IF;
  END LOOP;

  RETURN v_instance_id;
END;
$$;

COMMENT ON FUNCTION "public"."generate_bom_instance_for_quote_line" IS 
'Genera BOMInstance y BOMInstanceLines para un QuoteLine.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).';

-- ====================================================
-- 4. Corregir generate_bom_from_slots (para QuoteLines)
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_ql RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config jsonb;
BEGIN
    -- 1. Obtener QuoteLine
    SELECT * INTO v_ql
    FROM public."QuoteLines"
    WHERE id = p_quote_line_id
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_ql.id IS NULL THEN
        RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
    END IF;

    -- 2. Resolver BOM template
    v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
    v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', 
            p_org_id, p_product_type_id;
    END IF;

    -- 3. Soft-delete instancias previas (idempotencia)
    -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND quote_line_id = p_quote_line_id
        AND deleted = false;

    -- 4. Crear nueva instancia
    -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
    INSERT INTO public."BOMInstances"(
        organization_id, 
        quote_line_id, 
        bom_template_id,
        configured_product_id  -- NULL para QuoteLine
    )
    VALUES (p_org_id, p_quote_line_id, v_template_id, NULL)
    RETURNING id INTO v_instance_id;

    v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
    v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

    -- 5. Iterar BOMTemplateSlots
    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        -- Resolver item (usar catalog_item_id del slot o override)
        v_resolved_item := v_slot.catalog_item_id;

        -- Obtener reglas de qty/corte desde BOMComponents
        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        -- Calcular cantidad
        IF v_has_component_rules THEN
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

            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        -- Obtener costo y UOM
        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        -- Insertar línea del BOM (PADRE)
        -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas)
        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
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
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        END IF;

        -- Agregar HIJOS desde CatalogItemComponents
        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                SELECT 
                    cic.child_item_id,
                    cic.child_role,
                    cic.qty,
                    cic.uom,
                    COALESCE(ci.cost_exw, 0) AS child_cost
                FROM public."CatalogItemComponents" cic
                JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                WHERE cic.organization_id = p_org_id
                    AND cic.parent_item_id = v_resolved_item
                    AND cic.deleted = false
                ORDER BY cic.sort_order ASC
            LOOP
                -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas)
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
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;

COMMENT ON FUNCTION "public"."generate_bom_from_slots" IS 
'Genera BOMInstance desde BOMTemplateSlots para QuoteLine.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).';

COMMIT;
