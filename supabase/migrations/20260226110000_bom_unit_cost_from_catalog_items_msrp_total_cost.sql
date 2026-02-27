-- BOM unit cost: use CatalogItemsMSRP.total_cost (cost_exw + shipping + import_tax)
-- with fallback to CatalogItems.cost_exw. MSRP calculation uses total cost as-is when
-- from CatalogItemsMSRP, otherwise applies shipping/import_tax from CostSettings.
-- Full function body in database/migrations/442_fix_generate_bom_autocreate_mo_lines.sql (with same cost logic).

SELECT 1;
