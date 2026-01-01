-- ====================================================
-- Migration 356: Actually Insert One BomInstanceLine
-- ====================================================
-- Tries to insert ONE BomInstanceLine and returns the result/error
-- ====================================================

DO $$
DECLARE
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_organization_id uuid;
    v_result text;
    v_error text;
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
        RAISE EXCEPTION 'No BomInstance found for MO-000003';
    END IF;
    
    -- Try to insert ONE BomInstanceLine using the first QuoteLineComponent
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
        )
        SELECT 
            v_bom_instance_id,
            qlc.catalog_item_id,
            ci.sku,
            qlc.component_role,
            qlc.qty,
            CASE WHEN qlc.uom = 'm' THEN 'mts' ELSE qlc.uom END,
            COALESCE(ci.description, ci.item_name),
            CASE 
                WHEN qlc.component_role = 'fabric' THEN 'fabric'
                WHEN qlc.component_role = 'tube' THEN 'tube'
                WHEN qlc.component_role = 'motor' THEN 'motor'
                WHEN qlc.component_role = 'bracket' THEN 'bracket'
                WHEN qlc.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN qlc.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN qlc.component_role LIKE '%bottom_rail%' OR qlc.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
                ELSE 'accessory'
            END,
            v_organization_id,
            false,
            now(),
            now()
        FROM "QuoteLineComponents" qlc
        INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component'
        AND NOT EXISTS (
            SELECT 1 FROM "BomInstanceLines" bil
            WHERE bil.bom_instance_id = v_bom_instance_id
            AND bil.resolved_part_id = qlc.catalog_item_id
            AND COALESCE(bil.part_role, '') = COALESCE(qlc.component_role, '')
            AND bil.deleted = false
        )
        ORDER BY qlc.component_role
        LIMIT 1
        RETURNING id INTO v_result;
        
        RAISE NOTICE 'SUCCESS: Inserted BomInstanceLine with ID: %', v_result;
        
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
            RAISE EXCEPTION 'ERROR: %', v_error;
    END;
    
END $$;

