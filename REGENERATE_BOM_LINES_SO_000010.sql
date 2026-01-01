-- ============================================================================
-- REGENERAR BOM LINES PARA SO-000010
-- ============================================================================
-- Este script regenera los BomInstanceLines para SO-000010
-- basándose en los QuoteLineComponents existentes

DO $$
DECLARE
    v_so_id UUID;
    v_organization_id UUID;
    v_sale_order_line_id UUID;
    v_quote_line_id UUID;
    v_bom_instance_id UUID;
    v_count INT;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔄 REGENERANDO BOM LINES PARA SO-000010';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- 1. Obtener SO-000010
    SELECT id, organization_id INTO v_so_id, v_organization_id
    FROM "SaleOrders"
    WHERE sale_order_no = 'SO-000010' AND deleted = false
    LIMIT 1;
    
    IF v_so_id IS NULL THEN
        RAISE EXCEPTION 'SO-000010 no encontrado';
    END IF;
    
    RAISE NOTICE '✅ SO-000010 encontrado: ID = %', v_so_id;
    RAISE NOTICE '   Organization ID = %', v_organization_id;
    RAISE NOTICE '';
    
    -- 2. Obtener SaleOrderLines y QuoteLines
    FOR rec IN 
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            ql.product_type_id,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty
        FROM "SaleOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
        WHERE sol.sale_order_id = v_so_id AND sol.deleted = false
    LOOP
        v_sale_order_line_id := rec.sale_order_line_id;
        v_quote_line_id := rec.quote_line_id;
        
        RAISE NOTICE '📋 Procesando SaleOrderLine: % (QuoteLine: %)', v_sale_order_line_id, v_quote_line_id;
        
        -- 3. Verificar o crear BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NULL THEN
            -- Crear BomInstance
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                bom_template_id,
                deleted,
                created_at,
                updated_at
            )
            SELECT 
                v_organization_id,
                v_sale_order_line_id,
                v_quote_line_id,
                bt.id,
                false,
                NOW(),
                NOW()
            FROM "BOMTemplates" bt
            WHERE bt.product_type_id = rec.product_type_id
                AND bt.deleted = false
            ORDER BY bt.created_at DESC
            LIMIT 1
            RETURNING id INTO v_bom_instance_id;
            
            IF v_bom_instance_id IS NULL THEN
                RAISE NOTICE '⚠️  WARNING: No se encontró BOMTemplate para product_type_id = %', rec.product_type_id;
                CONTINUE;
            END IF;
            
            RAISE NOTICE '   ✅ BomInstance creado: %', v_bom_instance_id;
        ELSE
            RAISE NOTICE '   ✅ BomInstance existente: %', v_bom_instance_id;
        END IF;
        
        -- 4. Eliminar BomInstanceLines existentes (para regenerar)
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RAISE NOTICE '   🗑️  Eliminados % BomInstanceLines antiguos', v_count;
        
        -- 5. Copiar desde QuoteLineComponents a BomInstanceLines
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
        RAISE NOTICE '   ✅ Insertados % BomInstanceLines nuevos', v_count;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ REGENERACIÓN COMPLETA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Ejecuta VERIFY_SO_000010_COMPLETE.sql para verificar los resultados';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error regenerando BOM: %', SQLERRM;
END $$;








