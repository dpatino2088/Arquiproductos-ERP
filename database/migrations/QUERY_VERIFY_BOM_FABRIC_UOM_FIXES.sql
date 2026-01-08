-- ====================================================
-- Verification Queries for BOM Fabric and UOM Fixes
-- ====================================================
-- These queries verify that:
-- 1. Fabric in BOM matches SalesOrderLine/QuoteLine selection
-- 2. UOM is normalized to canonical (m, m2, ea)
-- 3. Quantities are converted correctly (ft->m)
-- ====================================================

-- ====================================================
-- Query 1: Verify Fabric Matches SO Selection
-- ====================================================
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    ql.collection_name AS quote_collection,
    ql.variant_name AS quote_variant,
    -- BOM fabric
    bil.resolved_sku AS bom_fabric_sku,
    bil.resolved_part_id AS bom_fabric_catalog_item_id,
    ci_bom.collection_name AS bom_fabric_collection,
    ci_bom.variant_name AS bom_fabric_variant,
    ci_bom.sku AS bom_fabric_sku_full,
    -- Match status
    CASE 
        WHEN ql.collection_name = ci_bom.collection_name OR ql.variant_name = ci_bom.variant_name THEN '✅ MATCH'
        WHEN bil.resolved_part_id IS NULL THEN '⚠️  NO BOM FABRIC'
        WHEN ql.collection_name IS NULL AND ql.variant_name IS NULL THEN '⚠️  NO SELECTION IN QUOTE'
        ELSE '❌ MISMATCH'
    END AS match_status,
    -- BOM instance info
    bi.id AS bom_instance_id,
    COALESCE(bi.generated_at, bi.created_at) AS bom_date
FROM "SalesOrderLines" sol
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.deleted = false 
    AND bil.part_role = 'fabric'
LEFT JOIN "CatalogItems" ci_bom ON ci_bom.id = bil.resolved_part_id AND ci_bom.deleted = false
WHERE sol.deleted = false
ORDER BY bi.created_at DESC, sol.sale_order_id, sol.line_number
LIMIT 20;

-- ====================================================
-- Query 2: Verify UOM Normalization
-- ====================================================
-- Should show ONLY m, m2, ea after normalization
SELECT 
    uom,
    COUNT(*) AS line_count,
    SUM(qty) AS total_qty,
    CASE 
        WHEN uom IN ('m', 'm2', 'ea') THEN '✅ CANONICAL'
        ELSE '❌ NOT NORMALIZED'
    END AS status
FROM "BomInstanceLines"
WHERE deleted = false
GROUP BY uom
ORDER BY line_count DESC;

-- ====================================================
-- Query 3: Check for Non-Canonical UOMs (Should be 0)
-- ====================================================
SELECT 
    bi.id AS bom_instance_id,
    bi.sale_order_line_id,
    bil.id AS bom_line_id,
    bil.part_role,
    bil.uom AS current_uom,
    bil.qty,
    bil.resolved_sku,
    'Should be normalized' AS issue
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE bi.deleted = false
AND bil.uom NOT IN ('m', 'm2', 'ea')
ORDER BY bi.created_at DESC
LIMIT 50;

-- ====================================================
-- Query 4: Verify Quantity Conversions (ft -> m)
-- ====================================================
-- Check if there are any lines that should have been converted
-- (This is a diagnostic query - should return 0 after fix)
SELECT 
    bil.id AS bom_line_id,
    bil.part_role,
    bil.qty AS current_qty,
    bil.uom AS current_uom,
    bc.uom AS template_uom,
    bc.qty_type,
    CASE 
        WHEN bc.uom = 'ft' AND bil.uom = 'm' THEN '✅ CONVERTED (ft->m)'
        WHEN bc.uom IN ('pcs', 'set') AND bil.uom = 'ea' THEN '✅ CONVERTED (pcs/set->ea)'
        WHEN bil.uom = bc.uom THEN '✅ NO CONVERSION NEEDED'
        ELSE '⚠️  CHECK CONVERSION'
    END AS conversion_status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id AND bi.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bi.bom_template_id 
    AND bc.component_role = bil.part_role 
    AND bc.deleted = false
WHERE bil.deleted = false
AND bil.source = 'bom_component'
AND bc.uom IS NOT NULL
ORDER BY bi.created_at DESC
LIMIT 50;

-- ====================================================
-- Query 5: Verify Latest BOM Instance Selection
-- ====================================================
-- Should show only the most recent BOM per SaleOrderLine
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    COUNT(bi.id) AS bom_instance_count,
    ARRAY_AGG(bi.id ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC) AS bom_instance_ids,
    ARRAY_AGG(COALESCE(bi.generated_at, bi.created_at) ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC) AS bom_dates,
    MAX(COALESCE(bi.generated_at, bi.created_at)) AS latest_bom_date,
    CASE 
        WHEN COUNT(bi.id) = 0 THEN '⚠️  NO BOM'
        WHEN COUNT(bi.id) = 1 THEN '✅ SINGLE BOM'
        ELSE '⚠️  MULTIPLE BOMs (should reset before regenerate)'
    END AS status
FROM "SalesOrderLines" sol
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE sol.deleted = false
GROUP BY sol.id, sol.line_number
HAVING COUNT(bi.id) > 1 OR COUNT(bi.id) = 0
ORDER BY sol.sale_order_id, sol.line_number
LIMIT 20;

-- ====================================================
-- Query 6: Fabric Resolution Path Analysis
-- ====================================================
-- Shows which resolution path was used for each fabric
SELECT 
    sol.id AS sale_order_line_id,
    ql.collection_name,
    ql.variant_name,
    -- Check resolution paths
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
     WHERE qlc.quote_line_id = ql.id 
     AND qlc.component_role = 'fabric' 
     AND qlc.deleted = false) AS has_qlc_fabric,
    (SELECT cp.fabric_catalog_item_id FROM "ConfiguredProducts" cp 
     WHERE cp.quote_line_id = ql.id 
     AND cp.deleted = false 
     LIMIT 1) AS configured_product_fabric_id,
    -- Resolved fabric
    bil.resolved_part_id AS bom_fabric_id,
    ci.sku AS bom_fabric_sku,
    -- Resolution path used
    CASE 
        WHEN EXISTS (SELECT 1 FROM "QuoteLineComponents" qlc 
                     WHERE qlc.quote_line_id = ql.id 
                     AND qlc.component_role = 'fabric' 
                     AND qlc.catalog_item_id = bil.resolved_part_id
                     AND qlc.deleted = false) THEN 'QuoteLineComponents'
        WHEN EXISTS (SELECT 1 FROM "ConfiguredProducts" cp 
                     WHERE cp.quote_line_id = ql.id 
                     AND cp.fabric_catalog_item_id = bil.resolved_part_id
                     AND cp.deleted = false) THEN 'ConfiguredProduct'
        WHEN ql.collection_name = ci.collection_name OR ql.variant_name = ci.variant_name THEN 'Collection/Variant Match'
        ELSE 'Auto-Select/Fallback'
    END AS resolution_path
FROM "SalesOrderLines" sol
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.deleted = false 
    AND bil.part_role = 'fabric'
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id AND ci.deleted = false
WHERE sol.deleted = false
ORDER BY bi.created_at DESC
LIMIT 20;


