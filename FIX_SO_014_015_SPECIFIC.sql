-- ============================================================================
-- CORRECCIÓN ESPECÍFICA: SO-000014 y SO-000015
-- ============================================================================

DO $$
DECLARE
    v_quote_line_record RECORD;
    v_sale_order_line_id UUID;
    v_bom_instance_id UUID;
    v_bom_template_id UUID;
    v_qlc_count INT;
    v_bil_count INT;
    v_result jsonb;
    v_error_count INT := 0;
    v_success_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔄 CORRIGIENDO SO-000014 y SO-000015';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            sol.id as sale_order_line_id,
            so.sale_order_no,
            q.quote_no
        FROM "SaleOrders" so
        INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        INNER JOIN "Quotes" q ON q.id = ql.quote_id AND q.deleted = false
        WHERE so.sale_order_no IN ('SO-000014', 'SO-000015')
            AND so.deleted = false
            AND ql.deleted = false
        ORDER BY so.sale_order_no
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '📦 Procesando: % - QuoteLine: % (Quote: %)', 
            v_quote_line_record.sale_order_no,
            v_quote_line_record.quote_line_id,
            v_quote_line_record.quote_no;
        
        -- Verificar product_type_id
        IF v_quote_line_record.product_type_id IS NULL THEN
            RAISE NOTICE '   ❌ QuoteLine no tiene product_type_id';
            v_error_count := v_error_count + 1;
            CONTINUE;
        END IF;
        
        -- Verificar organization_id
        IF v_quote_line_record.organization_id IS NULL THEN
            RAISE NOTICE '   ⚠️  QuoteLine no tiene organization_id. Intentando corregir...';
            -- Intentar obtener organization_id del Quote
            UPDATE "QuoteLines"
            SET organization_id = (
                SELECT organization_id FROM "Quotes" WHERE id = (
                    SELECT quote_id FROM "QuoteLines" WHERE id = v_quote_line_record.quote_line_id
                )
            )
            WHERE id = v_quote_line_record.quote_line_id;
            
            -- Recargar organization_id
            SELECT organization_id INTO v_quote_line_record.organization_id
            FROM "QuoteLines"
            WHERE id = v_quote_line_record.quote_line_id;
            
            IF v_quote_line_record.organization_id IS NULL THEN
                RAISE NOTICE '   ❌ No se pudo obtener organization_id';
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
        END IF;
        
        RAISE NOTICE '   ✅ QuoteLine tiene product_type_id: % y organization_id: %', 
            v_quote_line_record.product_type_id,
            v_quote_line_record.organization_id;
        
        -- Verificar si ya existen QuoteLineComponents
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_record.quote_line_id
            AND source = 'configured_component'
            AND deleted = false;
        
        IF v_qlc_count = 0 THEN
            RAISE NOTICE '   🔧 Generando QuoteLineComponents...';
            
            -- Generar QuoteLineComponents
            BEGIN
                v_result := public.generate_configured_bom_for_quote_line(
                    v_quote_line_record.quote_line_id,
                    v_quote_line_record.product_type_id,
                    v_quote_line_record.organization_id,
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
                
                -- Verificar si se generaron
                SELECT COUNT(*) INTO v_qlc_count
                FROM "QuoteLineComponents"
                WHERE quote_line_id = v_quote_line_record.quote_line_id
                    AND source = 'configured_component'
                    AND deleted = false;
                
                IF v_qlc_count > 0 THEN
                    RAISE NOTICE '   ✅ QuoteLineComponents generados: % componentes', v_qlc_count;
                ELSE
                    RAISE NOTICE '   ⚠️  No se generaron QuoteLineComponents';
                    v_error_count := v_error_count + 1;
                    CONTINUE;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '   ❌ Error generando QuoteLineComponents: %', SQLERRM;
                    v_error_count := v_error_count + 1;
                    CONTINUE;
            END;
        ELSE
            RAISE NOTICE '   ✅ QuoteLineComponents ya existen: % componentes', v_qlc_count;
        END IF;
        
        -- Verificar y crear BomInstance
        IF v_quote_line_record.sale_order_line_id IS NOT NULL THEN
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
                AND deleted = false
            LIMIT 1;
            
            IF v_bom_instance_id IS NULL THEN
                -- Obtener BOMTemplate
                SELECT id INTO v_bom_template_id
                FROM "BOMTemplates"
                WHERE product_type_id = v_quote_line_record.product_type_id
                    AND deleted = false
                    AND active = true
                ORDER BY 
                    CASE WHEN organization_id = v_quote_line_record.organization_id THEN 0 ELSE 1 END,
                    created_at DESC
                LIMIT 1;
                
                IF v_bom_template_id IS NULL THEN
                    RAISE NOTICE '   ⚠️  No se encontró BOMTemplate activo';
                ELSE
                    RAISE NOTICE '   ✅ BOMTemplate encontrado: %', v_bom_template_id;
                END IF;
                
                -- Crear BomInstance
                BEGIN
                    INSERT INTO "BomInstances" (
                        organization_id,
                        sale_order_line_id,
                        quote_line_id,
                        bom_template_id,
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_quote_line_record.organization_id,
                        v_quote_line_record.sale_order_line_id,
                        v_quote_line_record.quote_line_id,
                        v_bom_template_id,
                        false,
                        NOW(),
                        NOW()
                    ) RETURNING id INTO v_bom_instance_id;
                    
                    RAISE NOTICE '   ✅ BomInstance creado: %', v_bom_instance_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE '   ❌ Error creando BomInstance: %', SQLERRM;
                        v_error_count := v_error_count + 1;
                        CONTINUE;
                END;
            ELSE
                RAISE NOTICE '   ✅ BomInstance ya existe: %', v_bom_instance_id;
            END IF;
            
            -- Copiar QuoteLineComponents a BomInstanceLines
            IF v_bom_instance_id IS NOT NULL THEN
                -- Eliminar BomInstanceLines existentes para regenerar
                DELETE FROM "BomInstanceLines"
                WHERE bom_instance_id = v_bom_instance_id;
                
                BEGIN
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
                    WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
                        AND qlc.deleted = false
                        AND qlc.source = 'configured_component'
                    ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                    WHERE deleted = false
                    DO NOTHING;
                    
                    GET DIAGNOSTICS v_bil_count = ROW_COUNT;
                    RAISE NOTICE '   ✅ BomInstanceLines creados: % componentes', v_bil_count;
                    v_success_count := v_success_count + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE '   ❌ Error creando BomInstanceLines: %', SQLERRM;
                        v_error_count := v_error_count + 1;
                END;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CORRECCIÓN COMPLETA';
    RAISE NOTICE '   ✅ Exitosos: %', v_success_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '   ⚠️  Errores: %', v_error_count;
    END IF;
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error corrigiendo SO-000014 y SO-000015: %', SQLERRM;
END $$;

-- Verificar resultado
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
WHERE so.sale_order_no IN ('SO-000014', 'SO-000015')
    AND so.deleted = false
GROUP BY so.id, so.sale_order_no
ORDER BY so.sale_order_no;








