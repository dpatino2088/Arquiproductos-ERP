-- ====================================================
-- Migration 229: Verification Queries for BOM Configuration
-- ====================================================
-- This file contains verification queries to ensure BOM generation
-- is deterministic and correct after implementing configuration fields
-- ====================================================
-- NOTE: For easier use, see 229_verification_queries_IMPROVED.sql
-- which automatically selects QuoteLines without requiring UUID replacement
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
-- Ensure QuoteLines stores configuration fields
-- ====================================================
-- Usage Option A: Replace <QUOTE_LINE_UUID> with actual quote_line_id
-- Usage Option B: Use the improved version below (automatic selection)
-- ====================================================

-- Option A: Specific QuoteLine (requires UUID replacement)
-- SELECT 
--     id,
--     product_type,
--     drive_type,
--     operating_system_variant,
--     tube_type,
--     bottom_rail_type,
--     side_channel,
--     side_channel_type,
--     hardware_color,
--     width_m,
--     height_m,
--     qty
-- FROM "QuoteLines" 
-- WHERE id = '<QUOTE_LINE_UUID>';

-- Option B: Most recent QuoteLines (no UUID needed)
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
-- Ensure QuoteLineComponents contains required roles
-- Expected: tube, bracket, fabric, bottom_rail_profile, bottom_rail_end_cap
-- If side_channel=true => expect side_channel_profile, side_channel_end_cap
-- ====================================================

-- Option A: Specific QuoteLine (requires UUID replacement)
-- SELECT 
--     qlc.component_role,
--     ci.sku,
--     ci.item_name,
--     qlc.qty,
--     qlc.uom,
--     qlc.source
-- FROM "QuoteLineComponents" qlc
-- JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
-- WHERE qlc.quote_line_id = '<QUOTE_LINE_UUID>' 
--     AND qlc.deleted = false
-- ORDER BY qlc.component_role;

-- Option B: Most recent QuoteLine (no UUID needed)
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
-- VERIFICATION 3: Check BomInstanceLines Roles
-- ====================================================
-- Ensure BomInstanceLines inherit those roles
-- ====================================================

-- Option A: Specific QuoteLine (requires UUID replacement)
-- SELECT 
--     bil.part_role,
--     bil.resolved_sku,
--     bil.qty,
--     bil.uom,
--     bil.cut_length_mm,
--     bil.calc_notes
-- FROM "BomInstanceLines" bil
-- JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
-- WHERE bi.quote_line_id = '<QUOTE_LINE_UUID>' 
--     AND bil.deleted = false
-- ORDER BY bil.part_role;

-- Option B: Most recent QuoteLine (no UUID needed)
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
-- VERIFICATION 4: Check SalesOrderLines Configuration
-- ====================================================
-- Ensure SalesOrderLines copied configuration fields
-- ====================================================

-- Option A: Specific QuoteLine (requires UUID replacement)
-- SELECT 
--     sol.id,
--     sol.sale_order_id,
--     sol.quote_line_id,
--     sol.product_type,
--     sol.drive_type,
--     sol.operating_system_variant,
--     sol.tube_type,
--     sol.bottom_rail_type,
--     sol.side_channel,
--     sol.side_channel_type,
--     sol.hardware_color,
--     sol.width_m,
--     sol.height_m
-- FROM "SalesOrderLines" sol
-- WHERE sol.quote_line_id = '<QUOTE_LINE_UUID>'
--     AND sol.deleted = false;

-- Option B: Recent QuoteLines (no UUID needed)
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
-- This proves deterministic SKU resolution
-- ====================================================

-- Example: Compare RTU-42 vs RTU-80 for same quote
-- Option A: Specific Quote (requires UUID replacement)
-- SELECT 
--     ql.id as quote_line_id,
--     ql.tube_type,
--     qlc.component_role,
--     ci.sku,
--     qlc.qty,
--     qlc.uom
-- FROM "QuoteLines" ql
-- JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
-- JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
-- WHERE ql.quote_id = '<QUOTE_UUID>'
--     AND ql.deleted = false
--     AND qlc.deleted = false
--     AND qlc.component_role = 'tube'
-- ORDER BY ql.tube_type, ql.id;

