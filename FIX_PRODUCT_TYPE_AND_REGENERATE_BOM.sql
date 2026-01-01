-- ============================================================================
-- CORRECCIÓN COMPLETA: Agregar product_type_id y regenerar BOM
-- Para SO-000011, SO-000012, SO-000013
-- ============================================================================

DO $$
DECLARE
    v_quote_line_id UUID;
    v_product_type_id UUID;
    v_organization_id UUID;
    v_product_type_code TEXT;
    v_count INT;
    rec RECORD;
    v_sale_order_line_id UUID;
    v_bom_instance_id UUID;
    v_bom_template_id UUID;
    v_quote_line_record RECORD;
    v_result jsonb;
    v_error_count INT := 0;
    v_success_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔧 CORRIGIENDO product_type_id Y REGENERANDO BOM';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- Paso 1: Identificar y corregir product_type_id
    RAISE NOTICE '📋 PASO 1: Identificando product_type_id...';
    
    FOR rec IN 
        SELECT 
            so.id as sale_order_id,
            so.sale_order_no,
            so.organization_id,
            sol.id as sale_order_line_id,
            ql.id as quote_line_id,
            ql.product_type,
            ql.drive_type,
            ql.organization_id as ql_org_id
        FROM "SaleOrders" so
        INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
            AND so.deleted = false
            AND ql.product_type_id IS NULL
        ORDER BY so.sale_order_no
    LOOP
        v_quote_line_id := rec.quote_line_id;
        v_organization_id := COALESCE(rec.ql_org_id, rec.organization_id);
        v_sale_order_line_id := rec.sale_order_line_id;
        
        RAISE NOTICE '';
        RAISE NOTICE '📦 Procesando: % - QuoteLine: %', rec.sale_order_no, v_quote_line_id;
        RAISE NOTICE '   - product_type (string): %', rec.product_type;
        RAISE NOTICE '   - drive_type: %', rec.drive_type;
        RAISE NOTICE '   - organization_id: %', v_organization_id;
        
        -- Intentar encontrar product_type_id por código
        IF rec.product_type IS NOT NULL THEN
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE UPPER(code) = UPPER(rec.product_type)
                AND (organization_id = v_organization_id OR organization_id IS NULL)
                AND deleted = false
            ORDER BY 
                CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_product_type_id IS NOT NULL THEN
                RAISE NOTICE '   ✅ ProductType encontrado por código: % (ID: %)', rec.product_type, v_product_type_id;
            END IF;
        END IF;
        
        -- Si no se encontró por código, buscar por tipo común (ROLLER SHADE)
        IF v_product_type_id IS NULL THEN
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE UPPER(code) IN ('ROLLER', 'ROLLER_SHADE', 'ROLLER-SHADE')
                AND (organization_id = v_organization_id OR organization_id IS NULL)
                AND deleted = false
            ORDER BY 
                CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_product_type_id IS NOT NULL THEN
                RAISE NOTICE '   ✅ ProductType encontrado por tipo común (ROLLER): %', v_product_type_id;
            END IF;
        END IF;
        
        -- Si aún no se encontró, buscar cualquier ProductType activo de la organización
        IF v_product_type_id IS NULL THEN
            SELECT id INTO v_product_type_id
            FROM "ProductTypes"
            WHERE (organization_id = v_organization_id OR organization_id IS NULL)
                AND deleted = false
            ORDER BY 
                CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1;
            
            IF v_product_type_id IS NOT NULL THEN
                RAISE NOTICE '   ⚠️  ProductType encontrado (cualquiera disponible): %', v_product_type_id;
            END IF;
        END IF;
        
        -- Si no se encontró ningún ProductType, mostrar error
        IF v_product_type_id IS NULL THEN
            RAISE NOTICE '   ❌ NO SE ENCONTRÓ ProductType para organization_id: %', v_organization_id;
            v_error_count := v_error_count + 1;
            CONTINUE;
        END IF;
        
        -- Actualizar QuoteLine con product_type_id
        BEGIN
            UPDATE "QuoteLines"
            SET 
                product_type_id = v_product_type_id,
                organization_id = v_organization_id,
                updated_at = NOW()
            WHERE id = v_quote_line_id;
            
            RAISE NOTICE '   ✅ QuoteLine actualizado con product_type_id: %', v_product_type_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '   ❌ Error actualizando QuoteLine: %', SQLERRM;
                v_error_count := v_error_count + 1;
                CONTINUE;
        END;
        
        -- Obtener QuoteLine completo
        SELECT * INTO v_quote_line_record
        FROM "QuoteLines"
        WHERE id = v_quote_line_id AND deleted = false;
        
        IF NOT FOUND THEN
            RAISE NOTICE '   ❌ QuoteLine no encontrado después de actualizar';
            v_error_count := v_error_count + 1;
            CONTINUE;
        END IF;
        
        -- Verificar BOMTemplate
        SELECT id INTO v_bom_template_id
        FROM "BOMTemplates"
        WHERE product_type_id = v_product_type_id
            AND deleted = false
            AND active = true
        ORDER BY 
            CASE WHEN organization_id = v_organization_id THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_bom_template_id IS NULL THEN
            RAISE NOTICE '   ⚠️  No se encontró BOMTemplate activo para product_type_id: %', v_product_type_id;
            RAISE NOTICE '      Continuando de todas formas...';
        ELSE
            RAISE NOTICE '   ✅ BOMTemplate encontrado: %', v_bom_template_id;
        END IF;
        
        -- Eliminar QuoteLineComponents existentes (solo fabric)
        DELETE FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_id
            AND deleted = false
            AND source = 'configured_component';
        
        RAISE NOTICE '   🧹 QuoteLineComponents antiguos eliminados';
        
        -- Generar QuoteLineComponents
        BEGIN
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line_record.id,
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
            RAISE NOTICE '   ✅ QuoteLineComponents generados';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '   ❌ Error generando QuoteLineComponents: %', SQLERRM;
                RAISE NOTICE '      SQLSTATE: %', SQLSTATE;
                v_error_count := v_error_count + 1;
                CONTINUE;
        END;
        
        -- Verificar QuoteLineComponents generados
        SELECT COUNT(*) INTO v_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_id
            AND deleted = false
            AND source = 'configured_component';
        
        IF v_count = 0 THEN
            RAISE NOTICE '   ⚠️  No se generaron QuoteLineComponents (count = 0)';
            v_error_count := v_error_count + 1;
            CONTINUE;
        END IF;
        
        RAISE NOTICE '   ✅ QuoteLineComponents generados: % componentes', v_count;
        
        -- Eliminar BomInstance existente si existe
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NOT NULL THEN
            DELETE FROM "BomInstanceLines" WHERE bom_instance_id = v_bom_instance_id;
            DELETE FROM "BomInstances" WHERE id = v_bom_instance_id;
            RAISE NOTICE '   🧹 BomInstance antiguo eliminado';
        END IF;
        
        -- Crear BomInstance
        IF v_bom_template_id IS NOT NULL THEN
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
                    v_organization_id,
                    v_sale_order_line_id,
                    v_quote_line_id,
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
            
            -- Copiar QuoteLineComponents a BomInstanceLines
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
                WHERE qlc.quote_line_id = v_quote_line_id
                    AND qlc.deleted = false
                    AND qlc.source = 'configured_component';
                
                GET DIAGNOSTICS v_count = ROW_COUNT;
                RAISE NOTICE '   ✅ BomInstanceLines creados: % componentes', v_count;
                v_success_count := v_success_count + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '   ❌ Error creando BomInstanceLines: %', SQLERRM;
                    RAISE NOTICE '      SQLSTATE: %', SQLSTATE;
                    v_error_count := v_error_count + 1;
            END;
        ELSE
            RAISE NOTICE '   ⚠️  No se creó BomInstance porque no hay BOMTemplate';
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
        RAISE EXCEPTION 'Error corrigiendo product_type_id: %', SQLERRM;
END $$;

-- Verificar resultado final
SELECT 
    'RESULTADO FINAL' as paso,
    so.sale_order_no,
    ql.product_type_id,
    pt.name as product_type_name,
    COUNT(DISTINCT sol.id) as sale_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as qlc_count,
    (SELECT COUNT(*) FROM "SaleOrderMaterialList" sml WHERE sml.sale_order_id = so.id) as materiales_en_view
FROM "SaleOrders" so
LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.id, so.sale_order_no, ql.product_type_id, pt.name
ORDER BY so.sale_order_no;








