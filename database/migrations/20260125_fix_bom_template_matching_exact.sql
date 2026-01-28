-- ====================================================
-- MIGRATION: Mejorar select_best_bom_template_for_configured_product
-- Date: 2026-01-25
-- Description: 
--  Mejora la función para que sea EXACTA (SKUs y hardware_color deben coincidir exactamente).
--  Agrega mejor logging y debugging para identificar por qué no encuentra templates.
--  Los SKUs son exactos y provienen del catálogo, por lo que el matching debe ser exacto.
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Mejorar select_best_bom_template_for_configured_product
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
    v_selected_bottom_bar_sku text;
    v_selected_headbox_sku text;
    v_selected_side_channel_sku text;
    v_selected_bottom_channel_sku text;
    v_selected_motor_sku text;
    v_selected_drive_sku text;
    v_selected_tube_sku text;
    v_matching_count integer;
    v_debug_info text;
BEGIN
    -- Extraer valores del config_snapshot
    v_hardware_color := p_config_snapshot->>'hardware_color';
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'hardwareColor';
    END IF;
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'operatingSystemColor';
    END IF;
    
    -- Normalizar hardware_color (capitalize first letter)
    IF v_hardware_color IS NOT NULL THEN
        v_hardware_color := UPPER(SUBSTRING(v_hardware_color, 1, 1)) || LOWER(SUBSTRING(v_hardware_color, 2));
    END IF;
    
    v_selected_bottom_bar_sku := p_config_snapshot->>'bottom_bar_sku';
    v_selected_headbox_sku := p_config_snapshot->>'headbox_sku';
    v_selected_side_channel_sku := p_config_snapshot->>'side_channel_sku';
    v_selected_bottom_channel_sku := p_config_snapshot->>'bottom_channel_sku';
    v_selected_motor_sku := p_config_snapshot->>'motor_sku';
    v_selected_drive_sku := p_config_snapshot->>'drive_sku';
    v_selected_tube_sku := p_config_snapshot->>'tube_sku';

    -- ✅ DEBUG: Log valores extraídos
    v_debug_info := format(
        'Config snapshot: hardware_color=%s, bottom_bar_sku=%s, headbox_sku=%s, motor_sku=%s, drive_sku=%s, tube_sku=%s',
        v_hardware_color,
        v_selected_bottom_bar_sku,
        v_selected_headbox_sku,
        v_selected_motor_sku,
        v_selected_drive_sku,
        v_selected_tube_sku
    );
    RAISE NOTICE '%', v_debug_info;

    -- Buscar template que coincida EXACTAMENTE con todas las selecciones
    -- ✅ CRÍTICO: hardware_color debe coincidir EXACTAMENTE (case-insensitive pero exacto)
    -- ✅ CRÍTICO: SKUs deben coincidir EXACTAMENTE (trim, case-sensitive)
    SELECT bt.id
    INTO v_template_id
    FROM "public"."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
        AND bt.product_type_id = p_product_type_id
        AND bt.deleted = false
        AND bt.archived = false
        -- ✅ hardware_color debe coincidir EXACTAMENTE (case-insensitive)
        AND (
            v_hardware_color IS NULL 
            OR LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color))
        )
        -- ✅ Filtrar por SKUs exactos de componentes seleccionados
        -- Si un SKU está en config_snapshot, el template DEBE tenerlo exacto
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
    ORDER BY 
        -- Priorizar templates con hardware_color que coincida exactamente
        CASE 
            WHEN v_hardware_color IS NOT NULL 
                 AND LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
            THEN 0 
            ELSE 1 
        END,
        COALESCE((bt.metadata->>'priority')::int, 0) DESC,
        bt.updated_at DESC
    LIMIT 1;

    -- ✅ DEBUG: Si no se encontró template, log información de debugging
    IF v_template_id IS NULL THEN
        -- Contar templates disponibles para este product_type_id
        SELECT COUNT(*) INTO v_matching_count
        FROM "public"."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false;
        
        RAISE WARNING 'No BOMTemplate found for org=%, product_type_id=%, hardware_color=%. Available templates for product_type: %. Config: %',
            p_org_id, p_product_type_id, v_hardware_color, v_matching_count, v_debug_info;
    ELSE
        RAISE NOTICE 'BOMTemplate found: % for org=%, product_type_id=%, hardware_color=%',
            v_template_id, p_org_id, p_product_type_id, v_hardware_color;
    END IF;

    RETURN v_template_id;
END;
$$;

COMMENT ON FUNCTION "public"."select_best_bom_template_for_configured_product"(uuid, uuid, jsonb) IS 
'Selecciona el mejor BOMTemplate para una configuración.
✅ EXACTO: hardware_color y SKUs deben coincidir EXACTAMENTE.
- hardware_color: case-insensitive pero debe coincidir exactamente
- SKUs: case-sensitive, trim, deben coincidir exactamente
- Si un SKU está en config_snapshot, el template DEBE tenerlo exacto
- Retorna NULL solo si NO existe ningún template que cumpla todos los criterios exactos';

COMMIT;
