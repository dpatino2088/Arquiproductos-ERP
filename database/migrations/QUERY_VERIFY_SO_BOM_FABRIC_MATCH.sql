-- ====================================================
-- Verification Queries: Compare SO Selection vs BOM Fabric
-- ====================================================
-- These queries verify that the BOM fabric matches the Sales Order selection
-- ====================================================

-- Query 1: Compare QuoteLine collection/variant with resolved fabric SKU in BOM
-- This shows if the fabric in the BOM matches what was selected in the Quote/SO
SELECT 
    ql.id as quote_line_id,
    sol.id as sale_order_line_id,
    bi.id as bom_instance_id,
    ql.collection_name as ql_collection_name,
    ql.variant_name as ql_variant_name,
    ql.collection_id as ql_collection_id,
    ql.variant_id as ql_variant_id,
    -- Fabric from QuoteLineComponents (the actual selection)
    qlc_fabric.catalog_item_id as qlc_fabric_catalog_item_id,
    qlc_fabric_ci.sku as qlc_fabric_sku,
    qlc_fabric_ci.collection_name as qlc_fabric_collection_name,
    qlc_fabric_ci.variant_name as qlc_fabric_variant_name,
    -- Fabric from BOM (what was generated)
    bil.resolved_part_id as bom_fabric_catalog_item_id,
    bil.resolved_sku as bom_fabric_sku,
    bil.source as bom_fabric_source,
    catalog_fabric_ci.collection_name as bom_fabric_collection_name,
    catalog_fabric_ci.variant_name as bom_fabric_variant_name,
    -- Match status
    CASE 
        WHEN qlc_fabric.catalog_item_id IS NOT NULL 
             AND bil.resolved_part_id = qlc_fabric.catalog_item_id THEN 'MATCH'
        WHEN qlc_fabric.catalog_item_id IS NOT NULL 
             AND bil.resolved_part_id != qlc_fabric.catalog_item_id THEN 'MISMATCH'
        WHEN qlc_fabric.catalog_item_id IS NULL 
             AND bil.resolved_part_id IS NOT NULL THEN 'NO_QLC_FABRIC_BOM_HAS_FABRIC'
        WHEN qlc_fabric.catalog_item_id IS NOT NULL 
             AND bil.resolved_part_id IS NULL THEN 'QLC_FABRIC_BOM_NO_FABRIC'
        ELSE 'NO_DATA'
    END as match_status
FROM "QuoteLines" ql
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
LEFT JOIN "QuoteLineComponents" qlc_fabric ON qlc_fabric.quote_line_id = ql.id 
    AND qlc_fabric.component_role = 'fabric' 
    AND qlc_fabric.deleted = false
    AND qlc_fabric.source = 'configured_component'
LEFT JOIN "CatalogItems" qlc_fabric_ci ON qlc_fabric_ci.id = qlc_fabric.catalog_item_id
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.part_role = 'fabric' 
    AND bil.deleted = false
LEFT JOIN "CatalogItems" catalog_fabric_ci ON catalog_fabric_ci.id = bil.resolved_part_id
WHERE ql.deleted = false
ORDER BY bi.created_at DESC
LIMIT 20;

-- Query 2: Check if QuoteLineComponents has fabric but BOM doesn't (or vice versa)
SELECT 
    ql.id as quote_line_id,
    sol.id as sale_order_line_id,
    bi.id as bom_instance_id,
    CASE 
        WHEN qlc_fabric.id IS NOT NULL AND bil.id IS NULL THEN 'QLC_HAS_FABRIC_BOM_MISSING'
        WHEN qlc_fabric.id IS NULL AND bil.id IS NOT NULL THEN 'QLC_NO_FABRIC_BOM_HAS_FABRIC'
        WHEN qlc_fabric.id IS NOT NULL AND bil.id IS NOT NULL THEN 'BOTH_HAVE_FABRIC'
        ELSE 'NEITHER_HAS_FABRIC'
    END as fabric_status,
    qlc_fabric.catalog_item_id as qlc_fabric_id,
    qlc_fabric_ci.sku as qlc_fabric_sku,
    bil.resolved_part_id as bom_fabric_id,
    bil.resolved_sku as bom_fabric_sku
FROM "QuoteLines" ql
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
LEFT JOIN "QuoteLineComponents" qlc_fabric ON qlc_fabric.quote_line_id = ql.id 
    AND qlc_fabric.component_role = 'fabric' 
    AND qlc_fabric.deleted = false
    AND qlc_fabric.source = 'configured_component'
LEFT JOIN "CatalogItems" qlc_fabric_ci ON qlc_fabric_ci.id = qlc_fabric.catalog_item_id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.part_role = 'fabric' 
    AND bil.deleted = false
WHERE ql.deleted = false
ORDER BY bi.created_at DESC
LIMIT 20;

-- Query 3: Verify UOM normalization (should only see m, m2, ea)
SELECT 
    bil.uom,
    public.normalize_uom_to_canonical(bil.uom) as uom_canonical,
    COUNT(*) as line_count,
    STRING_AGG(DISTINCT bil.part_role, ', ' ORDER BY bil.part_role) as roles
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
  AND bi.deleted = false
GROUP BY bil.uom, public.normalize_uom_to_canonical(bil.uom)
ORDER BY line_count DESC;

-- Query 4: Find lines with non-canonical UOM (should be 0 after fix)
SELECT 
    bi.id as bom_instance_id,
    bil.id as bom_line_id,
    bil.resolved_sku,
    bil.part_role,
    bil.uom,
    public.normalize_uom_to_canonical(bil.uom) as uom_canonical,
    CASE 
        WHEN bil.uom != public.normalize_uom_to_canonical(bil.uom) THEN 'NEEDS_NORMALIZATION'
        ELSE 'OK'
    END as status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
  AND bi.deleted = false
  AND bil.uom != public.normalize_uom_to_canonical(bil.uom)
ORDER BY bi.created_at DESC
LIMIT 50;


