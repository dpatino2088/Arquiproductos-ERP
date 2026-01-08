-- ====================================================
-- Query de Diagnóstico: BOM Template Resolution
-- ====================================================
-- Este query ayuda a entender por qué no se puede resolver
-- el bom_template_id para un SalesOrderLine específico
-- ====================================================

-- Reemplaza este UUID con el que está fallando
\set sale_order_line_id '5715f1b2-2817-4cfa-b89f-a8a0b2ac412e'

-- Paso 1: Verificar SalesOrderLine
SELECT 
    'SalesOrderLine' AS step,
    sol.id,
    sol.line_number,
    sol.quote_line_id,
    sol.sale_order_id
FROM "SalesOrderLines" sol
WHERE sol.id = :'sale_order_line_id'::uuid
AND sol.deleted = false;

-- Paso 2: Verificar QuoteLine
SELECT 
    'QuoteLine' AS step,
    ql.id,
    ql.bom_template_id AS quote_line_bom_template_id,
    ql.product_type_id AS quote_line_product_type_id,
    ql.collection_name,
    ql.variant_name
FROM "QuoteLines" ql
WHERE ql.id = (
    SELECT sol.quote_line_id 
    FROM "SalesOrderLines" sol 
    WHERE sol.id = :'sale_order_line_id'::uuid
    LIMIT 1
)
AND ql.deleted = false;

-- Paso 3: Verificar ConfiguredProduct
SELECT 
    'ConfiguredProduct' AS step,
    cp.id,
    cp.quote_line_id,
    cp.product_type_id AS configured_product_type_id,
    -- Verificar si tiene bom_template_id (puede no existir)
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'ConfiguredProducts'
            AND column_name = 'bom_template_id'
        ) THEN 'Column exists'
        ELSE 'Column does not exist'
    END AS bom_template_id_column_status
FROM "ConfiguredProducts" cp
WHERE cp.quote_line_id = (
    SELECT sol.quote_line_id 
    FROM "SalesOrderLines" sol 
    WHERE sol.id = :'sale_order_line_id'::uuid
    LIMIT 1
)
AND cp.deleted = false;

-- Paso 4: Verificar ProductType y BOMTemplates disponibles
SELECT 
    'ProductType & BOMTemplates' AS step,
    pt.id AS product_type_id,
    pt.name AS product_type_name,
    COUNT(bt.id) AS available_templates_count,
    ARRAY_AGG(bt.id) AS template_ids,
    ARRAY_AGG(bt.name) AS template_names
FROM "ProductTypes" pt
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id 
    AND bt.active = true 
    AND bt.deleted = false
WHERE pt.id = (
    SELECT ql.product_type_id 
    FROM "QuoteLines" ql
    WHERE ql.id = (
        SELECT sol.quote_line_id 
        FROM "SalesOrderLines" sol 
        WHERE sol.id = :'sale_order_line_id'::uuid
        LIMIT 1
    )
    LIMIT 1
)
AND pt.deleted = false
GROUP BY pt.id, pt.name;

-- Paso 5: Resumen completo
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    ql.id AS quote_line_id,
    ql.bom_template_id AS quote_line_bom_template_id,
    ql.product_type_id AS quote_line_product_type_id,
    cp.id AS configured_product_id,
    pt.id AS product_type_id,
    pt.name AS product_type_name,
    COUNT(bt.id) AS available_bom_templates,
    CASE 
        WHEN ql.bom_template_id IS NOT NULL THEN '✅ Has bom_template_id in QuoteLine'
        WHEN cp.id IS NOT NULL AND EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'ConfiguredProducts'
            AND column_name = 'bom_template_id'
        ) THEN '⚠️  Check ConfiguredProduct.bom_template_id'
        WHEN COUNT(bt.id) > 0 THEN '⚠️  Has templates but not selected'
        ELSE '❌ No templates available for ProductType'
    END AS resolution_status
FROM "SalesOrderLines" sol
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ConfiguredProducts" cp ON cp.quote_line_id = ql.id AND cp.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = COALESCE(ql.product_type_id, cp.product_type_id) AND pt.deleted = false
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id AND bt.active = true AND bt.deleted = false
WHERE sol.id = :'sale_order_line_id'::uuid
AND sol.deleted = false
GROUP BY sol.id, sol.line_number, ql.id, ql.bom_template_id, ql.product_type_id, cp.id, pt.id, pt.name;


