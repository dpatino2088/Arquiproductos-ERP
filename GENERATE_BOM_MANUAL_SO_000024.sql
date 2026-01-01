-- ====================================================
-- Generar BOM Manualmente para SO-000024
-- ====================================================
-- Este script genera BOM usando los valores del diagnóstico
-- ====================================================

DO $$
DECLARE
    v_sale_order_no text := 'SO-000024';
    v_quote_line_id uuid;
    v_product_type_id uuid;
    v_organization_id uuid;
    v_sale_order_line_id uuid;
    v_drive_type text;
    v_bottom_rail_type text;
    v_cassette boolean;
    v_cassette_type text;
    v_side_channel boolean;
    v_side_channel_type text;
    v_hardware_color text;
    v_width_m numeric;
    v_height_m numeric;
    v_qty numeric;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_bom_lines_count integer;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Generando BOM manualmente para %', v_sale_order_no;
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Obtener los IDs dinámicamente desde SO-000024
    SELECT 
        ql.id,
        ql.product_type_id,
        ql.organization_id,
        sol.id,
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
    INTO 
        v_quote_line_id,
        v_product_type_id,
        v_organization_id,
        v_sale_order_line_id,
        v_drive_type,
        v_bottom_rail_type,
        v_cassette,
        v_cassette_type,
        v_side_channel,
        v_side_channel_type,
        v_hardware_color,
        v_width_m,
        v_height_m,
        v_qty
    FROM "SalesOrders" so
    INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
    WHERE so.sale_order_no = v_sale_order_no
    AND so.deleted = false
    ORDER BY sol.line_number
    LIMIT 1;

    IF v_quote_line_id IS NULL THEN
        RAISE EXCEPTION '❌ No QuoteLine found for %', v_sale_order_no;
    END IF;

    RAISE NOTICE '✅ Found QuoteLine and SaleOrderLine:';
    RAISE NOTICE '   QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '   Product Type ID: %', v_product_type_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '   Sale Order Line ID: %', v_sale_order_line_id;
    RAISE NOTICE '   Width: %m, Height: %m, Qty: %', v_width_m, v_height_m, v_qty;
    RAISE NOTICE '';

    -- Generar BOM
    BEGIN
        RAISE NOTICE '🔧 Calling generate_configured_bom_for_quote_line...';
        
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line_id,                    -- quote_line_id
                v_product_type_id,                  -- product_type_id
                v_organization_id,                  -- organization_id
                v_drive_type,                       -- drive_type
                v_bottom_rail_type,                 -- bottom_rail_type
                COALESCE(v_cassette, false),        -- cassette
                v_cassette_type,                    -- cassette_type
                COALESCE(v_side_channel, false),   -- side_channel
                v_side_channel_type,                -- side_channel_type
                v_hardware_color,                   -- hardware_color
                v_width_m,                          -- width_m
                v_height_m,                         -- height_m
                v_qty                               -- qty
            );
        
        RAISE NOTICE '✅ Function returned: %', v_result;
        RAISE NOTICE '';

        -- Verificar si se creó BomInstance
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND deleted = false
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE NOTICE '🔧 Creating BomInstance for SaleOrderLine %...', v_sale_order_line_id;
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                configured_product_id,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_organization_id,
                v_sale_order_line_id,
                v_quote_line_id,
                NULL, -- configured_product_id can be NULL
                'locked', -- Status: locked because it's for a Sales Order
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '✅ Created BomInstance %', v_bom_instance_id;
        ELSE
            RAISE NOTICE '✅ BomInstance % already exists', v_bom_instance_id;
        END IF;

        -- Step 4: Copy QuoteLineComponents to BomInstanceLines
        RAISE NOTICE '  🔧 Copying QuoteLineComponents to BomInstanceLines...';
        
        -- First, check if QuoteLineComponents exist
        DECLARE
            v_qlc_count integer;
        BEGIN
            SELECT COUNT(*) INTO v_qlc_count
            FROM "QuoteLineComponents" qlc
            WHERE qlc.quote_line_id = v_quote_line_id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false;
            
            RAISE NOTICE '  📊 Found % QuoteLineComponents to copy', v_qlc_count;
            
            IF v_qlc_count = 0 THEN
                RAISE WARNING '  ⚠️ No QuoteLineComponents found! The function generate_configured_bom_for_quote_line may not have created any components.';
            END IF;
        END;
        
        DECLARE
            v_component_record RECORD;
            v_canonical_uom text;
            v_unit_cost_exw numeric;
            v_total_cost_exw numeric;
            v_category_code text;
            v_copied_count integer := 0;
        BEGIN
            FOR v_component_record IN
                SELECT 
                    qlc.*,
                    ci.item_name,
                    ci.sku
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_quote_line_id
                AND qlc.source = 'configured_component'
                AND qlc.deleted = false
                AND ci.deleted = false
            LOOP
                RAISE NOTICE '  🔧 Processing component: % (SKU: %, Role: %)', v_component_record.item_name, v_component_record.sku, v_component_record.component_role;
                -- Compute canonical UOM
                v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
                
                -- Compute unit_cost_exw using get_unit_cost_in_uom
                v_unit_cost_exw := public.get_unit_cost_in_uom(
                    v_component_record.catalog_item_id,
                    v_canonical_uom,
                    v_organization_id
                );
                
                -- If unit_cost_exw is NULL or 0, try to use the stored unit_cost_exw from QuoteLineComponents
                IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                    v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
                END IF;
                
                -- Calculate total_cost_exw
                v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
                
                -- Derive category_code from component_role
                v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
                
                -- Insert BomInstanceLine
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
                    organization_id,
                    created_at,
                    updated_at,
                    deleted
                ) VALUES (
                    v_bom_instance_id,
                    NULL, -- source_template_line_id (optional)
                    v_component_record.catalog_item_id,
                    v_component_record.sku,
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_component_record.uom,
                    COALESCE(v_component_record.item_name, ''),
                    v_unit_cost_exw,
                    v_total_cost_exw,
                    v_category_code,
                    v_organization_id,
                    now(),
                    now(),
                    false
                ) ON CONFLICT DO NOTHING;
                
                v_copied_count := v_copied_count + 1;
                RAISE NOTICE '  ✅ Copied component % to BomInstanceLines', v_component_record.item_name;
            END LOOP;
            
            RAISE NOTICE '  ✅ Total copied: % QuoteLineComponents to BomInstanceLines', v_copied_count;
            
            IF v_copied_count = 0 THEN
                RAISE WARNING '  ⚠️ No components were copied! Check if QuoteLineComponents exist and are not deleted.';
            END IF;
        END;

        -- Verificar BomInstanceLines
        SELECT COUNT(*) INTO v_bom_lines_count
        FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
        RAISE NOTICE '';
        RAISE NOTICE '✅ BomInstanceLines created: %', v_bom_lines_count;
        
        IF v_bom_lines_count = 0 THEN
            RAISE WARNING '⚠️ No BomInstanceLines were created!';
            RAISE WARNING '   Check if QuoteLineComponents exist for this QuoteLine';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION '❌ Error generating BOM: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Proceso completado!';
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar resultados
SELECT 
    'Verificación Final' as paso,
    so.sale_order_no,
    sol.id as sale_order_line_id,
    ql.id as quote_line_id,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    CASE 
        WHEN COUNT(DISTINCT bi.id) > 0 THEN '✅ Has BOM'
        ELSE '❌ No BOM'
    END as bom_status
FROM "SalesOrders" so
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-000024'
AND sol.deleted = false
GROUP BY so.id, so.sale_order_no, sol.id, ql.id
ORDER BY sol.line_number;

