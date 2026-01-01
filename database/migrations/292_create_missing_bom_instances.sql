-- ====================================================
-- Migration 292: Create missing BomInstances for SO-090154
-- ====================================================
-- Creates BomInstances for SalesOrderLines that don't have them
-- ====================================================

-- First, diagnose the situation
SELECT 
    'DIAGNOSIS' as step,
    so.sale_order_no,
    so.id as sale_order_id,
    COUNT(DISTINCT sol.id) as sales_order_lines_count,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT qlc.id) as quote_line_components_count
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = sol.quote_line_id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false
GROUP BY so.sale_order_no, so.id;

-- Create BomInstances for SalesOrderLines that don't have them
DO $$
DECLARE
    v_sale_order_no text := 'SO-090154';
    v_sale_order_id uuid;
    v_sol_record RECORD;
    v_bom_instance_id uuid;
    v_created_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Creating BomInstances for %...', v_sale_order_no;
    RAISE NOTICE '';
    
    -- Get SalesOrder ID
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE sale_order_no = v_sale_order_no
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder % not found', v_sale_order_no;
    END IF;
    
    RAISE NOTICE '✅ Found SalesOrder: %', v_sale_order_id;
    
    -- Create BomInstances for each SalesOrderLine
    FOR v_sol_record IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            sol.organization_id,
            sol.product_type_id
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order_id
        AND sol.deleted = false
        ORDER BY sol.line_number ASC
    LOOP
        -- Check if BomInstance already exists
        IF EXISTS (
            SELECT 1 FROM "BomInstances"
            WHERE sale_order_line_id = v_sol_record.sale_order_line_id
            AND deleted = false
        ) THEN
            RAISE NOTICE '  ⏭️  BomInstance already exists for SalesOrderLine %', v_sol_record.sale_order_line_id;
            CONTINUE;
        END IF;
        
        -- Create BomInstance
        BEGIN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                bom_template_id,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_sol_record.organization_id,
                v_sol_record.sale_order_line_id,
                v_sol_record.quote_line_id,
                NULL, -- bom_template_id can be NULL
                false,
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  ✅ Created BomInstance % for SalesOrderLine %', 
                v_bom_instance_id, v_sol_record.sale_order_line_id;
            v_created_count := v_created_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creating BomInstance for SalesOrderLine %: %', 
                    v_sol_record.sale_order_line_id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Completed: Created % BomInstance(s)', v_created_count;
    
END $$;

-- Verify results
SELECT 
    'VERIFICATION' as step,
    so.sale_order_no,
    so.status,
    COUNT(DISTINCT sol.id) as sales_order_lines_count,
    COUNT(DISTINCT bi.id) as bom_instances_count
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false
GROUP BY so.sale_order_no, so.status;