-- Option B: All QuoteLines with tube_type (no UUID needed)
SELECT 
    ql.id as quote_line_id,
    ql.tube_type,
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

-- Option A: Specific QuoteLine (requires UUID replacement)
-- SELECT 
--     bil.part_role,
--     bil.resolved_sku,
--     bil.qty,
--     bil.uom,
--     bil.cut_length_mm,
--     CASE 
--         WHEN bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile') 
--             AND bil.uom = 'm' 
--             AND bil.cut_length_mm IS NOT NULL 
--             AND ABS(bil.qty - (bil.cut_length_mm / 1000.0)) < 0.001
--         THEN '✅ CORRECT'
--         WHEN bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile') 
--             AND bil.uom = 'ea'
--         THEN '❌ WRONG: Should be meters'
--         WHEN bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile') 
--             AND bil.cut_length_mm IS NULL
--         THEN '⚠️ WARNING: cut_length_mm is NULL'
--         ELSE '✅ OK (not linear)'
--     END as validation_status
-- FROM "BomInstanceLines" bil
-- JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
-- WHERE bi.quote_line_id = '<QUOTE_LINE_UUID>'
--     AND bil.deleted = false
--     AND bil.part_role IN ('tube', 'bottom_rail_profile', 'side_channel_profile')
-- ORDER BY bil.part_role;

-- Option B: Recent QuoteLines (no UUID needed)
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

-- Option A: Specific Quote (requires UUID replacement)
-- SELECT 
--     ql.id as quote_line_id,
--     ql.operating_system_variant,
--     qlc.component_role,
--     ci.sku,
--     ci.item_name
-- FROM "QuoteLines" ql
-- JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
-- JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
-- WHERE ql.quote_id = '<QUOTE_UUID>'
--     AND ql.deleted = false
--     AND qlc.deleted = false
--     AND qlc.component_role IN ('operating_system_drive', 'motor')
-- ORDER BY ql.operating_system_variant, qlc.component_role;

-- Option B: All QuoteLines with operating_system_variant (no UUID needed)
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

-- Option A: Specific Quote (requires UUID replacement)
-- SELECT 
--     COUNT(DISTINCT ql.id) as total_quote_lines,
--     COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'tube') as tube_components,
--     COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'bracket') as bracket_components,
--     COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'fabric') as fabric_components,
--     COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'bottom_rail_profile') as bottom_rail_components,
--     COUNT(DISTINCT qlc.id) FILTER (WHERE qlc.component_role = 'side_channel_profile') as side_channel_components,
--     COUNT(DISTINCT ql.id) FILTER (WHERE ql.tube_type IS NOT NULL) as quote_lines_with_tube_type,
--     COUNT(DISTINCT ql.id) FILTER (WHERE ql.operating_system_variant IS NOT NULL) as quote_lines_with_os_variant,
--     COUNT(DISTINCT ql.id) FILTER (WHERE ql.side_channel = true) as quote_lines_with_side_channel
-- FROM "QuoteLines" ql
-- LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
-- WHERE ql.quote_id = '<QUOTE_UUID>'
--     AND ql.deleted = false;

-- Option B: Recent QuoteLines (last 30 days, no UUID needed)
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

-- Option A: Specific Quote (requires UUID replacement)
-- SELECT 
--     ql.id as quote_line_id,
--     ql.tube_type,
--     ql.operating_system_variant,
--     ql.drive_type,
--     qlc.component_role,
--     CASE 
--         WHEN qlc.catalog_item_id IS NULL THEN '❌ NULL catalog_item_id'
--         WHEN ci.id IS NULL THEN '❌ Invalid catalog_item_id'
--         ELSE '✅ OK'
--     END as resolution_status
-- FROM "QuoteLines" ql
-- JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
-- LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
-- WHERE ql.quote_id = '<QUOTE_UUID>'
--     AND ql.deleted = false
--     AND qlc.deleted = false
--     AND (qlc.catalog_item_id IS NULL OR ci.id IS NULL)
-- ORDER BY ql.id, qlc.component_role;

-- Option B: All QuoteLines with resolution errors (no UUID needed)
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

