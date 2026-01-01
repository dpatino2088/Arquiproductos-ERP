-- ====================================================
-- Migration 352: Create BomInstanceLines Manually
-- ====================================================
-- Creates BomInstanceLines from QuoteLineComponents for the existing BomInstance
-- ====================================================

DO $$
DECLARE
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_organization_id uuid;
    v_qlc RECORD;
    v_validated_uom text;
    v_category_code text;
    v_created_count integer := 0;
    v_existing_count integer := 0;
BEGIN
    -- Get BomInstance for MO-000003
    SELECT bi.id, bi.quote_line_id, bi.organization_id
    INTO v_bom_instance_id, v_quote_line_id, v_organization_id
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND bi.deleted = false
    LIMIT 1;
    
    IF v_bom_instance_id IS NULL THEN
        RAISE NOTICE '❌ No BomInstance found for MO-000003';
        RETURN;
    END IF;
    
    RAISE NOTICE '📦 BomInstance ID: %', v_bom_instance_id;
    RAISE NOTICE '   QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Create BomInstanceLines from QuoteLineComponents
    FOR v_qlc IN
        SELECT 
            qlc.id,
            qlc.catalog_item_id,
            qlc.component_role,
            qlc.qty,
            qlc.uom,
            ci.sku,
            ci.item_name,
            ci.description as catalog_item_description
        FROM "QuoteLineComponents" qlc
        INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'
        ORDER BY qlc.component_role
    LOOP
        -- Check if BomInstanceLine already exists
        IF EXISTS (
            SELECT 1
            FROM "BomInstanceLines" bil
            WHERE bil.bom_instance_id = v_bom_instance_id
            AND bil.resolved_part_id = v_qlc.catalog_item_id
            AND COALESCE(bil.part_role, '') = COALESCE(v_qlc.component_role, '')
            AND bil.deleted = false
        ) THEN
            v_existing_count := v_existing_count + 1;
            CONTINUE;
        END IF;
        
        -- Normalize UOM (m -> mts)
        v_validated_uom := CASE 
            WHEN v_qlc.uom = 'm' THEN 'mts'
            ELSE v_qlc.uom
        END;
        
        -- Calculate category_code from component_role (must match constraint check_bom_instance_lines_category_code_valid)
        v_category_code := CASE 
            WHEN v_qlc.component_role = 'fabric' THEN 'fabric'
            WHEN v_qlc.component_role = 'tube' THEN 'tube'
            WHEN v_qlc.component_role = 'motor' THEN 'motor'
            WHEN v_qlc.component_role = 'bracket' THEN 'bracket'
            WHEN v_qlc.component_role LIKE '%cassette%' THEN 'cassette'
            WHEN v_qlc.component_role LIKE '%side_channel%' THEN 'side_channel'
            WHEN v_qlc.component_role LIKE '%bottom_rail%' OR v_qlc.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
            ELSE 'accessory'  -- Default for motor_adapter, operating_system_drive, bracket_cover, chain, etc.
        END;
        
        -- Create BomInstanceLine
        BEGIN
            INSERT INTO "BomInstanceLines" (
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                description,
                category_code,
                organization_id,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_bom_instance_id,
                v_qlc.catalog_item_id,
                v_qlc.sku,
                v_qlc.component_role,
                v_qlc.qty,
                v_validated_uom,
                COALESCE(v_qlc.catalog_item_description, v_qlc.item_name),
                v_category_code,
                v_organization_id,
                false,
                now(),
                now()
            );
            
            v_created_count := v_created_count + 1;
            RAISE NOTICE '   ✅ Created BomInstanceLine for % (SKU: %)', v_qlc.component_role, v_qlc.sku;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ❌ Error creating BomInstanceLine for % (SKU: %): %', 
                    v_qlc.component_role, v_qlc.sku, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '   Created: %', v_created_count;
    RAISE NOTICE '   Already existed: %', v_existing_count;
    
END $$;

-- Verify
SELECT 
    'VERIFICATION' as check_type,
    COUNT(*) as bom_instance_lines
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND bil.deleted = false;

