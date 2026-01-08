-- ====================================================
-- Verification Queries for BOM Reset and SO-Driven BOM
-- ====================================================
-- These queries help verify that:
-- 1. BOM template resolution is working correctly
-- 2. Fabric selection matches SO/QuoteLine
-- 3. UOM normalization is applied
-- 4. Latest BOM instances are being selected
-- ====================================================

-- ====================================================
-- Query 0: Test Helper Functions (Quick Test)
-- ====================================================
-- Test resolve_bom_template_id_for_sale_order_line with a real UUID
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    sol.quote_line_id,
    public.resolve_bom_template_id_for_sale_order_line(sol.id) AS resolved_bom_template_id,
    bt.name AS resolved_template_name
FROM "SalesOrderLines" sol
LEFT JOIN "BOMTemplates" bt ON bt.id = public.resolve_bom_template_id_for_sale_order_line(sol.id) AND bt.deleted = false
WHERE sol.deleted = false
LIMIT 5;

-- Test resolve_selected_fabric_catalog_item_id with a real UUID
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    public.resolve_selected_fabric_catalog_item_id(sol.id) AS selected_fabric_catalog_item_id,
    ci.sku AS selected_fabric_sku,
    ci.item_name AS selected_fabric_name
FROM "SalesOrderLines" sol
LEFT JOIN "CatalogItems" ci ON ci.id = public.resolve_selected_fabric_catalog_item_id(sol.id) AND ci.deleted = false
WHERE sol.deleted = false
LIMIT 5;

-- ====================================================
-- Query 1: Validate BOM Template Resolution
-- ====================================================
-- Check that bom_template_id is correctly resolved for each SalesOrderLine
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    sol.quote_line_id,
    ql.bom_template_id AS quote_line_bom_template_id,
    ql.product_type_id AS quote_line_product_type_id,
    pt.name AS product_type_name,
    public.resolve_bom_template_id_for_sale_order_line(sol.id) AS resolved_bom_template_id,
    bt.name AS resolved_template_name,
    bt.active AS template_active
FROM "SalesOrderLines" sol
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id AND pt.deleted = false
LEFT JOIN "BOMTemplates" bt ON bt.id = public.resolve_bom_template_id_for_sale_order_line(sol.id) AND bt.deleted = false
WHERE sol.deleted = false
ORDER BY sol.sale_order_id, sol.line_number
LIMIT 20;

-- ====================================================
-- Query 2: Validate Fabric Selection (SO-Driven)
-- ====================================================
-- Compare selected fabric in SO/QuoteLine vs resolved fabric in BOM
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    ql.collection_name AS quote_line_collection,
    ql.variant_name AS quote_line_variant,
    public.resolve_selected_fabric_catalog_item_id(sol.id) AS selected_fabric_catalog_item_id,
    ci_selected.sku AS selected_fabric_sku,
    ci_selected.item_name AS selected_fabric_name,
    ci_selected.collection_name AS selected_fabric_collection,
    ci_selected.variant_name AS selected_fabric_variant,
    -- BOM fabric (most recent)
    bil_fabric.catalog_item_id AS bom_fabric_catalog_item_id,
    ci_bom.sku AS bom_fabric_sku,
    ci_bom.item_name AS bom_fabric_name,
    ci_bom.collection_name AS bom_fabric_collection,
    ci_bom.variant_name AS bom_fabric_variant,
    -- Match status
    CASE 
        WHEN public.resolve_selected_fabric_catalog_item_id(sol.id) = bil_fabric.catalog_item_id THEN '✅ MATCH'
        WHEN bil_fabric.catalog_item_id IS NULL THEN '⚠️  NO BOM FABRIC'
        WHEN public.resolve_selected_fabric_catalog_item_id(sol.id) IS NULL THEN '⚠️  NO SELECTION'
        ELSE '❌ MISMATCH'
    END AS match_status
