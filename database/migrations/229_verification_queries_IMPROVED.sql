-- ====================================================
-- Migration 229: Verification Queries for BOM Configuration (IMPROVED)
-- ====================================================
-- This file contains verification queries that automatically
-- select QuoteLines without requiring manual UUID replacement
-- ====================================================

-- ====================================================
-- HELPER: List Available QuoteLines
-- ====================================================
-- Run this first to see available QuoteLines and their IDs
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.product_type,
    ql.drive_type,
    ql.operating_system_variant,
    ql.tube_type,
    ql.bottom_rail_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty,
    COUNT(qlc.id) as component_count
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
GROUP BY ql.id
ORDER BY ql.created_at DESC
LIMIT 10;

-- ====================================================
-- VERIFICATION 1: Check QuoteLines Configuration Fields
-- ====================================================
-- Shows configuration for the most recent QuoteLine
-- ====================================================

SELECT 
    id,
    product_type,
    drive_type,
    operating_system_variant,
    tube_type,
    bottom_rail_type,
    side_channel,
    side_channel_type,
    hardware_color,
    width_m,
    height_m,
    qty
FROM "QuoteLines" 
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 5;

-- ====================================================
-- VERIFICATION 2: Check QuoteLineComponents Roles
-- ====================================================
-- Shows components for the most recent QuoteLine
-- ====================================================

SELECT 
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom,
    qlc.source
FROM "QuoteLineComponents" qlc
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = (
    SELECT id FROM "QuoteLines" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 1
)
AND qlc.deleted = false
ORDER BY qlc.component_role;

-- ====================================================
-- VERIFICATION 2B: Check QuoteLineComponents for ALL Recent QuoteLines
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.tube_type,
    ql.operating_system_variant,
    qlc.component_role,
    ci.sku,
    qlc.qty,
    qlc.uom
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.created_at > NOW() - INTERVAL '7 days'
ORDER BY ql.created_at DESC, qlc.component_role
LIMIT 50;

-- ====================================================
-- VERIFICATION 3: Check BomInstanceLines Roles
-- ====================================================
-- Shows BOM lines for the most recent QuoteLine with BOM
-- ====================================================

SELECT 
    bil.part_role,
    bil.resolved_sku,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.calc_notes
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.quote_line_id = (
    SELECT id FROM "QuoteLines" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 1
)
AND bil.deleted = false
ORDER BY bil.part_role;

-- ====================================================
-- VERIFICATION 3B: Check BomInstanceLines for ALL Recent QuoteLines
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.tube_type,
    ql.operating_system_variant,
    bil.part_role,
    bil.resolved_sku,
    bil.qty,
    bil.uom,
    bil.cut_length_mm
FROM "QuoteLines" ql
JOIN "BomInstances" bi ON bi.quote_line_id = ql.id
JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE ql.deleted = false
    AND bi.deleted = false
    AND bil.deleted = false
    AND ql.created_at > NOW() - INTERVAL '7 days'
ORDER BY ql.created_at DESC, bil.part_role
LIMIT 50;

-- ====================================================
-- VERIFICATION 4: Check SalesOrderLines Configuration
-- ====================================================
-- Shows SalesOrderLines for recent QuoteLines
-- ====================================================

SELECT 
    sol.id,
    sol.sale_order_id,
    sol.quote_line_id,
    sol.product_type,
    sol.drive_type,
    sol.operating_system_variant,
    sol.tube_type,
    sol.bottom_rail_type,
    sol.side_channel,
    sol.side_channel_type,
    sol.hardware_color,
    sol.width_m,
    sol.height_m
FROM "SalesOrderLines" sol
WHERE sol.quote_line_id IN (
    SELECT id FROM "QuoteLines" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 5
)
AND sol.deleted = false
ORDER BY sol.created_at DESC;

-- ====================================================
-- VERIFICATION 5: Compare Different Configurations
-- ====================================================
-- Compare BOM outputs for different tube_type selections
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.tube_type,
    ql.operating_system_variant,
    qlc.component_role,
    ci.sku,
    qlc.qty,
    qlc.uom
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND qlc.component_role = 'tube'
    AND ql.tube_type IS NOT NULL
ORDER BY ql.tube_type, ql.id
LIMIT 20;

-- ====================================================
-- VERIFICATION 6: Check Side Channel Components
-- ====================================================
-- Ensure side channel roles appear when side_channel=true
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.side_channel,
    ql.side_channel_type,
    qlc.component_role,
    ci.sku,
    qlc.qty
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.component_role IN ('side_channel_profile', 'side_channel_end_cap')
    AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.side_channel = true
    AND ql.deleted = false
