-- ====================================================
-- Fix: generate_bom_for_manufacturing_order(uuid)
-- ====================================================
-- This function generates BOM for a ManufacturingOrder by:
-- 1. Resolving MO → SalesOrder → SalesOrderLines
-- 2. Creating BomInstance per SalesOrderLine if missing
-- 3. Copying QuoteLineComponents into BomInstanceLines
-- 4. Using correct column names: resolved_part_id (not catalog_item_id)
-- 5. Populating organization_id correctly
-- 6. Idempotent: deletes existing BomInstanceLines before insert
-- ====================================================

DROP FUNCTION IF EXISTS public.generate_bom_for_manufacturing_order(uuid);

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo_record RECORD;
    v_sales_order_record RECORD;
    v_sale_order_line_record RECORD;
    v_quote_line_record RECORD;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_organization_id uuid;
    v_copied_count integer;
    v_total_copied integer := 0;
BEGIN
    -- ====================================================
    -- STEP 1: Get ManufacturingOrder and SalesOrder
    -- ====================================================
    
    SELECT 
        mo.id,
        mo.sale_order_id,
        mo.organization_id
    INTO v_mo_record
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    v_organization_id := v_mo_record.organization_id;
    
    -- Get SalesOrder
    SELECT 
        so.id,
        so.sale_order_no,
        so.organization_id
    INTO v_sales_order_record
    FROM "SalesOrders" so
    WHERE so.id = v_mo_record.sale_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder % not found for ManufacturingOrder %', v_mo_record.sale_order_id, p_manufacturing_order_id;
    END IF;
    
    -- Ensure organization_id is set
    IF v_organization_id IS NULL THEN
        v_organization_id := v_sales_order_record.organization_id;
    END IF;
    
    RAISE NOTICE '🔧 Generating BOM for ManufacturingOrder % (SalesOrder: %)', p_manufacturing_order_id, v_sales_order_record.sale_order_no;
    
    -- ====================================================
    -- STEP 2: Process each SalesOrderLine
    -- ====================================================
    
    FOR v_sale_order_line_record IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            sol.organization_id
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sales_order_record.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Get QuoteLine
        SELECT 
            ql.id,
            ql.organization_id
        INTO v_quote_line_record
        FROM "QuoteLines" ql
        WHERE ql.id = v_sale_order_line_record.quote_line_id
        AND ql.deleted = false;
        
        IF NOT FOUND THEN
            RAISE WARNING '⚠️ QuoteLine % not found for SaleOrderLine %', v_sale_order_line_record.quote_line_id, v_sale_order_line_record.sale_order_line_id;
            CONTINUE;
        END IF;
        
        -- Ensure organization_id
        IF v_organization_id IS NULL THEN
            v_organization_id := COALESCE(v_sale_order_line_record.organization_id, v_quote_line_record.organization_id);
        END IF;
        
        -- ====================================================
        -- STEP 3: Create or get BomInstance
        -- ====================================================
        
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Create BomInstance
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
                v_sale_order_line_record.sale_order_line_id,
                v_sale_order_line_record.quote_line_id,
                NULL,
                'locked',
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_sale_order_line_record.sale_order_line_id;
        ELSE
            RAISE NOTICE '✅ BomInstance % already exists for SaleOrderLine %', v_bom_instance_id, v_sale_order_line_record.sale_order_line_id;
        END IF;
        
        -- ====================================================
        -- STEP 4: Delete existing BomInstanceLines (idempotent)
        -- ====================================================
        
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
        -- ====================================================
        -- STEP 5: Copy QuoteLineComponents to BomInstanceLines
        -- ====================================================
        
        v_copied_count := 0;
        
        FOR v_component_record IN
            SELECT
                qlc.id,
                qlc.catalog_item_id,
                qlc.component_role,
                qlc.qty,
                qlc.uom,
                qlc.unit_cost_exw,
                ci.sku,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            ORDER BY qlc.id
        LOOP
            BEGIN
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
                    NULL,
                    v_component_record.catalog_item_id,  -- resolved_part_id = catalog_item_id from QuoteLineComponents
                    v_component_record.sku,              -- resolved_sku from CatalogItems
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_component_record.uom,
                    v_component_record.item_name,
                    v_component_record.unit_cost_exw,
                    v_component_record.qty * COALESCE(v_component_record.unit_cost_exw, 0),
                    'accessory',  -- Default category, can be derived from component_role if needed
                    v_organization_id,
                    now(),
                    now(),
                    false
                );
                
                v_copied_count := v_copied_count + 1;
                v_total_copied := v_total_copied + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '❌ Error copying QuoteLineComponent % to BomInstanceLines: % (SQLSTATE: %)', 
                        v_component_record.id, SQLERRM, SQLSTATE;
            END;
        END LOOP;
        
        IF v_copied_count > 0 THEN
            RAISE NOTICE '✅ Copied % QuoteLineComponents to BomInstanceLines for BomInstance %', v_copied_count, v_bom_instance_id;
        ELSE
            RAISE WARNING '⚠️ No QuoteLineComponents found for QuoteLine %', v_quote_line_record.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ BOM Generation Complete';
    RAISE NOTICE '   ManufacturingOrder: %', p_manufacturing_order_id;
    RAISE NOTICE '   SalesOrder: %', v_sales_order_record.sale_order_no;
    RAISE NOTICE '   Total components copied: %', v_total_copied;
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in generate_bom_for_manufacturing_order: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) IS 
'Generates BOM for a ManufacturingOrder by copying QuoteLineComponents to BomInstanceLines.
Uses correct column names: resolved_part_id (not catalog_item_id).
Idempotent: deletes existing BomInstanceLines before insert.
Returns void.';

-- ====================================================
-- VERIFICATION QUERY
-- ====================================================
-- Run this after calling the function to verify BOM was created

-- Example verification (replace with actual MO ID):
/*
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.id = 'YOUR_MO_ID_HERE'
GROUP BY mo.manufacturing_order_no, so.sale_order_no;
*/






