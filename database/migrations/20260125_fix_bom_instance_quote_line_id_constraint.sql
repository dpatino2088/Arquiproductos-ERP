-- ====================================================
-- MIGRATION: Fix BOMInstance creation - NO crear sin quote_line_id
-- Date: 2026-01-25
-- Description: 
--  Modifica create_configured_product_and_bom_preview para NO crear BOMInstance
--  sin quote_line_id. El BOMInstance se creará después cuando se tenga quote_line_id.
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Eliminar versiones anteriores de create_configured_product_and_bom_preview
-- ====================================================
-- ✅ Necesario para evitar error "function name is not unique"
DROP FUNCTION IF EXISTS "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid");
DROP FUNCTION IF EXISTS "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid");

-- ====================================================
-- 2. Crear create_configured_product_and_bom_preview (nueva versión)
-- ====================================================
-- ✅ CAMBIO: NO crear BOMInstance en el preview
-- El BOMInstance se creará después cuando se tenga quote_line_id
CREATE FUNCTION "public"."create_configured_product_and_bom_preview"(
    "p_org_id" "uuid", 
    "p_product_type_id" "uuid", 
    "p_config_snapshot" "jsonb", 
    "p_quote_id" "uuid" DEFAULT NULL::"uuid",
    "p_quote_line_id" "uuid" DEFAULT NULL::"uuid"  -- ✅ NUEVO: quote_line_id opcional
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_configured_product_id uuid;
    v_bom_template_id uuid;
    v_bom_instance_id uuid;
    v_totals jsonb;
    v_hardware_color text;
    v_fabric_item_id uuid;
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_quantity numeric(12,4);
    v_roll_sku text;
    v_roll_collection_name text;
    v_roll_variant_name text;
    v_roll_width numeric(12,4);
BEGIN
    -- 1. Resolver BOM template usando config_snapshot
    v_bom_template_id := public.select_best_bom_template_for_configured_product(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
    );

    IF v_bom_template_id IS NULL THEN
        RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', 
            p_org_id, p_product_type_id;
    END IF;

    -- 2. Extraer datos principales del config_snapshot
    v_hardware_color := COALESCE(
        p_config_snapshot->>'hardware_color',
        p_config_snapshot->>'hardwareColor',
        p_config_snapshot->>'operatingSystemColor'
    );
    
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
    IF v_fabric_item_id IS NULL THEN
        v_fabric_item_id := (p_config_snapshot->>'fabric_catalog_item_id')::uuid; -- Legacy compatibility
    END IF;
    IF v_fabric_item_id IS NULL THEN
        v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
    END IF;
    
    v_width_mm := (p_config_snapshot->>'width_mm')::numeric;
    IF v_width_mm IS NULL THEN
        v_width_mm := COALESCE((p_config_snapshot->>'width_m')::numeric, 0) * 1000;
    END IF;
    
    v_height_mm := (p_config_snapshot->>'height_mm')::numeric;
    IF v_height_mm IS NULL THEN
        v_height_mm := COALESCE((p_config_snapshot->>'height_m')::numeric, 0) * 1000;
    END IF;
    
    v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric, 1);

    -- 3. Obtener info del roll si existe
    IF v_fabric_item_id IS NOT NULL THEN
        SELECT 
            ci.sku, 
            ci.collection_name, 
            ci.variant_name,
            ci.roll_width
        INTO 
            v_roll_sku, 
            v_roll_collection_name, 
            v_roll_variant_name,
            v_roll_width
        FROM public."CatalogItems" ci
        WHERE ci.id = v_fabric_item_id
            AND ci.is_fabric = true
            AND ci.is_active = true
            AND (ci.organization_id = p_org_id OR ci.organization_id IS NULL)
        LIMIT 1;
    END IF;

    -- 4. Crear ConfiguredProduct
    INSERT INTO public."ConfiguredProducts"(
        organization_id,
        quote_id,
        bom_template_id,
        product_type_id,
        roll_catalog_item_id,
        roll_sku,
        roll_collection_name,
        roll_variant_name,
        roll_width,
        width_mm,
        height_mm,
        quantity,
        hardware_color,
        bottom_bar_item_id,
        bottom_bar_sku,
        headbox_item_id,
        headbox_sku,
        side_channel_item_id,
        side_channel_sku,
        bottom_channel_item_id,
        bottom_channel_sku,
        motor_item_id,
        motor_sku,
        drive_item_id,
        drive_sku,
        tube_item_id,
        tube_sku,
        operating_type,
        config_snapshot
    ) VALUES (
        p_org_id,
        p_quote_id,
        v_bom_template_id,
        p_product_type_id,
        v_fabric_item_id,
        v_roll_sku,
        v_roll_collection_name,
        v_roll_variant_name,
        v_roll_width,
        v_width_mm,
        v_height_mm,
        v_quantity,
        v_hardware_color,
        (p_config_snapshot->>'bottom_bar_item_id')::uuid,
        p_config_snapshot->>'bottom_bar_sku',
        (p_config_snapshot->>'headbox_item_id')::uuid,
        p_config_snapshot->>'headbox_sku',
        (p_config_snapshot->>'side_channel_item_id')::uuid,
        p_config_snapshot->>'side_channel_sku',
        (p_config_snapshot->>'bottom_channel_item_id')::uuid,
        p_config_snapshot->>'bottom_channel_sku',
        (p_config_snapshot->>'motor_item_id')::uuid,
        p_config_snapshot->>'motor_sku',
        (p_config_snapshot->>'drive_item_id')::uuid,
        p_config_snapshot->>'drive_sku',
        (p_config_snapshot->>'tube_item_id')::uuid,
        p_config_snapshot->>'tube_sku',
        COALESCE(
            p_config_snapshot->>'operating_type',
            p_config_snapshot->>'operation_type',
            p_config_snapshot->>'drive_type'
        ),
        p_config_snapshot
    )
    RETURNING id INTO v_configured_product_id;

    -- 5. ✅ CAMBIO CRÍTICO: NO crear BOMInstance en el preview
    -- El BOMInstance se creará después cuando se tenga quote_line_id
    -- Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id
    v_bom_instance_id := NULL;
    
    IF p_quote_line_id IS NULL THEN
        -- Registrar info para debugging
        RAISE NOTICE 'BOMInstance NO creado en preview: quote_line_id es NULL. Se creará después cuando se tenga QuoteLine.';
    END IF;

    -- 6. Calcular totals (aunque no haya BOMInstance aún, se puede calcular desde ConfiguredProduct)
    v_totals := public.calculate_configured_product_totals(v_configured_product_id);

    -- 7. Retornar resultado
    RETURN jsonb_build_object(
        'configured_product_id', v_configured_product_id,
        'bom_instance_id', v_bom_instance_id,  -- NULL si no se creó
        'bom_template_id', v_bom_template_id,
        'totals', v_totals
    );
