-- ====================================================
-- Script: Verify BOM After product_type_id Fix
-- ====================================================
-- This script verifies that BOMTemplate exists and components
-- can be generated after fixing product_type_id
-- ====================================================
-- INSTRUCTIONS: Change '50-000008' to your Sale Order number
-- ====================================================

-- Step 1: Verify ProductType and BOMTemplate
SELECT 
    'BOMTemplate Verification' as check_type,
    ql.id as quote_line_id,
    pt.id as product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ QuoteLine has NO product_type_id'
        WHEN pt.id IS NULL THEN '❌ ProductType NOT FOUND'
        WHEN bt.id IS NULL THEN '❌ NO BOMTemplate found'
        WHEN bt.active = false THEN '⚠️ BOMTemplate INACTIVE'
        WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate has NO components'
        WHEN COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') = COUNT(bc.id) THEN '⚠️ BOMTemplate ONLY has fabric'
        ELSE '✅ BOMTemplate OK - Ready for BOM generation'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id 
    AND pt.deleted = false
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id, pt.id, pt.name, bt.id, bt.name, bt.active, ql.product_type_id;

-- Step 2: Show BOMComponents available in the BOMTemplate
SELECT 
    'BOMComponents in Template' as check_type,
    bc.component_role,
    bc.block_type,
    bc.block_condition,
    bc.component_item_id,
    bc.auto_select,
    bc.applies_color,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom,
    bc.sequence_order
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, bc.sequence_order, bc.component_role;

-- Step 3: Check current QuoteLineComponents (what's already generated)
SELECT 
    'Current QuoteLineComponents' as check_type,
    ql.id as quote_line_id,
    qlc.component_role,
    qlc.source,
    qlc.uom,
    ci.sku,
    ci.item_name,
    qlc.qty
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, qlc.component_role, qlc.source;

-- Step 4: Summary - What needs to be done?
SELECT 
    'Action Required' as check_type,
    ql.id as quote_line_id,
    pt.name as product_type_name,
    COUNT(bc.id) as bom_template_components,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') as generated_components,
    CASE 
        WHEN COUNT(bc.id) = 0 THEN '❌ Create BOMTemplate with components'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') = 0 THEN '⚠️ Regenerate BOM (run generate_configured_bom_for_quote_line)'
        WHEN COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') < COUNT(bc.id) THEN '⚠️ Some components missing - Regenerate BOM'
        ELSE '✅ BOM appears complete'
    END as action_needed
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id AND pt.organization_id = ql.organization_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component' 
    AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id, pt.name;

