-- ====================================================
-- Fix BOM Lines for SO-025080 / MO-000001
-- ====================================================
-- Script específico para corregir este BOM
-- ====================================================

DO $$
DECLARE
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_organization_id uuid;
    v_component RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer := 0;
    v_result jsonb;
    v_quote_line RECORD;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Fixing BOM for SO-025080 / MO-000001';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Step 1: Get BomInstance
    SELECT 
        bi.id,
        bi.quote_line_id,
        bi.organization_id
    INTO v_bom_instance_id, v_quote_line_id, v_organization_id
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    WHERE so.sale_order_no = 'SO-025080'
    AND bi.deleted = false
    LIMIT 1;

    IF v_bom_instance_id IS NULL THEN
        RAISE EXCEPTION '❌ BomInstance not found for SO-025080';
    END IF;

    RAISE NOTICE '✅ Found BomInstance: %', v_bom_instance_id;
    RAISE NOTICE '   QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;

    -- Step 2: Get QuoteLine details
    SELECT 
        ql.id,
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
        ql.qty
    INTO v_quote_line
    FROM "QuoteLines" ql
    WHERE ql.id = v_quote_line_id
    AND ql.deleted = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION '❌ QuoteLine % not found', v_quote_line_id;
    END IF;

    RAISE NOTICE '✅ Found QuoteLine: %', v_quote_line.id;
    RAISE NOTICE '   Product Type ID: %', v_quote_line.product_type_id;

    -- Step 3: Check if QuoteLineComponents exist
    IF NOT EXISTS (
        SELECT 1 
        FROM "QuoteLineComponents" 
        WHERE quote_line_id = v_quote_line_id
        AND source = 'configured_component'
        AND deleted = false
    ) THEN
        RAISE NOTICE '⚠️ No QuoteLineComponents found. Generating...';
        
        IF v_quote_line.product_type_id IS NULL THEN
            RAISE EXCEPTION '❌ QuoteLine has no product_type_id, cannot generate components';
        END IF;

        BEGIN
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line.id,
                v_quote_line.product_type_id,
                COALESCE(v_quote_line.organization_id, v_organization_id),
                v_quote_line.drive_type,
                v_quote_line.bottom_rail_type,
                v_quote_line.cassette,
                v_quote_line.cassette_type,
                v_quote_line.side_channel,
                v_quote_line.side_channel_type,
                v_quote_line.hardware_color,
                v_quote_line.width_m,
                v_quote_line.height_m,
                v_quote_line.qty
            );
            
            RAISE NOTICE '✅ Generated QuoteLineComponents';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION '❌ Error generating QuoteLineComponents: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '✅ QuoteLineComponents already exist';
    END IF;

    -- Step 4: Copy QuoteLineComponents to BomInstanceLines
    RAISE NOTICE '';
    RAISE NOTICE 'Copying QuoteLineComponents to BomInstanceLines...';

    FOR v_component IN
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
        BEGIN
            RAISE NOTICE '  Processing component: % (SKU: %)', v_component.item_name, v_component.sku;
            
            v_canonical_uom := public.normalize_uom_to_canonical(v_component.uom);
            
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_component.catalog_item_id,
                v_canonical_uom,
                v_organization_id
            );
            
            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                v_unit_cost_exw := COALESCE(v_component.unit_cost_exw, 0);
            END IF;
            
            v_total_cost_exw := v_component.qty * v_unit_cost_exw;
            v_category_code := public.derive_category_code_from_role(v_component.component_role);
            
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
                v_component.catalog_item_id,
                v_component.sku,
                v_component.component_role,
                v_component.qty,
                v_canonical_uom,
                v_component.item_name,
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
            RAISE NOTICE '  ✅ Copied component %', v_copied_count;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error copying component %: % (SQLSTATE: %)', v_component.id, SQLERRM, SQLSTATE;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Process completed!';
    RAISE NOTICE '   Total components copied: %', v_copied_count;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verify
SELECT 
    'Verification' as check_type,
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    CASE
        WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅ Has Lines'
        ELSE '❌ No Lines'
    END as status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no;