END;
$$;

COMMENT ON FUNCTION "public"."create_configured_product_and_bom_preview" IS 
'Crea ConfiguredProduct y opcionalmente BOMInstance.
✅ CAMBIO: Solo crea BOMInstance si se proporciona quote_line_id.
Si quote_line_id es NULL, NO crea BOMInstance (se creará después cuando se tenga QuoteLine).
Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id.';

-- ====================================================
-- 3. Eliminar versiones anteriores de generate_bom_from_slots_for_configured_product
-- ====================================================
DROP FUNCTION IF EXISTS "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid");
DROP FUNCTION IF EXISTS "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid");

-- ====================================================
-- 4. Crear generate_bom_from_slots_for_configured_product (nueva versión)
-- ====================================================
-- ✅ CAMBIO: Agregar parámetro opcional quote_line_id
-- Si viene quote_line_id, crear BOMInstance con él (NO NULL)
-- Si NO viene, NO crear BOMInstance (retornar NULL)
CREATE FUNCTION "public"."generate_bom_from_slots_for_configured_product"(
    "p_org_id" "uuid", 
    "p_configured_product_id" "uuid", 
    "p_product_type_id" "uuid",
    "p_quote_line_id" "uuid" DEFAULT NULL::"uuid"  -- ✅ NUEVO: opcional
) RETURNS "uuid"
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

    -- ✅ CAMBIO CRÍTICO: Solo crear BOMInstance si se proporciona quote_line_id
    IF p_quote_line_id IS NULL THEN
        -- NO crear BOMInstance sin quote_line_id
        RAISE NOTICE 'BOMInstance NO creado: quote_line_id es NULL. Retornando NULL.';
        RETURN NULL;
    END IF;

    -- 2. Soft-delete instancias previas (idempotencia)
    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND (
            (configured_product_id = p_configured_product_id AND configured_product_id IS NOT NULL)
            OR (quote_line_id = p_quote_line_id AND quote_line_id IS NOT NULL)
        )
        AND deleted = false;

    -- 3. Crear nueva instancia con quote_line_id
    BEGIN
        INSERT INTO public."BOMInstances"(
            organization_id, 
            quote_line_id,  -- ✅ REQUERIDO
            configured_product_id, 
            bom_template_id
        )
        VALUES (p_org_id, p_quote_line_id, p_configured_product_id, v_template_id)
        RETURNING id INTO v_instance_id;

        IF v_instance_id IS NULL THEN
            RAISE EXCEPTION 'Failed to create BOMInstance: RETURNING id returned NULL. QuoteLine: %, ConfiguredProduct: %, Template: %', 
                p_quote_line_id, p_configured_product_id, v_template_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Failed to create BOMInstance for QuoteLine % and ConfiguredProduct %: %. Check constraints and schema.', 
                p_quote_line_id, p_configured_product_id, SQLERRM;
    END;

    v_width_mm := COALESCE(v_cp.width_mm, 0);
    v_height_mm := COALESCE(v_cp.height_mm, 0);

    -- 4. Iterar BOMTemplateSlots (PADRES) - misma lógica que antes
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
✅ CAMBIO: Ahora acepta quote_line_id opcional.
- Si quote_line_id viene: crea BOMInstance con quote_line_id (requerido por constraint)
- Si quote_line_id es NULL: NO crea BOMInstance (retorna NULL)
Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id.';

