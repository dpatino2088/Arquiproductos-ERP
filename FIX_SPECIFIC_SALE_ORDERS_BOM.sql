-- ============================================================================
-- CORREGIR BOM PARA SO-000011, SO-000012, SO-000013
-- ============================================================================
-- Script específico para regenerar BOM en estos 3 Sale Orders

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
    
    -- Procesar cada uno de los 3 Sale Orders
    FOR rec IN 
        SELECT 
            so.id as sale_order_id,
            so.sale_order_no,
            so.quote_id,
            so.organization_id
        FROM "SaleOrders" so
        WHERE so.sale_order_no IN ('SO-000011', 'SO-000012', 'SO-000013')
            AND so.deleted = false
    LOOP
        v_so_id := rec.sale_order_id;
        v_organization_id := rec.organization_id;
        v_sale_order_no := rec.sale_order_no;
        
        RAISE NOTICE '📋 Procesando Sale Order: % (Quote: %)', v_sale_order_no, rec.quote_id;
        
        -- Procesar cada SaleOrderLine
        FOR v_sale_order_line_id, v_quote_line_id IN 
            SELECT sol.id, sol.quote_line_id
            FROM "SaleOrderLines" sol
            WHERE sol.sale_order_id = v_so_id AND sol.deleted = false
        LOOP
            RAISE NOTICE '   Procesando SaleOrderLine: % (QuoteLine: %)', v_sale_order_line_id, v_quote_line_id;
            
            -- Verificar si ya existe BomInstance
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_sale_order_line_id AND deleted = false
            LIMIT 1;
            
            IF v_bom_instance_id IS NULL THEN
                -- Obtener datos del QuoteLine
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
                
                RAISE NOTICE '   ✅ QuoteLine encontrado: product_type_id = %', v_quote_line_record.product_type_id;
                
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
                    RAISE NOTICE '   ✅ QuoteLineComponents generados';
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
                
                RAISE NOTICE '   ✅ BOMTemplate encontrado: %', v_bom_template_id;
                
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
                        qlc.qty * COALESCE(qlc.unit_cost_exw, 0) as total_cost_exw,
                        COALESCE(
                            public.derive_category_code_from_role(qlc.component_role),
                            'accessory'
                        ) as category_code,
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
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE '   ❌ Error creando BomInstanceLines: %', SQLERRM;
                END;
            ELSE
                RAISE NOTICE '   ✅ BomInstance ya existe: %', v_bom_instance_id;
            END IF;
        END LOOP;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ REGENERACIÓN COMPLETA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Ejecuta QUICK_CHECK_BOM_FIXED.sql para verificar';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error regenerando BOM: %', SQLERRM;
END $$;