ORDER BY ql.id, qlc.component_role;

-- ====================================================
-- VERIFICATION 7: Check Linear UOM Conversion
-- ====================================================
-- Ensure tube and bottom_rail_profile are converted to meters
-- ====================================================

SELECT 
    bil.part_role,
    bil.resolved_sku,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    CASE 
        WHEN bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile') 
            AND bil.uom = 'm' 
            AND bil.cut_length_mm IS NOT NULL 
            AND ABS(bil.qty - (bil.cut_length_mm / 1000.0)) < 0.001
        THEN '✅ CORRECT'
        WHEN bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile') 
            AND bil.uom = 'ea'
        THEN '❌ WRONG: Should be meters'
        WHEN bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile') 
            AND bil.cut_length_mm IS NULL
        THEN '⚠️ WARNING: cut_length_mm is NULL'
        ELSE '✅ OK (not linear)'
    END as validation_status
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.quote_line_id IN (
    SELECT id FROM "QuoteLines" 
    WHERE deleted = false 
    ORDER BY created_at DESC 
    LIMIT 5
)
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile')
ORDER BY bil.part_role, bi.quote_line_id;

-- ====================================================
-- VERIFICATION 8: Check Operating System Variant Resolution
-- ====================================================
-- Compare Standard M vs Standard L SKU resolution
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.operating_system_variant,
    qlc.component_role,
    ci.sku,
    ci.item_name
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND ql.operating_system_variant IS NOT NULL
    AND qlc.component_role IN ('operating_system_drive', 'motor')
ORDER BY ql.operating_system_variant, qlc.component_role
LIMIT 20;

-- ====================================================
-- VERIFICATION 9: Summary Statistics
-- ====================================================
-- Overall health check for BOM generation
-- ====================================================

SELECT 
    COUNT(DISTINCT ql.id) as total_quote_lines,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'tube') as tube_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'bracket') as bracket_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'fabric') as fabric_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'bottom_rail_profile') as bottom_rail_components,
    COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') as side_channel_components,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) as quote_lines_with_tube_type,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) as quote_lines_with_os_variant,
    COUNT(DISTINCT ql.id) FILTER (WHERE ql.side_channel = true) as quote_lines_with_side_channel
FROM "QuoteLines" ql
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE ql.deleted = false
    AND ql.created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- VERIFICATION 10: Check for Resolution Errors
-- ====================================================
-- Find QuoteLineComponents that might have failed resolution
-- ====================================================

SELECT 
    ql.id as quote_line_id,
    ql.tube_type,
    ql.operating_system_variant,
    ql.drive_type,
    qlc.component_role,
    CASE 
        WHEN qlc.catalog_item_id IS NULL THEN '❌ NULL catalog_item_id'
        WHEN ci.id IS NULL THEN '❌ Invalid catalog_item_id'
        ELSE '✅ OK'
    END as resolution_status
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE ql.deleted = false
    AND qlc.deleted = false
    AND (qlc.catalog_item_id IS NULL OR ci.id IS NULL)
ORDER BY ql.id, qlc.component_role;

-- ====================================================
-- VERIFICATION 11: Check Configuration Field Coverage
-- ====================================================
-- Shows which QuoteLines have configuration fields set
-- ====================================================

SELECT 
    COUNT(*) as total_quote_lines,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL) as with_tube_type,
    COUNT(*) FILTER (WHERE operating_system_variant IS NOT NULL) as with_os_variant,
    COUNT(*) FILTER (WHERE tube_type IS NOT NULL AND operating_system_variant IS NOT NULL) as with_both,
    COUNT(*) FILTER (WHERE tube_type IS NULL OR operating_system_variant IS NULL) as missing_config
FROM "QuoteLines"
WHERE deleted = false
    AND created_at > NOW() - INTERVAL '30 days';

-- ====================================================
-- VERIFICATION 12: Check Role Consistency
-- ====================================================
-- Compare component_role in QuoteLineComponents vs part_role in BomInstanceLines
-- ====================================================

SELECT 
    qlc.component_role as quote_component_role,
    bil.part_role as bom_part_role,
    COUNT(*) as count,
    CASE 
        WHEN qlc.component_role = bil.part_role THEN '✅ MATCH'
        ELSE '❌ MISMATCH'
    END as status
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
    AND bil.resolved_part_id = qlc.catalog_item_id
WHERE qlc.deleted = false
    AND bi.deleted = false
    AND bil.deleted = false
GROUP BY qlc.component_role, bil.part_role
ORDER BY count DESC;



