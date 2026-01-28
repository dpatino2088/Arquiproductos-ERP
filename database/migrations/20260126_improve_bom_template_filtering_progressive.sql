-- ====================================================
-- MIGRATION: Mejorar filtrado progresivo de BOM Templates
-- Date: 2026-01-26
-- Description: 
--  Implementa filtrado progresivo según criterios obligatorios/opcionales:
--  OBLIGATORIOS: ProductType, Color, Bottom Bar, Operating Type (motor O drive, no ambos), Tube
--  OPCIONALES: Headbox, Side Channel, Bottom Channel
--  Prioriza templates con más coincidencias exactas
--  Valida que no haya SKUs duplicados
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
    v_operating_type text; -- 'motor' o 'manual'
    v_matching_count integer;
    v_debug_info text;
    v_match_score integer;
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
    
    -- ✅ CRITICAL: Determinar Operating Type (obligatorio)
    -- Si hay motor_sku, operating_type = 'motor'
    -- Si hay drive_sku, operating_type = 'manual'
    -- NO pueden estar ambos
    IF v_selected_motor_sku IS NOT NULL AND v_selected_drive_sku IS NOT NULL THEN
        RAISE WARNING 'Invalid config: both motor_sku and drive_sku are set. Only one should be set.';
        -- Preferir motor si ambos están presentes
        v_operating_type := 'motor';
        v_selected_drive_sku := NULL;
    ELSIF v_selected_motor_sku IS NOT NULL THEN
        v_operating_type := 'motor';
    ELSIF v_selected_drive_sku IS NOT NULL THEN
        v_operating_type := 'manual';
    ELSE
        v_operating_type := NULL;
    END IF;

    -- ✅ DEBUG: Log valores extraídos
    v_debug_info := format(
        'Config snapshot: hardware_color=%s, operating_type=%s, bottom_bar_sku=%s, headbox_sku=%s, motor_sku=%s, drive_sku=%s, tube_sku=%s, side_channel_sku=%s, bottom_channel_sku=%s',
        v_hardware_color,
        v_operating_type,
        v_selected_bottom_bar_sku,
        v_selected_headbox_sku,
        v_selected_motor_sku,
        v_selected_drive_sku,
        v_selected_tube_sku,
        v_selected_side_channel_sku,
        v_selected_bottom_channel_sku
    );
    RAISE NOTICE '%', v_debug_info;

    -- ✅ FILTRADO PROGRESIVO: Buscar templates que coincidan EXACTAMENTE
    -- OBLIGATORIOS primero, luego OPCIONALES
    -- Usar subquery para calcular score y ordenar
    WITH scored_templates AS (
        SELECT bt.id,
               bt.hardware_color,
               bt.metadata,
               bt.updated_at,
               -- Calcular score: más coincidencias = mejor
               (CASE WHEN v_hardware_color IS NOT NULL 
                          AND LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_bottom_bar_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'bottom_bar'
                                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_bar_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_tube_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'tube'
                                        AND TRIM(ci.sku) = TRIM(v_selected_tube_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_operating_type = 'motor' AND v_selected_motor_sku IS NOT NULL
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'motor'
                                        AND TRIM(ci.sku) = TRIM(v_selected_motor_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_operating_type = 'manual' AND v_selected_drive_sku IS NOT NULL
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'drive'
                                        AND TRIM(ci.sku) = TRIM(v_selected_drive_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_headbox_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'headbox'
                                        AND TRIM(ci.sku) = TRIM(v_selected_headbox_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_side_channel_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'side_channel'
                                        AND TRIM(ci.sku) = TRIM(v_selected_side_channel_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_bottom_channel_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'bottom_channel'
                                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_channel_sku))
                     THEN 1 ELSE 0 END) AS match_score
        FROM "public"."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false
            -- ✅ OBLIGATORIO 1: hardware_color debe coincidir EXACTAMENTE
            AND (
                v_hardware_color IS NULL 
                OR LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color))
            )
            -- ✅ OBLIGATORIO 2: Bottom Bar SKU debe coincidir EXACTAMENTE
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
            -- ✅ OBLIGATORIO 3: Tube SKU debe coincidir EXACTAMENTE
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
            -- ✅ OBLIGATORIO 4: Operating Type (motor O drive, no ambos)
            AND (
                v_operating_type IS NULL
                OR (
                    v_operating_type = 'motor' 
                    AND v_selected_motor_sku IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'motor'
                            AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
                    )
                    -- ✅ Validar que NO tenga drive_sku (no puede tener ambos)
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'drive'
                            AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
                    )
                )
                OR (
                    v_operating_type = 'manual' 
                    AND v_selected_drive_sku IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'drive'
                            AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
                    )
                    -- ✅ Validar que NO tenga motor_sku (no puede tener ambos)
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'motor'
                            AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
                    )
                )
            )
            -- ✅ OPCIONAL 1: Headbox SKU (si está seleccionado, debe coincidir)
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
            -- ✅ OPCIONAL 2: Side Channel SKU (si está seleccionado, debe coincidir)
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
            -- ✅ OPCIONAL 3: Bottom Channel SKU (si está seleccionado, debe coincidir)
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
    )
    SELECT st.id, st.match_score
    INTO v_template_id, v_match_score
    FROM scored_templates st
    ORDER BY 
        -- 1. Priorizar por score (más coincidencias primero) - CRÍTICO para desambiguar
        st.match_score DESC,
        -- 2. Priorizar templates que coincidan con hardware_color exacto
        CASE 
            WHEN v_hardware_color IS NOT NULL 
                 AND LOWER(TRIM(COALESCE(st.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
            THEN 0 
            ELSE 1 
        END,
        -- 3. Luego por priority en metadata
        COALESCE((st.metadata->>'priority')::int, 0) DESC,
        -- 4. Finalmente por updated_at (más reciente primero)
        st.updated_at DESC
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
        
        RAISE WARNING 'No BOMTemplate found for org=%, product_type_id=%, hardware_color=%, operating_type=%. Available templates for product_type: %. Config: %',
            p_org_id, p_product_type_id, v_hardware_color, v_operating_type, v_matching_count, v_debug_info;
    ELSE
        RAISE NOTICE 'BOMTemplate found: % (score: %) for org=%, product_type_id=%, hardware_color=%, operating_type=%',
            v_template_id, v_match_score, p_org_id, p_product_type_id, v_hardware_color, v_operating_type;
    END IF;

    RETURN v_template_id;
END;
$$;

COMMENT ON FUNCTION "public"."select_best_bom_template_for_configured_product"(uuid, uuid, jsonb) IS 
'Selecciona el mejor BOMTemplate para una configuración con filtrado progresivo.
✅ FILTRADO PROGRESIVO:
- OBLIGATORIOS: ProductType, Color (hardware_color), Bottom Bar (bottom_bar_sku), Operating Type (motor_sku O drive_sku, no ambos), Tube (tube_sku)
- OPCIONALES: Headbox (headbox_sku), Side Channel (side_channel_sku), Bottom Channel (bottom_channel_sku)
✅ VALIDACIONES:
- SKUs deben coincidir EXACTAMENTE (trim, case-sensitive)
- hardware_color debe coincidir EXACTAMENTE (case-insensitive)
- Operating Type: motor O manual, no ambos
- No permite SKUs duplicados en el mismo template
✅ PRIORIZACIÓN:
- Ordena por score de coincidencias (más coincidencias = mejor)
- Luego por hardware_color exacto
- Luego por priority en metadata
- Finalmente por updated_at (más reciente primero)';

COMMIT;
