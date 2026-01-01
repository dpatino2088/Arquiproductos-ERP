-- ====================================================
-- Migration 311: Test direct insert of BomInstanceLines
-- ====================================================

-- Try to insert one BomInstanceLine directly to see if there are validation errors
DO $$
DECLARE
    v_mo_id uuid;
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_bom_instance_id uuid;
    v_qlc_record RECORD;
    v_bil_id uuid;
    v_canonical_uom text;
    v_category_code text;
    v_unit_cost_exw numeric(12,4) := 0;
    v_total_cost_exw numeric(12,4) := 0;
    v_insert_count integer := 0;
BEGIN
    RAISE NOTICE '🧪 Testing direct insert of BomInstanceLines...';
    RAISE NOTICE '';
    
    -- Get Manufacturing Order details
    SELECT mo.id, mo.sale_order_id, mo.organization_id
    INTO v_mo_id, v_sale_order_id, v_organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000002'
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder MO-000002 not found';
    END IF;
    
    RAISE NOTICE 'Manufacturing Order ID: %', v_mo_id;
    RAISE NOTICE 'Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Get first BomInstance
    SELECT bi.id INTO v_bom_instance_id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sale_order_id
    AND bi.deleted = false
    AND sol.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No BomInstance found';
    END IF;
    
    RAISE NOTICE 'BomInstance ID: %', v_bom_instance_id;
    RAISE NOTICE '';
    
    -- Try to insert first QuoteLineComponent
    FOR v_qlc_record IN
        SELECT 
            qlc.*,
            ci.sku,
            ci.item_name
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = (
            SELECT quote_line_id FROM "BomInstances" WHERE id = v_bom_instance_id LIMIT 1
        )
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'
        LIMIT 1  -- Only try first one
    LOOP
        RAISE NOTICE 'Attempting to insert:';
        RAISE NOTICE '  - component_role: %', v_qlc_record.component_role;
        RAISE NOTICE '  - catalog_item_id: %', v_qlc_record.catalog_item_id;
        RAISE NOTICE '  - sku: %', COALESCE(v_qlc_record.sku, 'NULL');
        RAISE NOTICE '  - qty: %', v_qlc_record.qty;
        RAISE NOTICE '  - uom: %', v_qlc_record.uom;
        
        -- Determine canonical UOM
        CASE v_qlc_record.uom
            WHEN 'm' THEN v_canonical_uom := 'mts';
            WHEN 'm2' THEN v_canonical_uom := 'm2';
            WHEN 'ea' THEN v_canonical_uom := 'ea';
            WHEN 'pcs' THEN v_canonical_uom := 'ea';
            ELSE v_canonical_uom := COALESCE(v_qlc_record.uom, 'ea');
        END CASE;
        
        RAISE NOTICE '  - canonical_uom: %', v_canonical_uom;
        
        -- Get category code
        v_category_code := CASE 
            WHEN v_qlc_record.component_role IN ('fabric', 'tube', 'bottom_rail_profile', 'side_channel_profile') THEN 'MAT'
            WHEN v_qlc_record.component_role IN ('bracket', 'motor', 'motor_adapter') THEN 'HW'
            ELSE 'GEN'
        END;
        
        RAISE NOTICE '  - category_code: %', v_category_code;
        
        -- Calculate costs
        v_unit_cost_exw := COALESCE(v_qlc_record.unit_cost_exw, 0);
        v_total_cost_exw := v_unit_cost_exw * COALESCE(v_qlc_record.qty, 0);
        
        RAISE NOTICE '  - unit_cost_exw: %', v_unit_cost_exw;
        RAISE NOTICE '  - total_cost_exw: %', v_total_cost_exw;
        RAISE NOTICE '';
        
        -- Try INSERT without ON CONFLICT to see actual error
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
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_organization_id,
                v_bom_instance_id,
                NULL,
                v_qlc_record.catalog_item_id,
                v_qlc_record.sku,
                v_qlc_record.component_role,
                v_qlc_record.qty,
                v_canonical_uom,
                COALESCE(v_qlc_record.item_name, ''),
                v_unit_cost_exw,
                v_total_cost_exw,
                v_category_code,
                false,
                now(),
                now()
            ) RETURNING id INTO v_bil_id;
            
            RAISE NOTICE '✅ SUCCESS! Created BomInstanceLine %', v_bil_id;
            v_insert_count := v_insert_count + 1;
            
            -- Rollback this test insert
            DELETE FROM "BomInstanceLines" WHERE id = v_bil_id;
            RAISE NOTICE '🧹 Rolled back test insert';
            
        EXCEPTION
            WHEN unique_violation THEN
                RAISE WARNING '❌ UNIQUE VIOLATION: A BomInstanceLine with these values already exists';
                RAISE WARNING '   Conflict on: (bom_instance_id, resolved_part_id, part_role, uom)';
            WHEN OTHERS THEN
                RAISE WARNING '❌ ERROR: %', SQLERRM;
                RAISE WARNING '   SQLSTATE: %', SQLSTATE;
        END;
        
        EXIT; -- Only test first one
    END LOOP;
    
    IF v_insert_count = 0 THEN
        RAISE NOTICE '⚠️  No QuoteLineComponents found to test';
    END IF;
    
END $$;


