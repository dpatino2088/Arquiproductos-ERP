-- ============================================================================
-- CORREGIR SALE ORDERS SIN BOM (VERSIÓN SIMPLIFICADA)
-- ============================================================================
-- Este script regenera los BOM para Sale Orders que tienen SaleOrderLines pero no BOM

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
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔄 REGENERANDO BOM PARA SALE ORDERS SIN BOM';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- Obtener Sale Orders sin BOM
    FOR rec IN 
        SELECT DISTINCT
            so.id as sale_order_id,
            so.quote_id,
            so.organization_id
        FROM "SaleOrders" so
        INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
        WHERE so.deleted = false
            AND NOT EXISTS (
                SELECT 1 FROM "BomInstances" bi
                WHERE bi.sale_order_line_id = sol.id AND bi.deleted = false
            )
    LOOP
        v_so_id := rec.sale_order_id;
        v_organization_id := rec.organization_id;
        
        RAISE NOTICE '📋 Procesando Sale Order: % (Quote: %)', rec.sale_order_id, rec.quote_id;
        
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
                -- Obtener datos del QuoteLine
                SELECT * INTO v_quote_line_record
                FROM "QuoteLines"
                WHERE id = v_quote_line_id AND deleted = false;
                
                IF FOUND AND v_quote_line_record.product_type_id IS NOT NULL THEN
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
                            RAISE NOTICE '   ⚠️  Error generando BOM para QuoteLine %: %', v_quote_line_id, SQLERRM;
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
                        RAISE NOTICE '   ✅ BOM generado: % componentes', v_count;
                    ELSE
                        RAISE NOTICE '   ⚠️  No se encontró BOMTemplate para product_type_id = %', v_quote_line_record.product_type_id;
                    END IF;
                ELSE
                    RAISE NOTICE '   ⚠️  QuoteLine % no encontrado o sin product_type_id', v_quote_line_id;
                END IF;
            ELSE
                RAISE NOTICE '   ✅ BomInstance ya existe';
            END IF;
        END LOOP;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ REGENERACIÓN COMPLETA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error regenerando BOM: %', SQLERRM;
END $$;








