-- ====================================================
-- Diagnóstico: Cálculo de Precio en QuoteLines vs BOM
-- ====================================================
-- Compara el precio actual en QuoteLines con el precio que debería tener
-- basándose en los componentes del BOM
-- ====================================================

-- 1. Verificar QuoteLines con BOMTemplate
SELECT 
    ql.id,
    ql.line_number,
    ql.bom_template_id,
    ql.product_type,
    ql.width_m,
    ql.height_m,
    ql.computed_qty,
    ql.unit_price_snapshot as ql_unit_price,
    ql.list_unit_price_snapshot as ql_list_price,
    ql.line_total as ql_line_total,
    ci.sku as catalog_item_sku,
    ci.msrp as catalog_item_msrp,
    ci.cost_exw as catalog_item_cost,
    bt.name as bom_template_name
FROM "QuoteLines" ql
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
LEFT JOIN "BOMTemplates" bt ON bt.id = ql.bom_template_id
WHERE ql.deleted = false
AND ql.bom_template_id IS NOT NULL
ORDER BY ql.created_at DESC
LIMIT 5;

-- 2. Verificar componentes del BOM para un QuoteLine específico
-- (Reemplaza el ID con un QuoteLine real)
SELECT 
    bc.id as component_id,
    bc.component_role,
    bc.component_sub_role,
    bc.selection_mode,
    bc.component_item_id,
    bc.qty_type,
    bc.qty_value,
    ci.sku as resolved_sku,
    ci.msrp as component_msrp,
    ci.cost_exw as component_cost,
    ic.code as category_code
FROM "BOMComponents" bc
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE bc.bom_template_id = (
    SELECT bom_template_id 
    FROM "QuoteLines" 
    WHERE deleted = false 
    AND bom_template_id IS NOT NULL 
    LIMIT 1
)
AND bc.deleted = false
ORDER BY bc.sort_order;

-- 3. Comparar precio actual vs precio que debería tener (suma de componentes)
-- Nota: Esto es una estimación - el precio real se calcula cuando se genera el BOM
SELECT 
    'El precio en QuoteLines solo refleja el CatalogItem principal' as note,
    'El precio debería ser la suma de TODOS los componentes del BOM' as expected,
    'Necesitamos calcular el precio basándose en BOMTemplate antes de guardar QuoteLine' as solution;


