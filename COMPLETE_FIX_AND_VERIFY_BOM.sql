-- ============================================================================
-- CORRECCIÓN COMPLETA Y VERIFICACIÓN DE BOM PARA SO-000011, SO-000012, SO-000013
-- ============================================================================
-- Este script:
-- 1. Verifica el estado actual
-- 2. Regenera los BOM si es necesario
-- 3. Verifica que aparezcan en SaleOrderMaterialList

-- ========================================================================
-- PASO 1: VERIFICAR ESTADO ACTUAL
-- ========================================================================
SELECT 
    'ESTADO ACTUAL' as paso,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sale_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    (SELECT COUNT(*) FROM "SaleOrderMaterialList" sml WHERE sml.sale_order_id = so.id) as materiales_en_view
FROM "SaleOrders" so
LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.id, so.sale_order_no
ORDER BY so.sale_order_no;

-- ========================================================================
-- PASO 2: REGENERAR BOM (ejecutar en un bloque DO separado)
-- ========================================================================
DO $$
DECLARE
    v_so_id UUID;
    v_organization_id UUID;
    v_sale_order_line_id UUID;
    v_quote_line_id UUID;
    v_bom_instance_id UUID;
    v_count INT;
    rec RECORD;
    v_quote_line_record RECORD;
    v_bom_template_id UUID;
    v_sale_order_no TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔄 REGENERANDO BOM PARA SO-000011, SO-000012, SO-000013';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    FOR rec IN 
        SELECT 
            so.id as sale_order_id,
            so.sale_order_no,
            so.quote_id,
            so.organization_id
        FROM "SaleOrders" so
        WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
            AND so.deleted = false
        ORDER BY so.sale_order_no
    LOOP
        v_so_id := rec.sale_order_id;
        v_organization_id := rec.organization_id;
        v_sale_order_no := rec.sale_order_no;
        
        RAISE NOTICE '📋 Procesando: %', v_sale_order_no;
        
        FOR v_sale_order_line_id, v_quote_line_id IN 
            SELECT sol.id, sol.quote_line_id
            FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = v_so_id AND sol.deleted = false
        LOOP
            -- Verificar si ya existe BomInstance
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_sale_order_line_id AND deleted = false
            LIMIT 1;
            
            IF v_bom_instance_id IS NULL THEN
                -- Obtener QuoteLine
                SELECT * INTO v_quote_line_record
                FROM "QuoteLines"
                WHERE id = v_quote_line_id AND deleted = false;
                
                IF FOUND AND v_quote_line_record.product_type_id IS NOT NULL THEN
                    -- Generar QuoteLineComponents
                    BEGIN
                        PERFORM public.generate_configured_bom_for_quote_line(
                            v_quote_line_record.id,
                            v_quote_line_record.product_type_id,
                            v_organization_id,
                            v_quote_line_record.drive_type,
                            v_quote_line_record.bottom_rail_type,
                            v_quote_line_record.cassette,
                            v_quote_line_record.cassette_type,
                            v_quote_line_record.side_channel,
                            v_quote_line_record.side_channel_type,
                            v_quote_line_record.hardware_color,
                            v_quote_line_record.width_m,
                            v_quote_line_record.height_m,
                            v_quote_line_record.qty
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE NOTICE '   ⚠️  Error generando BOM: %', SQLERRM;
                            CONTINUE;
                    END;
                    
                    -- Obtener BOMTemplate
                    SELECT id INTO v_bom_template_id
                    FROM "BOMTemplates"
                    WHERE product_type_id = v_quote_line_record.product_type_id
                        AND deleted = false
                    ORDER BY created_at DESC
                    LIMIT 1;
                    
                    IF v_bom_template_id IS NOT NULL THEN
                        -- Crear BomInstance
                        INSERT INTO "BomInstances" (
                            organization_id,
                            sale_order_line_id,
                            quote_line_id,
                            bom_template_id,
                            deleted,
                            created_at,
                            updated_at
                        ) VALUES (
                            v_organization_id,
                            v_sale_order_line_id,
                            v_quote_line_id,
                            v_bom_template_id,
                            false,
                            NOW(),
                            NOW()
                        ) RETURNING id INTO v_bom_instance_id;
                        
                        -- Copiar QuoteLineComponents a BomInstanceLines
                        INSERT INTO "BomInstanceLines" (
                            organization_id,
                            bom_instance_id,
                            resolved_part_id,
                            qty,
                            uom,
                            unit_cost_exw,
                            total_cost_exw,
                            category_code,
                            description,
                            resolved_sku,
                            part_role,
                            created_at,
                            updated_at,
                            deleted
                        )
                        SELECT 
                            qlc.organization_id,
                            v_bom_instance_id,
                            qlc.catalog_item_id,
                            qlc.qty,
                            qlc.uom,
                            qlc.unit_cost_exw,
                            qlc.qty * COALESCE(qlc.unit_cost_exw, 0),
                            COALESCE(public.derive_category_code_from_role(qlc.component_role), 'accessory'),
                            ci.item_name,
                            ci.sku,
                            qlc.component_role,
                            NOW(),
                            NOW(),
                            false
                        FROM "QuoteLineComponents" qlc
                        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                        WHERE qlc.quote_line_id = v_quote_line_id
                            AND qlc.deleted = false
                            AND qlc.source = 'configured_component';
                        
                        GET DIAGNOSTICS v_count = ROW_COUNT;
                        RAISE NOTICE '   ✅ BOM generado: % componentes', v_count;
                    END IF;
                END IF;
            END IF;
        END LOOP;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '✅ REGENERACIÓN COMPLETA';
    RAISE NOTICE '';
END $$;

-- ========================================================================
-- PASO 3: VERIFICAR RESULTADO FINAL
-- ========================================================================
SELECT 
    'RESULTADO FINAL' as paso,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sale_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    (SELECT COUNT(*) FROM "SaleOrderMaterialList" sml WHERE sml.sale_order_id = so.id) as materiales_en_view
FROM "SaleOrders" so
LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.id, so.sale_order_no
ORDER BY so.sale_order_no;

-- ========================================================================
-- PASO 4: MOSTRAR MATERIALES EN SaleOrderMaterialList
-- ========================================================================
SELECT 
    sale_order_no,
    category_code,
    sku,
    item_name,
    total_qty,
    uom,
    total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
ORDER BY sale_order_no, category_code, sku;








