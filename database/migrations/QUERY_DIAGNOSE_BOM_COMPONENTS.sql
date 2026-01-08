-- ====================================================
-- Query de Diagnóstico: Comparar BOM Template vs BOM Generado
-- ====================================================
-- Verificar qué componentes hay en el BOM Template vs qué se generó
-- ====================================================

-- 1) Ver componentes en el BOM Template activo
-- (Reemplazar con el bom_template_id real)
SELECT 
    bc.id,
    bc.component_role,
    bc.component_sub_role,
    bc.auto_select,
    bc.component_item_id,
    bc.sku_resolution_rule,
    bc.qty_type,
    bc.qty_value,
    bc.hardware_color,
    bc.block_condition,
    ci.sku AS fixed_sku,
    ci.item_name AS fixed_item_name
FROM "BOMComponents" bc
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bc.bom_template_id = (
    SELECT id FROM "BOMTemplates" 
    WHERE active = true 
    AND deleted = false 
    AND product_type_id = (
        SELECT product_type_id FROM "QuoteLines" ql
        JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
        JOIN "SalesOrders" so ON so.id = sol.sale_order_id
        JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
        WHERE mo.id = '695aefee-e794-41f2-b7b7-8000877c8ca7'::uuid
        LIMIT 1
    )
    LIMIT 1
)
AND bc.deleted = false
ORDER BY bc.component_role, bc.component_sub_role;

-- 2) Ver componentes generados en BomInstanceLines
SELECT 
    bil.id,
    bil.part_role,
    bil.resolved_sku,
    bil.description,
    bil.qty,
    bil.uom,
    bil.category_code,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.unit_msrp_sale_out,
    bil.total_msrp_sale_out
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id IN (
    SELECT bi.id 
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.id = '695aefee-e794-41f2-b7b7-8000877c8ca7'::uuid
    AND bi.deleted = false
)
AND bil.deleted = false
ORDER BY bil.part_role;

-- 3) Comparar: Componentes en Template vs Generados
WITH template_components AS (
    SELECT DISTINCT
        bc.component_role,
        bc.auto_select,
        COUNT(*) as count_in_template
    FROM "BOMComponents" bc
    WHERE bc.bom_template_id = (
        SELECT id FROM "BOMTemplates" 
        WHERE active = true 
        AND deleted = false 
        AND product_type_id = (
            SELECT product_type_id FROM "QuoteLines" ql
            JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
            JOIN "SalesOrders" so ON so.id = sol.sale_order_id
            JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
            WHERE mo.id = '695aefee-e794-41f2-b7b7-8000877c8ca7'::uuid
            LIMIT 1
        )
        LIMIT 1
    )
    AND bc.deleted = false
    GROUP BY bc.component_role, bc.auto_select
),
generated_components AS (
    SELECT 
        bil.part_role,
        COUNT(*) as count_generated
    FROM "BomInstanceLines" bil
    WHERE bil.bom_instance_id IN (
        SELECT bi.id 
        FROM "BomInstances" bi
        JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        JOIN "SalesOrders" so ON so.id = sol.sale_order_id
        JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
        WHERE mo.id = '695aefee-e794-41f2-b7b7-8000877c8ca7'::uuid
        AND bi.deleted = false
    )
    AND bil.deleted = false
    GROUP BY bil.part_role
)
SELECT 
    COALESCE(tc.component_role, gc.part_role) AS role,
    tc.count_in_template,
    tc.auto_select,
    gc.count_generated,
    CASE 
        WHEN tc.component_role IS NULL THEN '❌ En Template pero NO generado'
        WHEN gc.part_role IS NULL THEN '✅ Generado pero NO en Template (puede ser de QuoteLineComponents)'
        WHEN tc.count_in_template != gc.count_generated THEN '⚠️ Cantidad diferente'
        ELSE '✅ OK'
    END AS status
FROM template_components tc
FULL OUTER JOIN generated_components gc ON gc.part_role = tc.component_role
ORDER BY status, role;


