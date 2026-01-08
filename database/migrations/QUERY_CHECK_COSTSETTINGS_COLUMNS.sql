-- Query to check which columns exist in CostSettings table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'CostSettings'
AND column_name IN ('shipping_percentage', 'labor_percentage', 'import_tax_percent', 'shipping_base_cost', 'shipping_cost_per_kg')
ORDER BY column_name;


