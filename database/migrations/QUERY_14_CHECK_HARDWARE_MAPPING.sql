-- ====================================================
-- QUERY 14: Check Hardware Role Mapping
-- ====================================================
-- This verifies if the hardware role mapping exists in ComponentRoleMap
-- ====================================================

-- Check if mapping exists
SELECT 
    item_category_code,
    role,
    sub_role,
    active,
    description
FROM "ComponentRoleMap"
WHERE role = 'hardware'
AND active = true;

-- Check if get_item_category_codes_from_role works for hardware
SELECT 
    public.get_item_category_codes_from_role('hardware', NULL) as hardware_category_codes;

-- Check which components use hardware role
SELECT 
    pt.name as product_type_name,
    bc.id as component_id,
    bc.component_role,
    bc.component_sub_role,
    bt.id as template_id
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
WHERE bc.component_role = 'hardware'
AND bc.deleted = false
AND bt.deleted = false
AND bt.active = true
AND pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;

