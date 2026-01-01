-- ====================================================
-- Fix SO Numbering: Start from SO-100
-- AND Generate Missing BOMs for all Manufacturing Orders
-- ====================================================
-- Este script:
-- 1. Actualiza el contador de OrganizationCounters para que los SO comiencen desde SO-000100
-- 2. Genera BOMs faltantes para todos los Manufacturing Orders que no tienen BOMs
-- ====================================================

-- ====================================================
-- PART 1: Fix SO Numbering
-- ====================================================

DO $$
DECLARE
    v_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    v_max_so_num integer;
    v_target_value integer;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'PART 1: Fixing SO Numbering';
    RAISE NOTICE '====================================================';
    
    -- Obtener el número más alto de SO existente para esta organización
    SELECT COALESCE((regexp_match(sale_order_no, 'SO-(\d+)'))[1]::integer, 0) INTO v_max_so_num
    FROM "SalesOrders"
    WHERE organization_id = v_org_id
    AND sale_order_no ~ '^SO-\d+$'
    ORDER BY (regexp_match(sale_order_no, 'SO-(\d+)'))[1]::integer DESC
    LIMIT 1;
    
    -- Si hay SOs existentes y el máximo es >= 100, usar max + 1
    -- Si no hay SOs o el máximo es < 100, usar 99 (para que el siguiente sea 100)
    IF v_max_so_num IS NOT NULL AND v_max_so_num >= 100 THEN
        v_target_value := v_max_so_num;
        RAISE NOTICE '   Found existing SOs. Max number: %, setting counter to %', v_max_so_num, v_target_value;
    ELSE
        v_target_value := 99;
        RAISE NOTICE '   No existing SOs or max < 100. Setting counter to 99 (next will be 100)';
    END IF;
    
    -- Insertar o actualizar el contador usando INSERT ... ON CONFLICT
    -- Esto es más simple y evita el problema con GET DIAGNOSTICS
    INSERT INTO "OrganizationCounters" (
        organization_id,
        key,
        last_value,
        updated_at
    ) VALUES (
        v_org_id,
        'sale_order',
        v_target_value,
        now()
    )
    ON CONFLICT (organization_id, key) DO UPDATE SET
        last_value = v_target_value,
        updated_at = now();
    
    RAISE NOTICE '✅ Counter created/updated for SO starting at %', v_target_value + 1;
END;
$$;

-- Verificar numeración
SELECT 
    'SO Numbering Verification' as check_type,
    organization_id,
    key,
    last_value,
    last_value + 1 as next_number,
    'SO-' || LPAD((last_value + 1)::text, 6, '0') as next_sale_order_no
FROM "OrganizationCounters"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND key = 'sale_order';

-- ====================================================
-- PART 2: Generate Missing BOMs for all Manufacturing Orders
-- ====================================================

