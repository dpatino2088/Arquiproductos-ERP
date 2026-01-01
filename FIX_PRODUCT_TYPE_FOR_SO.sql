-- ====================================================
-- Script: Fix Missing product_type_id for Sale Order
-- ====================================================
-- This script fixes QuoteLines with NULL product_type_id
-- by looking up the ProductType from CatalogItemProductTypes
-- ====================================================
-- INSTRUCTIONS: Change 'SO-000008' to your Sale Order number
-- ====================================================

DO $$
DECLARE
    v_sale_order_no text := 'SO-000008';
    v_updated_count integer := 0;
    v_quote_line_record record;
    v_product_type_id uuid;
    v_product_type_name text;
BEGIN
    RAISE NOTICE '🔧 Fixing NULL product_type_id for Sale Order: %', v_sale_order_no;
    RAISE NOTICE '';
    
    -- Step 1: Find and fix QuoteLines with NULL product_type_id
    FOR v_quote_line_record IN
        SELECT DISTINCT 
            ql.id as quote_line_id,
            ql.catalog_item_id,
            ql.organization_id,
            ci.sku
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
        WHERE so.sale_order_no = v_sale_order_no
        AND ql.product_type_id IS NULL
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
    LOOP
        -- Try to find PRIMARY ProductType first
        SELECT cipt.product_type_id, pt.name
        INTO v_product_type_id, v_product_type_name
        FROM "CatalogItemProductTypes" cipt
        INNER JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
            AND pt.organization_id = v_quote_line_record.organization_id
            AND pt.deleted = false
        WHERE cipt.catalog_item_id = v_quote_line_record.catalog_item_id
        AND cipt.organization_id = v_quote_line_record.organization_id
        AND cipt.is_primary = true
        AND cipt.deleted = false
        LIMIT 1;
        
        -- If no primary, get the first available ProductType
        IF v_product_type_id IS NULL THEN
            SELECT cipt.product_type_id, pt.name
            INTO v_product_type_id, v_product_type_name
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
            WHERE id = v_quote_line_record.quote_line_id;
            
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '  ✅ QuoteLine % (SKU: %) → ProductType: % (%)', 
                v_quote_line_record.quote_line_id, 
                COALESCE(v_quote_line_record.sku, 'N/A'),
                v_product_type_id,
                v_product_type_name;
        ELSE
            RAISE WARNING '  ⚠️  QuoteLine % (SKU: %) → No ProductType found in CatalogItemProductTypes', 
                v_quote_line_record.quote_line_id,
                COALESCE(v_quote_line_record.sku, 'N/A');
        END IF;
        
        -- Reset for next iteration
        v_product_type_id := NULL;
        v_product_type_name := NULL;
    END LOOP;
    
    RAISE NOTICE '';
    IF v_updated_count > 0 THEN
        RAISE NOTICE '✨ Fix completed. Updated % QuoteLine(s).', v_updated_count;
    ELSE
        RAISE NOTICE 'ℹ️  No QuoteLines needed updating (all have product_type_id or no matching ProductTypes found).';
    END IF;
END $$;

-- Verification: Show QuoteLines after fix
SELECT 
    'Verification After Fix' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.catalog_item_id,
    ci.sku,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.side_channel,
    ql.hardware_color,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ STILL NULL'
        WHEN pt.id IS NULL THEN '⚠️ ProductType NOT FOUND'
        ELSE '✅ FIXED'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id 
    AND pt.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id;

