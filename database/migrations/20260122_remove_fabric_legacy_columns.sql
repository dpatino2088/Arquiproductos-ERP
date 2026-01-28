-- ====================================================
-- Migration: Remove legacy fabric_* columns from ConfiguredProducts
-- Date: 2026-01-22
-- Description: 
--   1. Elimina columnas legacy fabric_* de ConfiguredProducts (ya migradas a roll_*)
--   2. Actualiza funciones SQL para remover referencias a fabric_*
--   3. Limpia código legacy innecesario
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Eliminar columnas legacy fabric_* de ConfiguredProducts
-- ====================================================

DO $$
BEGIN
    -- Eliminar columnas legacy solo si existen (para evitar errores si ya fueron eliminadas)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ConfiguredProducts' 
        AND column_name = 'fabric_catalog_item_id'
    ) THEN
        ALTER TABLE "public"."ConfiguredProducts"
            DROP COLUMN IF EXISTS "fabric_catalog_item_id",
            DROP COLUMN IF EXISTS "fabric_sku",
            DROP COLUMN IF EXISTS "fabric_collection_name",
            DROP COLUMN IF EXISTS "fabric_variant_name",
            DROP COLUMN IF EXISTS "fabric_msrp_total",
            DROP COLUMN IF EXISTS "fabric_plus_bom_total";
        
        RAISE NOTICE 'Columnas legacy fabric_* eliminadas de ConfiguredProducts';
    ELSE
        RAISE NOTICE 'Columnas legacy fabric_* ya no existen en ConfiguredProducts';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error al eliminar columnas legacy: %. Continuando...', SQLERRM;
END $$;