FROM "SalesOrderLines" sol
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "CatalogItems" ci_selected ON ci_selected.id = public.resolve_selected_fabric_catalog_item_id(sol.id) AND ci_selected.deleted = false
-- Get most recent BOM fabric for this line
LEFT JOIN LATERAL (
    SELECT bil.catalog_item_id
    FROM "BomInstances" bi
    INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
    WHERE bi.sale_order_line_id = sol.id
    AND bi.deleted = false
    AND bil.part_role = 'fabric'
    ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC
    LIMIT 1
) bil_fabric ON true
LEFT JOIN "CatalogItems" ci_bom ON ci_bom.id = bil_fabric.catalog_item_id AND ci_bom.deleted = false
WHERE sol.deleted = false
ORDER BY sol.sale_order_id, sol.line_number
LIMIT 20;

-- ====================================================
-- Query 3: Validate UOM Normalization
-- ====================================================
-- Check that all BOM lines have canonical UOM (m, m2, ea)
SELECT 
    bi.id AS bom_instance_id,
    bi.sale_order_line_id,
    bil.id AS bom_line_id,
    bil.part_role,
    bil.uom AS uom_raw,
    public.normalize_uom_to_canonical(bil.uom) AS uom_canonical,
    bil.qty,
    ci.sku,
    CASE 
        WHEN bil.uom IN ('m', 'm2', 'ea') THEN '✅ CANONICAL'
        WHEN public.normalize_uom_to_canonical(bil.uom) != bil.uom THEN '⚠️  NEEDS NORMALIZATION'
        ELSE '❌ INVALID'
    END AS uom_status
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.catalog_item_id AND ci.deleted = false
WHERE bi.deleted = false
AND bil.uom NOT IN ('m', 'm2', 'ea')
ORDER BY bi.created_at DESC, bil.part_role
LIMIT 50;

-- ====================================================
-- Query 4: List BOM Instances by Sale Order Line (Latest First)
-- ====================================================
-- Verify that the monitor is selecting the most recent BOM
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    bi.id AS bom_instance_id,
    bi.bom_template_id,
    bt.name AS template_name,
    COALESCE(bi.generated_at, bi.created_at) AS bom_date,
    COUNT(bil.id) AS line_count,
    SUM(bil.qty) AS total_qty,
    bi.total_cost_exw,
    bi.total_msrp_sale_out
FROM "SalesOrderLines" sol
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id AND bt.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE sol.deleted = false
GROUP BY sol.id, sol.line_number, bi.id, bi.bom_template_id, bt.name, bi.generated_at, bi.created_at, bi.total_cost_exw, bi.total_msrp_sale_out
ORDER BY sol.sale_order_id, sol.line_number, COALESCE(bi.generated_at, bi.created_at) DESC;

-- ====================================================
-- Query 5: Check for Duplicate BOM Instances (Should be None After Reset)
-- ====================================================
-- After reset, there should be only one active BOM per SaleOrderLine
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    COUNT(bi.id) AS active_bom_count,
    ARRAY_AGG(bi.id ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC) AS bom_instance_ids,
    ARRAY_AGG(COALESCE(bi.generated_at, bi.created_at) ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC) AS bom_dates
FROM "SalesOrderLines" sol
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE sol.deleted = false
GROUP BY sol.id, sol.line_number
HAVING COUNT(bi.id) > 1
ORDER BY sol.sale_order_id, sol.line_number;

-- ====================================================
-- Query 6: Verify BOM Template Components Have Correct UOM
-- ====================================================
-- Check that BOMComponents have canonical UOM
SELECT 
    bt.id AS bom_template_id,
    bt.name AS template_name,
    bc.id AS component_id,
    bc.component_role,
    bc.auto_select,
    bc.qty_type,
    bc.uom AS component_uom,
    CASE 
        WHEN bc.uom IN ('m', 'm2', 'ea') THEN '✅ CANONICAL'
        WHEN bc.uom IN ('ft', 'pcs', 'set') THEN '⚠️  NEEDS NORMALIZATION'
        ELSE '❌ INVALID'
    END AS uom_status
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.deleted = false
AND bt.active = true
AND bc.uom NOT IN ('m', 'm2', 'ea')
ORDER BY bt.name, bc.component_role
LIMIT 50;

