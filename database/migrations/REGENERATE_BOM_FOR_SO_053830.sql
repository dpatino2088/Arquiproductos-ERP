-- ====================================================
-- REGENERAR BOM PARA SO-053830
-- ====================================================
-- Script para regenerar BomInstances y BomInstanceLines
-- para un SalesOrder que no tiene BOM congelado
-- ====================================================

DO $$
DECLARE
    v_sale_order_id uuid;
    v_quote_id uuid;
    v_org_id uuid;
    v_sale_order_no text;
    v_quote_line_record RECORD;
    v_sale_order_line_record RECORD;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_total_cost_exw numeric(12,4);
    v_category_code text;
    v_bom_line_id uuid;
    v_existing_bom_instance_id uuid;
    v_created_bom_instances integer := 0;
    v_created_bom_lines integer := 0;
BEGIN
    -- 1. Obtener información del SalesOrder
    SELECT 
        so.id,
        so.quote_id,
        so.organization_id,
        so.sale_order_no
    INTO 
        v_sale_order_id,
        v_quote_id,
        v_org_id,
        v_sale_order_no
    FROM "SalesOrders" so
    WHERE so.sale_order_no = 'SO-053830'
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder SO-053830 no encontrado';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Regenerando BOM para %', v_sale_order_no;
    RAISE NOTICE 'SalesOrder ID: %', v_sale_order_id;
    RAISE NOTICE 'Quote ID: %', v_quote_id;
    RAISE NOTICE 'Organization ID: %', v_org_id;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- 2. Para cada SalesOrderLine, crear BomInstance si no existe
    FOR v_sale_order_line_record IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            sol.product_type_id
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order_id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        RAISE NOTICE 'Procesando SalesOrderLine % (QuoteLine: %)', 
            v_sale_order_line_record.sale_order_line_id,
            v_sale_order_line_record.quote_line_id;
        
        -- Verificar si ya existe BomInstance
        SELECT id INTO v_existing_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_existing_bom_instance_id IS NOT NULL THEN
            RAISE NOTICE '  ⏭️  BomInstance ya existe: %', v_existing_bom_instance_id;
            v_bom_instance_id := v_existing_bom_instance_id;
        ELSE
            -- Crear nuevo BomInstance
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                configured_product_id,
                status,
                created_at,
                updated_at,
                deleted
            ) VALUES (
                v_org_id,
                v_sale_order_line_record.sale_order_line_id,
                v_sale_order_line_record.quote_line_id,
                NULL,
                'locked',
                now(),
                now(),
                false
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  ✅ BomInstance creado: %', v_bom_instance_id;
            v_created_bom_instances := v_created_bom_instances + 1;
        END IF;
        
        -- 3. Poblar BomInstanceLines desde QuoteLineComponents
        -- Solo si hay QuoteLineComponents para este QuoteLine
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.sku,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_sale_order_line_record.quote_line_id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            -- Verificar si ya existe esta línea
            IF EXISTS (
                SELECT 1
                FROM "BomInstanceLines" bil
                WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.resolved_part_id = v_component_record.catalog_item_id
                AND COALESCE(bil.part_role, '') = COALESCE(v_component_record.component_role, '')
                AND bil.deleted = false
            ) THEN
                RAISE NOTICE '    ⏭️  BomInstanceLine ya existe para SKU: %', v_component_record.sku;
                CONTINUE;
            END IF;
            
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw using get_unit_cost_in_uom
            BEGIN
                v_unit_cost_exw := public.get_unit_cost_in_uom(
                    v_component_record.catalog_item_id,
                    v_canonical_uom,
                    v_org_id
                );
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ⚠️  Error obteniendo costo unitario para SKU %: %', 
                        v_component_record.sku, SQLERRM;
                    v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
            END;
            
            -- If unit_cost_exw is NULL or 0, try to use the stored unit_cost_exw from QuoteLineComponents
            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
            END IF;
            
            -- Calculate total_cost_exw
            v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
            
            -- Derive category_code from component_role
            BEGIN
                v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            EXCEPTION
                WHEN OTHERS THEN
                    v_category_code := NULL;
            END;
            
            -- Insert BomInstanceLine
            BEGIN
                INSERT INTO "BomInstanceLines" (
                    organization_id,
                    bom_instance_id,
                    source_template_line_id,
                    resolved_part_id,
                    resolved_sku,
                    part_role,
                    qty,
                    uom,
                    description,
                    unit_cost_exw,
                    total_cost_exw,
                    category_code,
                    created_at,
                    updated_at,
                    deleted
                ) VALUES (
                    v_org_id,
                    v_bom_instance_id,
                    NULL,
                    v_component_record.catalog_item_id,
                    v_component_record.sku,
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_canonical_uom,
                    COALESCE(v_component_record.item_name, 'Component'),
                    v_unit_cost_exw,
                    v_total_cost_exw,
                    v_category_code,
                    now(),
                    now(),
                    false
                )
                ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                WHERE deleted = false
                DO NOTHING
                RETURNING id INTO v_bom_line_id;
                
                IF v_bom_line_id IS NOT NULL THEN
                    RAISE NOTICE '    ✅ BomInstanceLine creado: SKU=% role=% qty=% %', 
                        v_component_record.sku,
                        v_component_record.component_role,
                        v_component_record.qty,
                        v_canonical_uom;
                    v_created_bom_lines := v_created_bom_lines + 1;
                    
                    -- Populate base/pricing fields if function exists
                    BEGIN
                        PERFORM public.populate_bom_line_base_pricing_fields(
                            v_bom_line_id,
                            v_component_record.catalog_item_id,
                            v_component_record.qty,
                            v_component_record.uom,
                            v_component_record.component_role,
                            v_org_id
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            -- Function might not exist, that's okay
                            NULL;
                    END;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ❌ Error creando BomInstanceLine para SKU %: %', 
                        v_component_record.sku, SQLERRM;
            END;
        END LOOP;
        
        -- 4. Apply engineering rules if function exists
        IF v_bom_instance_id IS NOT NULL THEN
            BEGIN
                PERFORM public.apply_engineering_rules_to_bom_instance(v_bom_instance_id);
                RAISE NOTICE '  ✅ Reglas de ingeniería aplicadas a BomInstance %', v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ⚠️  Error aplicando reglas de ingeniería: %', SQLERRM;
            END;
        END IF;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Regeneración completada';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'BomInstances creados: %', v_created_bom_instances;
    RAISE NOTICE 'BomInstanceLines creados: %', v_created_bom_lines;
    RAISE NOTICE '';
END $$;

-- Verificación: Contar BomInstanceLines para SO-053830
SELECT 
    COUNT(DISTINCT bil.id) as total_bom_lines,
    COUNT(DISTINCT bi.id) as total_bom_instances
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-053830'
AND bil.deleted = false
AND bi.deleted = false;

