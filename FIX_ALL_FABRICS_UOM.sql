-- ====================================================
-- Script: Fix UOM for ALL Fabrics (is_fabric = true)
-- ====================================================
-- Problem: Some fabrics have UOM = 'ea' which is incorrect
-- Solution: Set UOM to 'm' or 'm2' based on fabric_pricing_mode
-- Rule: ALL fabrics must have linear/area UOM, NEVER 'ea'
-- ====================================================

-- Step 1: Identify all fabrics with incorrect UOM
SELECT 
    'Step 1: Fabrics with Incorrect UOM' as check_type,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.uom as current_uom,
    ci.fabric_pricing_mode,
    CASE 
        WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
        WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
        WHEN ci.fabric_pricing_mode IS NULL THEN 'm2' -- Default to m2 if pricing mode is unknown
        ELSE 'm2' -- Default fallback
    END as correct_uom,
    CASE 
        WHEN ci.uom IS NULL OR ci.uom = 'ea' OR ci.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '❌ INCORRECT'
        ELSE '✅ OK'
    END as status
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
AND ci.deleted = false
AND (ci.uom IS NULL OR ci.uom = 'ea' OR ci.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'))
ORDER BY ci.sku;

-- Step 2: Fix UOM in CatalogItems for ALL fabrics
DO $$
DECLARE
    v_updated_count integer;
    v_fabric_count integer;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FIXING UOM FOR ALL FABRICS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Count fabrics that need fixing
    SELECT COUNT(*) INTO v_fabric_count
    FROM "CatalogItems"
    WHERE is_fabric = true
    AND deleted = false
    AND (uom IS NULL OR uom = 'ea' OR uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));
    
    RAISE NOTICE 'Step 2: Fixing UOM in CatalogItems...';
    RAISE NOTICE '  Found % fabrics with incorrect UOM', v_fabric_count;
    RAISE NOTICE '';
    
    -- Update CatalogItems: Set UOM based on fabric_pricing_mode
    UPDATE "CatalogItems" ci
    SET 
        uom = CASE 
                WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
                WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
                ELSE 'm2' -- Default to m2 if pricing mode is also null/unknown
              END,
        updated_at = NOW()
    WHERE 
        ci.is_fabric = true
        AND ci.deleted = false
        AND (ci.uom IS NULL OR ci.uom = 'ea' OR ci.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Updated % CatalogItems with corrected fabric UOM', v_updated_count;
    RAISE NOTICE '';
    
    -- Step 3: Fix UOM in QuoteLineComponents for fabric components
    RAISE NOTICE 'Step 3: Fixing UOM in QuoteLineComponents...';
    
    UPDATE "QuoteLineComponents" qlc
    SET 
        uom = CASE 
                WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
                WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
                ELSE 'm2' -- Default to m2 if pricing mode is also null/unknown
              END,
        updated_at = NOW()
    FROM "CatalogItems" ci
    WHERE 
        qlc.catalog_item_id = ci.id
        AND qlc.component_role LIKE '%fabric%'
        AND qlc.deleted = false
        AND ci.is_fabric = true
        AND (qlc.uom IS NULL OR qlc.uom = 'ea' OR qlc.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Updated % QuoteLineComponents with corrected fabric UOM', v_updated_count;
    RAISE NOTICE '';
    
    -- Step 4: Fix UOM in BomInstanceLines for fabric components
    RAISE NOTICE 'Step 4: Fixing UOM in BomInstanceLines...';
    
    UPDATE "BomInstanceLines" bil
    SET 
        uom = CASE 
                WHEN ci.fabric_pricing_mode = 'per_linear_m' THEN 'm'
                WHEN ci.fabric_pricing_mode = 'per_sqm' THEN 'm2'
                ELSE 'm2' -- Default to m2 if pricing mode is also null/unknown
              END,
        updated_at = NOW()
    FROM "CatalogItems" ci
    WHERE 
        bil.resolved_part_id = ci.id
        AND bil.category_code = 'fabric'
        AND bil.deleted = false
        AND ci.is_fabric = true
        AND (bil.uom IS NULL OR bil.uom = 'ea' OR bil.uom NOT IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Updated % BomInstanceLines with corrected fabric UOM', v_updated_count;
    RAISE NOTICE '';
    
    -- Step 5: Fix UOM in SaleOrderMaterialList (if it's a view, this might not be needed)
    -- But we'll check if there's a table backing it
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FIX COMPLETED';
    RAISE NOTICE '========================================';
END $$;

-- Step 6: Verify all fabrics now have correct UOM
SELECT 
    'Step 6: Verification - All Fabrics UOM' as check_type,
    ci.uom,
    ci.fabric_pricing_mode,
    COUNT(*) as count,
    CASE 
        WHEN ci.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '✅ OK'
        ELSE '❌ STILL INCORRECT'
    END as status,
    CASE 
        WHEN COUNT(*) <= 10 THEN STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku)
        ELSE (SELECT STRING_AGG(sku, ', ' ORDER BY sku) FROM (SELECT DISTINCT ci2.sku FROM "CatalogItems" ci2 WHERE ci2.is_fabric = true AND ci2.deleted = false AND ci2.uom = ci.uom AND ci2.fabric_pricing_mode = ci.fabric_pricing_mode ORDER BY ci2.sku LIMIT 5) sub) || ', ...'
    END as sample_skus
FROM "CatalogItems" ci
WHERE ci.is_fabric = true
AND ci.deleted = false
GROUP BY ci.uom, ci.fabric_pricing_mode
ORDER BY count DESC;

-- Step 7: Check specific fabric mentioned (RF-JA-ARETHA-0300)
SELECT 
    'Step 7: Specific Fabric Check' as check_type,
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
WHERE ci.sku = 'RF-JA-ARETHA-0300'
AND ci.is_fabric = true
AND ci.deleted = false;

-- Step 8: Check QuoteLineComponents for SO-000008 with fabric UOM
SELECT 
    'Step 8: QuoteLineComponents Fabric UOM for SO-000008' as check_type,
    qlc.id,
    qlc.component_role,
    qlc.uom,
    ci.sku,
    ci.fabric_pricing_mode,
    CASE 
        WHEN qlc.uom IN ('m', 'm2', 'mts', 'yd', 'yd2', 'ft', 'ft2', 'sqm', 'area') THEN '✅ OK'
        ELSE '❌ INCORRECT'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.component_role LIKE '%fabric%'
AND qlc.deleted = false
ORDER BY ci.sku;