-- ====================================================
-- 5. Eliminar versión anterior de create_bom_instance_for_configured_product (si existe)
-- ====================================================
DROP FUNCTION IF EXISTS "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid");

-- ====================================================
-- 6. Crear función helper para crear BOMInstance después de tener quote_line_id
-- ====================================================
CREATE FUNCTION "public"."create_bom_instance_for_configured_product"(
    "p_org_id" "uuid",
    "p_quote_line_id" "uuid",
    "p_configured_product_id" "uuid",
    "p_product_type_id" "uuid"
) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_bom_instance_id uuid;
    v_configured_product RECORD;
BEGIN
    -- ✅ VALIDACIÓN: quote_line_id es REQUERIDO
    IF p_quote_line_id IS NULL THEN
        RAISE EXCEPTION 'quote_line_id is required to create BOMInstance';
    END IF;

    -- Validar que ConfiguredProduct existe
    SELECT * INTO v_configured_product
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_configured_product.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct % not found or is deleted', p_configured_product_id;
    END IF;

    -- Verificar si ya existe BOMInstance para este quote_line_id
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE organization_id = p_org_id
        AND quote_line_id = p_quote_line_id
        AND deleted = false
    LIMIT 1;

    IF v_bom_instance_id IS NOT NULL THEN
        -- Ya existe, retornar
        RETURN v_bom_instance_id;
    END IF;

    -- Crear BOMInstance usando generate_bom_from_slots_for_configured_product
    -- ahora con quote_line_id
    v_bom_instance_id := public.generate_bom_from_slots_for_configured_product(
        p_org_id,
        p_configured_product_id,
        p_product_type_id,
        p_quote_line_id  -- ✅ Pasar quote_line_id
    );
    
    RETURN v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION "public"."create_bom_instance_for_configured_product" IS 
'Crea BOMInstance para un ConfiguredProduct existente cuando ya se tiene quote_line_id.
✅ REQUIERE: quote_line_id NO NULL (valida constraint).
Se usa después de crear QuoteLine para crear el BOMInstance asociado.';

COMMIT;
