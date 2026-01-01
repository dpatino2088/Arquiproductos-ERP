-- ====================================================
-- Script: Fix Fabric UOM "ea" - Final Fix
-- ====================================================
-- Fix ALL fabrics that have UOM = 'ea' to 'm' or 'm2'
-- ====================================================

-- Step 1: Find all fabrics with UOM = 'ea'
SELECT 
    'Step 1: Fabrics with UOM = ea' as check_type,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.uom as current_uom,
    ci.fabric_pricing_mode,
    CASE 
        WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
        WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
        ELSE 'm2'
    END as correct_uom
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
AND ci.deleted = false
AND ci.uom = 'ea'
ORDER BY ci.sku;

-- Step 2: Fix CatalogItems
UPDATE "CatalogItems" ci
SET 
    uom = CASE 
            WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
            WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
            ELSE 'm2'
          END,
    updated_at = NOW()
WHERE 
    ci.is_fabric = true
    AND ci.deleted = false
    AND ci.uom = 'ea';

-- Step 3: Fix QuoteLineComponents
UPDATE "QuoteLineComponents" qlc
SET 
    uom = CASE 
            WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
            WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
            ELSE 'm2'
          END,
    updated_at = NOW()
FROM "CatalogItems" ci
WHERE 
    qlc.catalog_item_id = ci.id
    AND qlc.component_role LIKE '%fabric%'
    AND qlc.deleted = false
    AND ci.is_fabric = true
    AND qlc.uom = 'ea';

-- Step 4: Fix BomInstanceLines
UPDATE "BomInstanceLines" bil
SET 
    uom = CASE 
            WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
            WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
            ELSE 'm2'
          END,
    updated_at = NOW()
FROM "CatalogItems" ci
WHERE 
    bil.resolved_part_id = ci.id
    AND bil.category_code = 'fabric'
    AND bil.deleted = false
    AND ci.is_fabric = true
    AND bil.uom = 'ea';

-- Step 5: Verify fix
SELECT 
    'Step 5: Verification - All Fabrics UOM' as check_type,
    ci.uom,
    COUNT(*) as count,
    CASE 
        WHEN ci.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '✅ OK'
        WHEN ci.uom = 'ea' THEN '❌ STILL INCORRECT (ea)'
        ELSE '⚠️ UNEXPECTED'
    END as status
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
AND ci.deleted = false
GROUP BY ci.uom
ORDER BY count DESC;

-- Step 6: Check specific fabric from UI (RF-BALI-0100)
SELECT 
    'Step 6: Specific Fabric Check' as check_type,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.uom,
    ci.fabric_pricing_mode,
    CASE 
        WHEN ci.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '✅ OK'
        ELSE '❌ INCORRECT'
    END as status
FROM "CatalogItems" ci
WHERE ci.sku = 'RF-BALI-0100'
AND ci.is_fabric = true
AND ci.deleted = false;








