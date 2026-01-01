-- ====================================================
-- Script: Diagnose and Fix Missing product_type_id in QuoteLines
-- ====================================================
-- This script identifies QuoteLines with NULL product_type_id
-- and attempts to fix them by looking up the ProductType
-- from the catalog_item_id via CatalogItemProductTypes
-- ====================================================

-- Step 1: Diagnose - Find QuoteLines with NULL product_type_id for SO-000008
SELECT 
    'QuoteLines with NULL product_type_id' as check_type,
    ql.id as quote_line_id,
    ql.catalog_item_id,
    ql.product_type_id,
    ci.sku,
    ci.item_name,
    ci.is_fabric,
    ql.drive_type,
    ql.width_m,
    ql.height_m,
    ql.qty
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'  -- Change this to your Sale Order number
AND ql.product_type_id IS NULL
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false;

-- Step 2: Find available ProductTypes for these QuoteLines
SELECT 
    'Available ProductTypes for QuoteLine' as check_type,
    ql.id as quote_line_id,
    ci.sku,
    cipt.product_type_id,
    pt.name as product_type_name,
    cipt.is_primary,
    COUNT(*) OVER (PARTITION BY ql.id) as product_type_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
INNER JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ql.catalog_item_id
    AND cipt.organization_id = ql.organization_id
    AND cipt.deleted = false
INNER JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
    AND pt.organization_id = ql.organization_id
    AND pt.deleted = false
WHERE so.sale_order_no = 'SO-000008'  -- Change this to your Sale Order number
AND ql.product_type_id IS NULL
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, cipt.is_primary DESC, pt.name;

-- Step 3: AUTO-FIX - Update QuoteLines with NULL product_type_id
-- This will use the PRIMARY ProductType (is_primary = true) or the first available ProductType
DO $$
DECLARE
    v_updated_count integer := 0;
    v_quote_line_record record;
    v_product_type_id uuid;
BEGIN
    RAISE NOTICE '🔧 Starting to fix NULL product_type_id in QuoteLines...';
    
    -- Loop through QuoteLines with NULL product_type_id
    FOR v_quote_line_record IN
        SELECT DISTINCT ql.id, ql.catalog_item_id, ql.organization_id
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE so.sale_order_no = 'SO-000008'  -- Change this to your Sale Order number
        AND ql.product_type_id IS NULL
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
    LOOP
        -- Try to find PRIMARY ProductType first
        SELECT cipt.product_type_id INTO v_product_type_id
        FROM "CatalogItemProductTypes" cipt
        WHERE cipt.catalog_item_id = v_quote_line_record.catalog_item_id
        AND cipt.organization_id = v_quote_line_record.organization_id
        AND cipt.is_primary = true
        AND cipt.deleted = false
        LIMIT 1;
        
        -- If no primary, get the first available ProductType
        IF v_product_type_id IS NULL THEN
            SELECT cipt.product_type_id INTO v_product_type_id
            FROM "CatalogItemProductTypes" cipt
            INNER JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
                AND pt.organization_id = v_quote_line_record.organization_id
                AND pt.deleted = false
            WHERE cipt.catalog_item_id = v_quote_line_record.catalog_item_id
            AND cipt.organization_id = v_quote_line_record.organization_id
            AND cipt.deleted = false
            ORDER BY pt.name
            LIMIT 1;
        END IF;
        
        -- Update QuoteLine if ProductType was found
        IF v_product_type_id IS NOT NULL THEN
            UPDATE "QuoteLines"
            SET 
                product_type_id = v_product_type_id,
                updated_at = NOW()
            WHERE id = v_quote_line_record.id;
            
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '  ✅ Updated QuoteLine % with product_type_id %', v_quote_line_record.id, v_product_type_id;
        ELSE
            RAISE WARNING '  ⚠️  Could not find ProductType for QuoteLine % (catalog_item_id: %)', 
                v_quote_line_record.id, v_quote_line_record.catalog_item_id;
        END IF;
        
        -- Reset for next iteration
        v_product_type_id := NULL;
    END LOOP;
    
    RAISE NOTICE '✨ Fix completed. Updated % QuoteLines.', v_updated_count;
END $$;

-- Step 4: Verify the fix
SELECT 
    'Verification After Fix' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.catalog_item_id,
    ci.sku,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ STILL NULL'
        WHEN pt.id IS NULL THEN '⚠️ ProductType NOT FOUND'
        ELSE '✅ FIXED'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id AND pt.organization_id = ql.organization_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'  -- Change this to your Sale Order number
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id;








