-- Query to verify where Cost Engine Settings are stored

-- 1. Check CostSettings table (Default settings: shipping, import_tax, labor percentages)
SELECT 
    id,
    organization_id,
    shipping_percentage,
    import_tax_percent,
    labor_percentage,
    currency_code,
    created_at,
    updated_at
FROM "CostSettings"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check ImportTaxRules table (Category-specific import tax rules)
SELECT 
    itr.id,
    itr.organization_id,
    itr.category_id,
    ic.code as category_code,
    ic.name as category_name,
    itr.import_tax_percentage,
    itr.active,
    itr.deleted,
    itr.created_at,
    itr.updated_at
FROM "ImportTaxRules" itr
LEFT JOIN "ItemCategories" ic ON ic.id = itr.category_id
WHERE itr.deleted = false
ORDER BY itr.created_at DESC
LIMIT 20;

-- 3. Check CategoryMargins table (Category-specific margin percentages)
SELECT 
    cm.id,
    cm.organization_id,
    cm.category_id,
    ic.code as category_code,
    ic.name as category_name,
    cm.margin_percentage,
    cm.active,
    cm.deleted,
    cm.created_at,
    cm.updated_at
FROM "CategoryMargins" cm
LEFT JOIN "ItemCategories" ic ON ic.id = cm.category_id
WHERE cm.deleted = false
ORDER BY cm.created_at DESC
LIMIT 20;


