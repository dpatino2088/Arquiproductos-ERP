-- ============================================================================
-- REGENERAR BOM PARA TODOS LOS SALE ORDERS QUE NO LO TIENEN
-- ============================================================================
-- Este script regenera los BOM para todos los Sale Orders que tienen
-- SaleOrderLines pero no tienen BomInstances

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
    v_total_processed INT := 0;
    v_total_created INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔄 REGENERANDO BOM PARA TODOS LOS SALE ORDERS SIN BOM';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- Obtener todos los Sale Orders sin BOM
    FOR rec IN 
        SELECT DISTINCT
            so.id as sale_order_id,
            so.sale_order_no,
            so.quote_id,
            so.organization_id
        FROM "SaleOrders" so
        INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
        WHERE so.deleted = false
            AND NOT EXISTS (
                SELECT 1 FROM "BomInstances" bi
                WHERE bi.sale_order_line_id = sol.id AND bi.deleted = false
            )
        ORDER BY so.sale_order_no
    LOOP
        v_so_id := rec.sale_order_id;
        v_organization_id := rec.organization_id;
        v_sale_order_no := rec.sale_order_no;
        v_total_processed := v_total_processed + 1;
        
        RAISE NOTICE '📋 [%/%] Procesando: % (Quote: %)', 
            v_total_processed, 
            (SELECT COUNT(DISTINCT so2.id) FROM "SaleOrders" so2 
             INNER JOIN "SaleOrderLines" sol2 ON sol2.sale_order_id = so2.id AND sol2.deleted = false
             WHERE so2.deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM "BomInstances" bi2
                    WHERE bi2.sale_order_line_id = sol2.id AND bi2.deleted = false
                )),
            v_sale_order_no, 
            rec.quote_id;
        
        -- Procesar cada SaleOrderLine
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
                
                IF NOT FOUND THEN
                    RAISE NOTICE '   ⚠️  QuoteLine % no encontrado', v_quote_line_id;
                    CONTINUE;
                END IF;
                
                IF v_quote_line_record.product_type_id IS NULL THEN
                    RAISE NOTICE '   ⚠️  QuoteLine % no tiene product_type_id', v_quote_line_id;
                    CONTINUE;
                END IF;
                
                -- Generar QuoteLineComponents usando la función
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
                        RAISE NOTICE '   ❌ Error generando QuoteLineComponents: %', SQLERRM;
                        CONTINUE;
                END;
                
                -- Obtener BOMTemplate
                SELECT id INTO v_bom_template_id
                FROM "BOMTemplates"
                WHERE product_type_id = v_quote_line_record.product_type_id
                    AND deleted = false
                ORDER BY created_at DESC
                LIMIT 1;
                
                IF v_bom_template_id IS NULL THEN
                    RAISE NOTICE '   ⚠️  No se encontró BOMTemplate para product_type_id = %', v_quote_line_record.product_type_id;
                    CONTINUE;
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
                        v_organization_id,
                        v_sale_order_line_id,
                        v_quote_line_id,
                        v_bom_template_id,
                        false,
                        NOW(),
                        NOW()
                    ) RETURNING id INTO v_bom_instance_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE '   ❌ Error creando BomInstance: %', SQLERRM;
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
                    v_total_created := v_total_created + v_count;
                    RAISE NOTICE '   ✅ BOM generado: % componentes', v_count;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE '   ❌ Error creando BomInstanceLines: %', SQLERRM;
                END;
            END IF;
        END LOOP;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ REGENERACIÓN COMPLETA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '   Sale Orders procesados: %', v_total_processed;
    RAISE NOTICE '   Componentes creados: %', v_total_created;
    RAISE NOTICE '';
    RAISE NOTICE 'Recarga la página para ver los BOM generados';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error regenerando BOM: %', SQLERRM;
END $$;








