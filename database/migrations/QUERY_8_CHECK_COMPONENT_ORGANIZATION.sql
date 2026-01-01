-- ====================================================
-- QUERY 8: Check Component Organization IDs
-- ====================================================
-- This checks if BOMComponents have organization_id that matches BOMTemplates
-- ====================================================

SELECT 
    pt.name as product_type,
    bt.id as template_id,
    bt.name as template_name,
    bt.organization_id as template_org_id,
    bc.id as component_id,
    bc.organization_id as component_org_id,
    bc.component_item_id,
    CASE 
        WHEN bc.organization_id IS NULL THEN 'COMPONENT_ORG_ID_NULL'
        WHEN bc.organization_id != bt.organization_id THEN 'ORG_ID_MISMATCH'
        ELSE 'OK'
    END as org_id_status
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND (
        bc.organization_id IS NULL
        OR bc.organization_id != bt.organization_id
    )
ORDER BY pt.name, bt.name, bc.sequence_order;