-- ====================================================
-- STEP 2: Actualizar función create_configured_product_and_bom_preview
--         para remover referencias a fabric_catalog_item_id
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."create_configured_product_and_bom_preview"(
    p_org_id uuid,
    p_product_type_id uuid,
    p_config_snapshot jsonb,
    p_quote_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cp_id uuid;
    v_instance_id uuid;
    v_template_id uuid;
    v_roll_item_id uuid;
    v_result jsonb;
BEGIN
    -- 1. Resolver roll_catalog_item_id desde config_snapshot
    -- ✅ Solo usar roll_catalog_item_id (sin fallback a fabric_catalog_item_id)
    v_roll_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
    
    -- Si no está en roll_catalog_item_id, intentar variantId o catalogItemId (campos del configurator)
    IF v_roll_item_id IS NULL THEN
        v_roll_item_id := (p_config_snapshot->>'variantId')::uuid;
    END IF;
    
    IF v_roll_item_id IS NULL THEN
        v_roll_item_id := (p_config_snapshot->>'catalogItemId')::uuid;
    END IF;

    -- 2. Resolver BOM Template
    v_template_id := "public"."select_best_bom_template_for_configured_product"(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
    );

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'No BOM template found for product type % and configuration', p_product_type_id;
    END IF;

    -- 3. Obtener roll_width desde CatalogItems si existe roll_catalog_item_id
    DECLARE
        v_roll_width numeric(12,4);
    BEGIN
        IF v_roll_item_id IS NOT NULL THEN
            SELECT COALESCE(roll_width, 0)
            INTO v_roll_width
            FROM "public"."CatalogItems"
            WHERE id = v_roll_item_id
            AND is_roll = true
            AND is_active = true;
        ELSE
            v_roll_width := 0;
        END IF;

        -- 4. Crear ConfiguredProduct
        INSERT INTO "public"."ConfiguredProducts"(
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
        )
        VALUES (
            p_org_id,
            p_quote_id,
            v_template_id,
            p_product_type_id,
            v_roll_item_id,
            p_config_snapshot->>'roll_sku',
            p_config_snapshot->>'roll_collection_name',
            p_config_snapshot->>'roll_variant_name',
            v_roll_width,
            (p_config_snapshot->>'width_mm')::numeric,
            (p_config_snapshot->>'height_mm')::numeric,
            COALESCE((p_config_snapshot->>'quantity')::numeric, 1),
            p_config_snapshot->>'hardware_color',
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
            p_config_snapshot->>'operating_type',
            p_config_snapshot
        )
        RETURNING id INTO v_cp_id;

        -- 5. Generar BOM Instance
        v_instance_id := "public"."generate_bom_from_slots_for_configured_product"(
            p_org_id,
            v_cp_id,
            p_product_type_id
        );

        -- 6. Calcular totals
        PERFORM "public"."calculate_configured_product_totals"(v_cp_id);

        -- 7. Obtener resultado
        SELECT jsonb_build_object(
            'configured_product_id', v_cp_id,
            'bom_instance_id', v_instance_id,
            'bom_template_id', v_template_id,
            'totals', jsonb_build_object(
                'roll_msrp_total', cp.roll_msrp_total,
                'bom_total', cp.bom_total,
                'roll_plus_bom_total', cp.roll_plus_bom_total,
                'labor_pct', cp.labor_pct,
                'accessories_total', cp.accessories_total,
                'total_msrp', cp.total_msrp
            )
        )
        INTO v_result
        FROM "public"."ConfiguredProducts" cp
        WHERE cp.id = v_cp_id;

        RETURN v_result;
    END;
END;
$$;

-- ====================================================
-- STEP 3: Actualizar función select_best_bom_template_for_configured_product
--         para remover referencias a fabric_catalog_item_id
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_configured_product"(
    p_org_id uuid,
    p_product_type_id uuid,
    p_config_snapshot jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_template_id uuid;
    v_hardware_color text;
    v_roll_item_id uuid;
    v_selected_bottom_bar_sku text;
    v_selected_headbox_sku text;
    v_selected_side_channel_sku text;
    v_selected_bottom_channel_sku text;
    v_selected_motor_sku text;
    v_selected_drive_sku text;
    v_selected_tube_sku text;
    v_matching_count integer;
BEGIN
    -- Extraer valores del config_snapshot
    v_hardware_color := p_config_snapshot->>'hardware_color';
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'hardwareColor';
    END IF;
    
    -- ✅ Solo usar roll_catalog_item_id (sin fallback a fabric_catalog_item_id)
    v_roll_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
    IF v_roll_item_id IS NULL THEN
        v_roll_item_id := (p_config_snapshot->>'variantId')::uuid;
    END IF;
    IF v_roll_item_id IS NULL THEN
        v_roll_item_id := (p_config_snapshot->>'catalogItemId')::uuid;
    END IF;
    
    v_selected_bottom_bar_sku := p_config_snapshot->>'bottom_bar_sku';
    v_selected_headbox_sku := p_config_snapshot->>'headbox_sku';
    v_selected_side_channel_sku := p_config_snapshot->>'side_channel_sku';
    v_selected_bottom_channel_sku := p_config_snapshot->>'bottom_channel_sku';
    v_selected_motor_sku := p_config_snapshot->>'motor_sku';
    v_selected_drive_sku := p_config_snapshot->>'drive_sku';
    v_selected_tube_sku := p_config_snapshot->>'tube_sku';

    -- Buscar template que coincida con todas las selecciones
    -- Filtros: product_type_id + hardware_color + SKUs exactos de componentes seleccionados
    SELECT bt.id
    INTO v_template_id
    FROM "public"."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
        AND bt.product_type_id = p_product_type_id
        AND bt.deleted = false
        AND (
            v_hardware_color IS NULL 
            OR bt.hardware_color = v_hardware_color
        )
        -- Filtrar por SKUs exactos de componentes seleccionados
        -- ✅ Obtener SKU desde CatalogItems (no desde slot_item_sku que no existe)
        -- ✅ BOMTemplateSlots NO tiene columna "deleted"
        AND (
            v_selected_bottom_bar_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'bottom_bar'
                    AND TRIM(ci.sku) = TRIM(v_selected_bottom_bar_sku)
            )
        )
        AND (
            v_selected_headbox_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'headbox'
                    AND TRIM(ci.sku) = TRIM(v_selected_headbox_sku)
            )
        )
        AND (
            v_selected_side_channel_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'side_channel'
                    AND TRIM(ci.sku) = TRIM(v_selected_side_channel_sku)
            )
        )
        AND (
            v_selected_bottom_channel_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'bottom_channel'
                    AND TRIM(ci.sku) = TRIM(v_selected_bottom_channel_sku)
            )
        )
        AND (
            v_selected_motor_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'motor'
                    AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
            )
        )
        AND (
            v_selected_drive_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'drive'
                    AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
            )
        )
        AND (
            v_selected_tube_sku IS NULL
            OR EXISTS (
                SELECT 1 FROM "public"."BOMTemplateSlots" bts
                JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                WHERE bts.bom_template_id = bt.id
                    AND bts.organization_id = p_org_id
                    AND bts.item_role = 'tube'
                    AND TRIM(ci.sku) = TRIM(v_selected_tube_sku)
            )
        )
    ORDER BY bt.created_at DESC
    LIMIT 1;

    RETURN v_template_id;
END;
$$;

-- ====================================================
-- STEP 4: Verificar que no haya referencias restantes a fabric_*
--         en otras funciones (solo informativo)
-- ====================================================

DO $$
DECLARE
    v_func_name text;
    v_func_body text;
BEGIN
    -- Buscar funciones que aún mencionen fabric_*
    FOR v_func_name IN
        SELECT routine_name
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_type = 'FUNCTION'
        AND routine_name LIKE '%configured_product%'
    LOOP
        SELECT pg_get_functiondef(oid::regprocedure)
        INTO v_func_body
        FROM pg_proc
        WHERE proname = v_func_name
        LIMIT 1;

        -- Solo mostrar advertencia si encuentra fabric_* (no crítico)
        IF v_func_body LIKE '%fabric_%' THEN
            RAISE NOTICE 'Advertencia: Función % todavía menciona fabric_* (revisar manualmente si es necesario)', v_func_name;
        END IF;
    END LOOP;
END $$;

COMMIT;

-- ====================================================
-- NOTAS POST-MIGRACIÓN:
-- ====================================================
-- 1. Verificar que ProductConfigurator.tsx ya no agregue fabric_catalog_item_id al configSnapshot
-- 2. Verificar que QuoteNew.tsx ya no use fallbacks a fabric_msrp_total o fabric_plus_bom_total
-- 3. Actualizar tipos TypeScript en configured-product.ts para remover campos legacy
-- 4. Actualizar otros archivos que puedan referenciar fabric_catalog_item_id o fabric_variant_id
