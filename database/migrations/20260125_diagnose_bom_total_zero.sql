-- ====================================================
-- DIAGNÓSTICO: Por qué bom_total está en 0
-- Date: 2026-01-25
-- Description: Verifica si bom_total = 0 es normal o hay un problema
-- ====================================================

-- 1. Verificar ConfiguredProducts con bom_total = 0
SELECT 
    cp.id,
    cp.roll_msrp_total,
    cp.bom_total,
    cp.roll_plus_bom_total,
    -- Verificar si tiene BOMInstance
    (SELECT COUNT(*) 
     FROM public."BOMInstances" bi 
     WHERE bi.configured_product_id = cp.id 
       AND bi.deleted = false) as bom_instances_count,
    -- Verificar si tiene BOMInstanceLines
    (SELECT COUNT(*) 
     FROM public."BOMInstances" bi
     JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
     WHERE bi.configured_product_id = cp.id 
       AND bi.deleted = false
       AND bil.deleted = false
       AND bil.resolved_part_id IS NOT NULL) as bom_lines_count,
    -- Verificar si los resolved_part_id tienen CatalogItemsMSRP
    (SELECT COUNT(DISTINCT bil.resolved_part_id)
     FROM public."BOMInstances" bi
     JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
     JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = bil.resolved_part_id
     WHERE bi.configured_product_id = cp.id 
       AND bi.deleted = false
       AND bil.deleted = false
       AND bil.resolved_part_id IS NOT NULL
       AND cim.organization_id = cp.organization_id) as bom_lines_with_msrp
FROM public."ConfiguredProducts" cp
WHERE cp.deleted = false
  AND cp.bom_total = 0
LIMIT 10;

-- 2. Verificar un ConfiguredProduct específico con detalle
-- (Reemplaza 'CONFIGURED_PRODUCT_ID' con un ID real de los resultados anteriores)
/*
SELECT 
    cp.id as configured_product_id,
    cp.roll_msrp_total,
    cp.bom_total,
    bi.id as bom_instance_id,
    bil.id as bom_line_id,
    bil.resolved_part_id,
    bil.part_role,
    bil.qty,
    ci.sku as part_sku,
    ci.name as part_name,
    cim.msrp_sale_out,
    cim.total_cost,
    (cim.msrp_sale_out * bil.qty) as line_msrp_total
FROM public."ConfiguredProducts" cp
LEFT JOIN public."BOMInstances" bi ON bi.configured_product_id = cp.id AND bi.deleted = false
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
LEFT JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = bil.resolved_part_id 
    AND cim.organization_id = cp.organization_id
WHERE cp.id = 'CONFIGURED_PRODUCT_ID'
ORDER BY bil.id;
*/

-- 3. Resumen: Cuántos ConfiguredProducts tienen BOM pero bom_total = 0
SELECT 
    COUNT(*) as total_configured_products,
    COUNT(CASE WHEN bom_total = 0 THEN 1 END) as bom_total_zero,
    COUNT(CASE WHEN bom_total > 0 THEN 1 END) as bom_total_positive,
    COUNT(CASE WHEN bom_total = 0 AND EXISTS (
        SELECT 1 
        FROM public."BOMInstances" bi
        JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
        WHERE bi.configured_product_id = cp.id 
          AND bi.deleted = false
          AND bil.deleted = false
          AND bil.resolved_part_id IS NOT NULL
    ) THEN 1 END) as bom_total_zero_but_has_bom_lines
FROM public."ConfiguredProducts" cp
WHERE cp.deleted = false;
