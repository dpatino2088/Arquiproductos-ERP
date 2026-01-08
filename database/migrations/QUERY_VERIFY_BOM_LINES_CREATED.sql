-- ====================================================
-- Query de Verificación: Verificar que BomInstanceLines se crearon
-- ====================================================
-- Ejecutar DESPUÉS de aplicar la migración 405 y generar un BOM
-- ====================================================

-- 1) Verificar conteo de líneas creadas
SELECT
    COUNT(*) AS lines_count,
    COUNT(DISTINCT bom_instance_id) AS instances_count
FROM "BomInstanceLines"
WHERE deleted = false;

-- 2) Verificar líneas por Manufacturing Order específico
-- (Reemplazar el MO ID con el real)
SELECT
    bi.id AS bom_instance_id,
    mo.manufacturing_order_no,
    COUNT(bil.id) AS lines_count,
    SUM(bil.total_cost_exw) AS total_cost,
    SUM(bil.total_msrp_sale_out) AS total_msrp
FROM "BomInstances" bi
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = (
    SELECT sol.sale_order_id 
    FROM "SalesOrderLines" sol 
    WHERE sol.id = bi.sale_order_line_id
)
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE bi.deleted = false
  AND mo.id = '695aefee-e794-41f2-b7b7-8000877c8ca7'::uuid  -- Reemplazar con MO ID real
GROUP BY bi.id, mo.manufacturing_order_no;

-- 3) Verificar que las columnas correctas tienen valores
SELECT
    id,
    resolved_sku,
    part_role,
    qty,
    unit_cost_exw,
    total_cost_exw,
    unit_msrp_sale_out,
    total_msrp_sale_out
FROM "BomInstanceLines"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;


