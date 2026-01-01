-- ====================================================
-- Script: Analyze Tables Issues
-- ====================================================
-- This script analyzes the tables shown in the images
-- to identify specific problems
-- ====================================================

-- Issue 1: BOMTemplates with deleted=TRUE but active=TRUE (contradictory)
SELECT 
    'Issue 1: BOMTemplates with deleted=TRUE but active=TRUE' as issue_type,
    bt.id,
    bt.name,
    bt.product_type_id,
    pt.name as product_type_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) as component_count
FROM "BOMTemplates" bt
LEFT JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'  -- Your organization
AND bt.deleted = true
AND bt.active = true
GROUP BY bt.id, bt.name, bt.product_type_id, pt.name, bt.active, bt.deleted
ORDER BY bt.name;

-- Issue 2: BOMTemplates for Roller Shade ProductType (should be active and not deleted)
SELECT 
    'Issue 2: BOMTemplates for Roller Shade' as issue_type,
    bt.id,
    bt.name,
    pt.name as product_type_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components
FROM "BOMTemplates" bt
INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND pt.name ILIKE '%roller%shade%'
GROUP BY bt.id, bt.name, pt.name, bt.active, bt.deleted
ORDER BY bt.deleted, bt.active DESC, bt.name;

-- Issue 3: BOMComponents with component_item_id = NULL and auto_select = false
SELECT 
    'Issue 3: BOMComponents with NULL item_id and auto_select=false' as issue_type,
    bc.id,
    bc.bom_template_id,
    bt.name as template_name,
    bc.component_role,
    bc.block_type,
    bc.component_item_id,
    bc.auto_select,
    bc.sku_resolution_rule,
    bc.applies_color
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
WHERE bc.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND bc.deleted = false
AND bc.component_item_id IS NULL
AND bc.auto_select = false
ORDER BY bt.name, bc.sequence_order;

-- Issue 4: BOMComponents with auto_select = true but no sku_resolution_rule
SELECT 
    'Issue 4: BOMComponents with auto_select=true but no rule' as issue_type,
    bc.id,
    bc.bom_template_id,
    bt.name as template_name,
    bc.component_role,
    bc.block_type,
    bc.auto_select,
    bc.sku_resolution_rule
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
WHERE bc.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND bc.deleted = false
AND bc.auto_select = true
AND bc.sku_resolution_rule IS NULL
ORDER BY bt.name, bc.sequence_order;

-- Issue 5: Active BOMTemplate for ProductType used in SO-000008
SELECT 
    'Issue 5: Active BOMTemplate for SO-000008 ProductType' as issue_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id, ql.product_type_id, pt.name, bt.id, bt.name, bt.active, bt.deleted;

-- Issue 6: Summary of BOMComponents by template
SELECT 
    'Issue 6: BOMComponents Summary by Template' as issue_type,
    bt.name as template_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_item_id IS NOT NULL) as with_item_id,
    COUNT(bc.id) FILTER (WHERE bc.component_item_id IS NULL AND bc.auto_select = false) as missing_item_id_fixed,
    COUNT(bc.id) FILTER (WHERE bc.component_item_id IS NULL AND bc.auto_select = true) as missing_item_id_auto,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
GROUP BY bt.id, bt.name, bt.active, bt.deleted
ORDER BY bt.deleted, bt.active DESC, bt.name;








