-- ====================================================
-- Migration 353: Test Creating a Single BomInstanceLine
-- ====================================================
-- Tests creating one BomInstanceLine to see what error occurs
-- ====================================================

DO $$
DECLARE
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_organization_id uuid;
    v_catalog_item_id uuid;
    v_sku text;
    v_item_name text;
    v_component_role text;
    v_qty numeric;
    v_uom text;
    v_category_code text;
    v_description text;
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
        RAISE NOTICE '❌ No BomInstance found';
        RETURN;
    END IF;
    
    RAISE NOTICE '📦 BomInstance ID: %', v_bom_instance_id;
    RAISE NOTICE '   QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Get first QuoteLineComponent
    SELECT 
        qlc.catalog_item_id,
        ci.sku,
        ci.item_name,
        qlc.component_role,
        qlc.qty,
        qlc.uom
    INTO v_catalog_item_id, v_sku, v_item_name, v_component_role, v_qty, v_uom
    FROM "QuoteLineComponents" qlc
    INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
    WHERE qlc.quote_line_id = v_quote_line_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    LIMIT 1;
    
    IF v_catalog_item_id IS NULL THEN
        RAISE NOTICE '❌ No QuoteLineComponents found';
        RETURN;
    END IF;
    
    RAISE NOTICE '📝 First Component:';
    RAISE NOTICE '   Catalog Item ID: %', v_catalog_item_id;
    RAISE NOTICE '   SKU: %', v_sku;
    RAISE NOTICE '   Component Role: %', v_component_role;
    RAISE NOTICE '   Qty: %', v_qty;
    RAISE NOTICE '   UOM: %', v_uom;
    RAISE NOTICE '';
    
    -- Normalize UOM
    v_uom := CASE WHEN v_uom = 'm' THEN 'mts' ELSE v_uom END;
    
    -- Calculate category_code
    v_category_code := CASE 
        WHEN v_component_role IN ('fabric', 'tube', 'bottom_rail_profile', 'side_channel_profile') THEN 'MAT'
        WHEN v_component_role IN ('bracket', 'motor', 'motor_adapter') THEN 'HW'
        ELSE 'GEN'
    END;
    
    v_description := v_item_name;
    
    RAISE NOTICE '🔧 Prepared values:';
    RAISE NOTICE '   UOM: %', v_uom;
    RAISE NOTICE '   Category Code: %', v_category_code;
    RAISE NOTICE '   Description: %', v_description;
    RAISE NOTICE '';
    
    -- Check if already exists
    IF EXISTS (
        SELECT 1 FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND resolved_part_id = v_catalog_item_id
        AND COALESCE(part_role, '') = COALESCE(v_component_role, '')
        AND deleted = false
    ) THEN
        RAISE NOTICE '⚠️  BomInstanceLine already exists for this component';
        RETURN;
    END IF;
    
    -- Try to create
    RAISE NOTICE '🚀 Attempting to create BomInstanceLine...';
    
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
            v_catalog_item_id,
            v_sku,
            v_component_role,
            v_qty,
            v_uom,
            v_description,
            v_category_code,
            v_organization_id,
            false,
            now(),
            now()
        );
        
        RAISE NOTICE '✅ BomInstanceLine created successfully!';
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ ERROR creating BomInstanceLine:';
            RAISE WARNING '   SQLSTATE: %', SQLSTATE;
            RAISE WARNING '   SQLERRM: %', SQLERRM;
            RAISE WARNING '   DETAIL: %', SQLERRM;
    END;
    
END $$;