DO $$
DECLARE
    r_mo RECORD;
    v_quote_line_record RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_copied_count integer;
    v_total_mos integer := 0;
    v_total_boms integer := 0;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'PART 2: Generating Missing BOMs for Manufacturing Orders';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    FOR r_mo IN
        SELECT 
            mo.id,
            mo.organization_id,
            mo.sale_order_id,
            mo.manufacturing_order_no,
            so.sale_order_no,
            so.quote_id
        FROM "ManufacturingOrders" mo
        INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
        WHERE mo.deleted = false
        AND mo.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
        AND NOT EXISTS (
            SELECT 1 
            FROM "SalesOrderLines" sol
            INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
            WHERE sol.sale_order_id = mo.sale_order_id
            AND sol.deleted = false
        )
        ORDER BY mo.created_at ASC
    LOOP
        BEGIN
            v_total_mos := v_total_mos + 1;
            RAISE NOTICE '📋 Processing Manufacturing Order % (SO: %)...', r_mo.manufacturing_order_no, r_mo.sale_order_no;

            -- Generate BOM for all QuoteLines in this SalesOrder
            FOR v_quote_line_record IN
                SELECT 
                    ql.id as quote_line_id,
                    ql.product_type_id,
                    ql.organization_id,
                    ql.drive_type,
                    ql.bottom_rail_type,
                    COALESCE(ql.cassette, false) as cassette,
                    ql.cassette_type,
                    COALESCE(ql.side_channel, false) as side_channel,
                    ql.side_channel_type,
                    ql.hardware_color,
                    ql.width_m,
                    ql.height_m,
                    ql.qty,
                    sol.id as sale_order_line_id
                FROM "SalesOrderLines" sol
                INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
                WHERE sol.sale_order_id = r_mo.sale_order_id
                    AND sol.deleted = false
                ORDER BY sol.line_number
            LOOP
                IF v_quote_line_record.product_type_id IS NULL THEN
                    RAISE NOTICE '  ⚠️ QuoteLine % has no product_type_id, skipping', v_quote_line_record.quote_line_id;
                    CONTINUE;
                END IF;

                IF v_quote_line_record.organization_id IS NULL THEN
                    UPDATE "QuoteLines"
                    SET organization_id = r_mo.organization_id
                    WHERE id = v_quote_line_record.quote_line_id;
                    v_quote_line_record.organization_id := r_mo.organization_id;
                END IF;

                BEGIN
                    RAISE NOTICE '  🔧 Generating BOM for QuoteLine %...', v_quote_line_record.quote_line_id;
                    
                    -- Generate QuoteLineComponents if they don't exist
                    IF NOT EXISTS (
                        SELECT 1 FROM "QuoteLineComponents"
                        WHERE quote_line_id = v_quote_line_record.quote_line_id
                        AND source = 'configured_component'
                        AND deleted = false
                    ) THEN
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
                        RAISE NOTICE '  ✅ Generated QuoteLineComponents for QuoteLine %', v_quote_line_record.quote_line_id;
                    END IF;
                    
                    -- Find or create BomInstance
                    SELECT id INTO v_bom_instance_id
                    FROM "BomInstances"
                    WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
                    AND deleted = false
                    LIMIT 1;
                    
                    IF NOT FOUND THEN
                        INSERT INTO "BomInstances" (
                            organization_id,
                            sale_order_line_id,
                            quote_line_id,
                            status,
                            created_at,
                            updated_at
                        ) VALUES (
                            r_mo.organization_id,
                            v_quote_line_record.sale_order_line_id,
                            v_quote_line_record.quote_line_id,
                            'locked',
                            now(),
                            now()
                        ) RETURNING id INTO v_bom_instance_id;
                        
                        RAISE NOTICE '  ✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
                    ELSE
                        RAISE NOTICE '  ✅ BomInstance % already exists for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
                    END IF;
                    
                    -- CRITICAL: Copy QuoteLineComponents to BomInstanceLines
                    RAISE NOTICE '  🔧 Copying QuoteLineComponents to BomInstanceLines...';
                    v_copied_count := 0;
                    
                    FOR v_component_record IN
                        SELECT
                            qlc.*,
                            ci.item_name,
                            ci.sku
                        FROM "QuoteLineComponents" qlc
                        INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                        WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
                        AND qlc.source = 'configured_component'
                        AND qlc.deleted = false
                        AND ci.deleted = false
                    LOOP
                        BEGIN
                            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
                            v_unit_cost_exw := public.get_unit_cost_in_uom(
                                v_component_record.catalog_item_id,
                                v_canonical_uom,
                                r_mo.organization_id
                            );
                            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                                v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
                            END IF;
                            v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
                            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
                            
                            INSERT INTO "BomInstanceLines" (
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
                                v_bom_instance_id,
                                NULL,
                                v_component_record.catalog_item_id,
                                v_component_record.sku,
                                v_component_record.component_role,
                                v_component_record.qty,
                                v_canonical_uom,
                                v_component_record.item_name,
                                v_unit_cost_exw,
                                v_total_cost_exw,
                                v_category_code,
                                now(),
                                now(),
                                false
                            ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) DO UPDATE SET
                                qty = EXCLUDED.qty,
                                unit_cost_exw = EXCLUDED.unit_cost_exw,
                                total_cost_exw = EXCLUDED.total_cost_exw,
                                description = EXCLUDED.description,
                                updated_at = now();
                            
                            v_copied_count := v_copied_count + 1;
                        EXCEPTION
                            WHEN OTHERS THEN
                                RAISE WARNING '❌ Error copying QuoteLineComponent % to BomInstanceLines: %', v_component_record.id, SQLERRM;
                        END;
                    END LOOP;
                    
                    RAISE NOTICE '  ✅ Copied % QuoteLineComponents to BomInstanceLines for BomInstance %', v_copied_count, v_bom_instance_id;
                    
                    IF v_copied_count > 0 THEN
                        v_total_boms := v_total_boms + 1;
                    END IF;
                    
                    RAISE NOTICE '  ✅ BOM generated for QuoteLine %', v_quote_line_record.quote_line_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '  ❌ Error generating BOM for QuoteLine %: %', v_quote_line_record.quote_line_id, SQLERRM;
                END;
            END LOOP;

            RAISE NOTICE '✅ Completed BOM generation for Manufacturing Order %', r_mo.manufacturing_order_no;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error processing Manufacturing Order %: %', r_mo.manufacturing_order_no, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Process completed!';
    RAISE NOTICE '   Total Manufacturing Orders processed: %', v_total_mos;
    RAISE NOTICE '   Total BOMs generated: %', v_total_boms;
    RAISE NOTICE '====================================================';
END;
$$;

-- ====================================================
-- PART 3: Verification
-- ====================================================

SELECT 
    'BOM Verification' as check_type,
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    CASE
        WHEN COUNT(DISTINCT bi.id) > 0 THEN '✅ Has BOM'
        ELSE '❌ No BOM'
    END as bom_status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
AND mo.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC
LIMIT 20;

