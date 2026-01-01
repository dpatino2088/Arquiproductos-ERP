-- ====================================================
-- Migration 314: Verification Queries for Complete Component Generation
-- ====================================================
-- Run these queries AFTER executing migration 313 to verify the fix
-- ====================================================

-- ============================================
-- Query 1: Verify QuoteLineComponents have multiple roles
-- ============================================
SELECT 
    '=== Query 1: Component Roles by QuoteLine ===' as section;

SELECT 
    ql.id::text as quote_line_id,
    ql.quote_id::text,
    qlc.component_role,
    COUNT(*) as component_count,
    STRING_AGG(DISTINCT ci.sku, ', ') as skus,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT qlc.uom, ', ') as uoms
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ql.id, ql.quote_id, qlc.component_role
ORDER BY ql.id, qlc.component_role;

-- ============================================
-- Query 2: Summary by QuoteLine (should show multiple roles)
-- ============================================
SELECT 
    '=== Query 2: Summary by QuoteLine ===' as section;

SELECT 
    ql.id::text as quote_line_id,
    COUNT(DISTINCT qlc.component_role) as unique_roles_count,
    COUNT(*) as total_components,
    STRING_AGG(DISTINCT qlc.component_role, ', ' ORDER BY qlc.component_role) as roles_found,
    CASE 
        WHEN COUNT(DISTINCT qlc.component_role) >= 5 THEN '✅ Good (5+ roles)'
        WHEN COUNT(DISTINCT qlc.component_role) >= 3 THEN '⚠️ Partial (3-4 roles)'
        ELSE '❌ Insufficient (<3 roles)'
    END as status
FROM "QuoteLines" ql
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY ql.id
ORDER BY ql.id;

-- ============================================
-- Query 3: Verify manufacturing BOM mirrors QuoteLineComponents
-- ============================================
SELECT 
    '=== Query 3: Manufacturing BOM vs QuoteLineComponents ===' as section;

SELECT 
    bi.quote_line_id::text,
    'QuoteLineComponents' as source,
    qlc.component_role as role,
    COUNT(*) as count
FROM "QuoteLineComponents" qlc
JOIN "BomInstances" bi ON bi.quote_line_id = qlc.quote_line_id
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
AND bi.deleted = false
GROUP BY bi.quote_line_id, qlc.component_role

UNION ALL

SELECT 
    bi.quote_line_id::text,
    'BomInstanceLines' as source,
    bil.part_role as role,
    COUNT(*) as count
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
AND bi.deleted = false
GROUP BY bi.quote_line_id, bil.part_role

ORDER BY quote_line_id, source, role;

-- ============================================
-- Query 4: Verify no part_role NULL in BomInstanceLines
-- ============================================
SELECT 
    '=== Query 4: Check for NULL part_role ===' as section;

SELECT 
    COUNT(*) as null_part_role_count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ No NULL part_role found'
        ELSE '❌ Found NULL part_role - PROBLEM!'
    END as status
FROM "BomInstanceLines" bil
JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
AND bi.deleted = false
AND bil.part_role IS NULL;

-- ============================================
-- Query 5: Expected vs Actual Roles for Roller Shade
-- ============================================
SELECT 
    '=== Query 5: Expected vs Actual Roles (Roller Shade) ===' as section;

WITH expected_roles AS (
    SELECT unnest(ARRAY[
        'fabric',
        'tube',
        'bracket',
        'bottom_rail_profile',
        'bottom_rail_end_cap',
        'motor',
        'motor_adapter',
        'motor_crown',
        'motor_accessory',
        'operating_system_drive',
        'chain',
        'chain_stop',
        'bracket_cover',
        'side_channel_profile',
        'side_channel_end_cap',
        'cassette'
    ]) as role
),
actual_roles AS (
    SELECT DISTINCT qlc.component_role as role
    FROM "QuoteLineComponents" qlc
    JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    WHERE qlc.deleted = false
    AND qlc.source = 'configured_component'
    AND ql.product_type ILIKE '%roller%'
)
SELECT 
    er.role as expected_role,
    CASE 
        WHEN ar.role IS NOT NULL THEN '✅ Found'
        ELSE '❌ Missing'
    END as status
FROM expected_roles er
LEFT JOIN actual_roles ar ON ar.role = er.role
ORDER BY er.role;

-- ============================================
-- Query 6: Test idempotency (re-run should not duplicate)
-- ============================================
SELECT 
    '=== Query 6: Idempotency Check (duplicate components) ===' as section;

SELECT 
    qlc.quote_line_id::text,
    qlc.component_role,
    qlc.catalog_item_id::text,
    COUNT(*) as duplicate_count,
    CASE 
        WHEN COUNT(*) > 1 THEN '❌ Duplicate found!'
        ELSE '✅ No duplicates'
    END as status
FROM "QuoteLineComponents" qlc
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY qlc.quote_line_id, qlc.component_role, qlc.catalog_item_id
HAVING COUNT(*) > 1
ORDER BY qlc.quote_line_id, qlc.component_role;

-- ============================================
-- Query 7: UOM Normalization Check
-- ============================================
SELECT 
    '=== Query 7: UOM Normalization Check ===' as section;

SELECT 
    qlc.component_role,
    qlc.uom,
    COUNT(*) as count,
    CASE 
        WHEN qlc.uom IN ('mts', 'm2', 'ea') THEN '✅ Valid UOM'
        WHEN qlc.uom = 'm' THEN '❌ Should be mts'
        WHEN qlc.uom = 'pcs' THEN '❌ Should be ea'
        ELSE '⚠️ Unknown UOM'
    END as status
FROM "QuoteLineComponents" qlc
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY qlc.component_role, qlc.uom
ORDER BY qlc.component_role, qlc.uom;


