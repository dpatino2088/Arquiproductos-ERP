-- ============================================================================
-- CORRECCIÓN COMPLETA PARA SO-000011, SO-000012, SO-000013
-- Este script regenera los BOM de forma más robusta
-- ============================================================================

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
    v_error_count INT := 0;
    v_success_count INT := 0;
    v_result jsonb;
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
            so.organization_id
        FROM "SaleOrders" so
        WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
            AND so.deleted = false
        ORDER BY so.sale_order_no
    LOOP
        v_so_id := rec.sale_order_id;
        v_organization_id := rec.organization_id;
        v_sale_order_no := rec.sale_order_no;
        
        RAISE NOTICE '📋 Procesando: % (org_id: %)', v_sale_order_no, v_organization_id;
        
        -- Verificar que existe organization_id
        IF v_organization_id IS NULL THEN
            RAISE NOTICE '   ❌ Sale Order no tiene organization_id';
            v_error_count := v_error_count + 1;
            CONTINUE;
        END IF;
        
        FOR v_sale_order_line_id, v_quote_line_id IN 
            SELECT sol.id, sol.quote_line_id
            FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = v_so_id AND sol.deleted = false
        LOOP
            RAISE NOTICE '   📦 SaleOrderLine: %, QuoteLine: %', v_sale_order_line_id, v_quote_line_id;
            
            -- Verificar si ya existe BomInstance
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_sale_order_line_id AND deleted = false
            LIMIT 1;
            
            IF v_bom_instance_id IS NOT NULL THEN
                RAISE NOTICE '   ⚠️  BomInstance ya existe: %. Eliminando para regenerar...', v_bom_instance_id;
                -- Eliminar BomInstanceLines primero
                DELETE FROM "BomInstanceLines" WHERE bom_instance_id = v_bom_instance_id;
                -- Eliminar BomInstance
                DELETE FROM "BomInstances" WHERE id = v_bom_instance_id;
                v_bom_instance_id := NULL;
            END IF;
            
            -- Obtener QuoteLine
            SELECT * INTO v_quote_line_record
            FROM "QuoteLines"
            WHERE id = v_quote_line_id AND deleted = false;
            
            IF NOT FOUND THEN
                RAISE NOTICE '   ❌ QuoteLine % no encontrado', v_quote_line_id;
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
            
            IF v_quote_line_record.product_type_id IS NULL THEN
                RAISE NOTICE '   ❌ QuoteLine % no tiene product_type_id', v_quote_line_id;
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
            
            IF v_quote_line_record.organization_id IS NULL THEN
                RAISE NOTICE '   ⚠️  QuoteLine no tiene organization_id. Usando el del SaleOrder...';
                UPDATE "QuoteLines" 
                SET organization_id = v_organization_id 
                WHERE id = v_quote_line_id;
                v_quote_line_record.organization_id := v_organization_id;
            END IF;
            
            RAISE NOTICE '   ✅ QuoteLine encontrado:';
            RAISE NOTICE '      - product_type_id: %', v_quote_line_record.product_type_id;
            RAISE NOTICE '      - organization_id: %', v_quote_line_record.organization_id;
            RAISE NOTICE '      - drive_type: %', v_quote_line_record.drive_type;
            RAISE NOTICE '      - bottom_rail_type: %', v_quote_line_record.bottom_rail_type;
            RAISE NOTICE '      - cassette: %', v_quote_line_record.cassette;
            RAISE NOTICE '      - side_channel: %', v_quote_line_record.side_channel;
            RAISE NOTICE '      - hardware_color: %', v_quote_line_record.hardware_color;
            RAISE NOTICE '      - width_m: %, height_m: %', v_quote_line_record.width_m, v_quote_line_record.height_m;
            
            -- Verificar BOMTemplate antes de generar
            SELECT id INTO v_bom_template_id
            FROM "BOMTemplates"
            WHERE product_type_id = v_quote_line_record.product_type_id
                AND organization_id = v_quote_line_record.organization_id
                AND deleted = false
                AND active = true
            ORDER BY created_at DESC
            LIMIT 1;
            
            IF v_bom_template_id IS NULL THEN
                RAISE NOTICE '   ❌ No se encontró BOMTemplate activo para product_type_id = % (org_id: %)', 
                    v_quote_line_record.product_type_id, v_quote_line_record.organization_id;
                
                -- Intentar buscar sin filtro de organization_id (templates compartidos)
                SELECT id INTO v_bom_template_id
                FROM "BOMTemplates"
                WHERE product_type_id = v_quote_line_record.product_type_id
                    AND deleted = false
                    AND active = true
                ORDER BY created_at DESC
                LIMIT 1;
                
                IF v_bom_template_id IS NULL THEN
                    RAISE NOTICE '   ❌ Tampoco hay BOMTemplate compartido';
                    v_error_count := v_error_count + 1;
                    CONTINUE;
                ELSE
                    RAISE NOTICE '   ✅ Encontrado BOMTemplate compartido: %', v_bom_template_id;
                END IF;
            ELSE
                RAISE NOTICE '   ✅ BOMTemplate encontrado: %', v_bom_template_id;
            END IF;
            
            -- Eliminar QuoteLineComponents existentes (para regenerar limpio)
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
            
            -- Verificar si se generaron QuoteLineComponents
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
        END LOOP;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ REGENERACIÓN COMPLETA';
    RAISE NOTICE '   ✅ Exitosos: %', v_success_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '   ⚠️  Errores: %', v_error_count;
    END IF;
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error regenerando BOM: %', SQLERRM;
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
WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
    AND so.deleted = false
GROUP BY so.id, so.sale_order_no
ORDER BY so.sale_order_no;








