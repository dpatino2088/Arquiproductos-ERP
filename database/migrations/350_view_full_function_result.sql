-- ====================================================
-- Migration 350: View Full Function Result
-- ====================================================
-- Shows the complete JSON result from the function
-- ====================================================

SELECT 
    public.generate_bom_for_manufacturing_order(
        (SELECT id FROM "ManufacturingOrders" WHERE manufacturing_order_no = 'MO-000003' AND deleted = false LIMIT 1)
    )::text as function_result_json;

-- Also show current state
SELECT 
    'CURRENT_STATE' as check_type,
    mo.manufacturing_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_instance_lines
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no;


