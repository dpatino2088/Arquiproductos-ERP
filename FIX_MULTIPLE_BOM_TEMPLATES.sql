-- ====================================================
-- Script: Fix Multiple BOMTemplates for Roller Shade
-- ====================================================
-- Problem: Multiple active BOMTemplates for same ProductType
-- Solution: Keep only ONE active template, deactivate others
-- ====================================================

-- Step 1: Identify all active BOMTemplates for Roller Shade ProductType
SELECT 
    'Step 1: All Active BOMTemplates for Roller Shade' as check_type,
    pt.id as product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    bt.deleted,
    bt.created_at,
    COUNT(bc.id) as component_count,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND pt.name ILIKE '%roller%shade%'
AND bt.deleted = false
GROUP BY pt.id, pt.name, bt.id, bt.name, bt.active, bt.deleted, bt.created_at
ORDER BY pt.name, bt.active DESC, bt.created_at DESC;

-- Step 2: FIX - Keep only the most complete template active, deactivate others
DO $$
DECLARE
    v_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    v_best_template_id uuid;
    v_best_template_name text;
    v_best_component_count integer := 0;
    v_template_record record;
    v_deactivated_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Step 2: Fixing multiple active BOMTemplates for Roller Shade...';
    RAISE NOTICE '';
    
    -- Find ProductType "Roller Shade"
    SELECT id INTO v_product_type_id
    FROM "ProductTypes"
    WHERE organization_id = v_organization_id
    AND name ILIKE '%roller%shade%'
    ORDER BY name
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        RAISE WARNING '❌ ProductType "Roller Shade" not found';
        RETURN;
    END IF;
    
    RAISE NOTICE '  ProductType ID: %', v_product_type_id;
    
    -- Find the template with most components
    FOR v_template_record IN
        SELECT 
            bt.id,
            bt.name,
            COUNT(bc.id) as component_count
        FROM "BOMTemplates" bt
        LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
        WHERE bt.product_type_id = v_product_type_id
        AND bt.organization_id = v_organization_id
        AND bt.deleted = false
        AND bt.active = true
        GROUP BY bt.id, bt.name
        ORDER BY component_count DESC, bt.created_at DESC
    LOOP
        IF v_best_template_id IS NULL OR v_template_record.component_count > v_best_component_count THEN
            v_best_template_id := v_template_record.id;
            v_best_template_name := v_template_record.name;
            v_best_component_count := v_template_record.component_count;
        END IF;
    END LOOP;
    
    IF v_best_template_id IS NULL THEN
        RAISE WARNING '❌ No active BOMTemplate found for ProductType: %', v_product_type_id;
        RETURN;
    END IF;
    
    RAISE NOTICE '  ✅ Best template: % (%) with % components', 
        v_best_template_name, 
        v_best_template_id,
        v_best_component_count;
    
    -- Deactivate all other active templates for this ProductType
    UPDATE "BOMTemplates"
    SET active = false,
        updated_at = NOW()
    WHERE product_type_id = v_product_type_id
    AND organization_id = v_organization_id
    AND deleted = false
    AND active = true
    AND id != v_best_template_id;
    
    GET DIAGNOSTICS v_deactivated_count = ROW_COUNT;
    
    IF v_deactivated_count > 0 THEN
        RAISE NOTICE '  ✅ Deactivated % other template(s)', v_deactivated_count;
    ELSE
        RAISE NOTICE '  ℹ️  No other templates to deactivate';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ Fix completed!';
    RAISE NOTICE '   Active template: % (%)', v_best_template_name, v_best_template_id;
    
END $$;

-- Step 3: Fix QuoteLine with NULL product_type_id
DO $$
DECLARE
    v_quote_line_record record;
    v_product_type_id uuid;
    v_updated_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Step 3: Fixing QuoteLines with NULL product_type_id for SO-000008...';
    RAISE NOTICE '';
    
    FOR v_quote_line_record IN
        SELECT 
            ql.id,
            ql.catalog_item_id,
            ql.organization_id
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE so.sale_order_no = 'SO-000008'
        AND ql.product_type_id IS NULL
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
    LOOP
        -- Try to find ProductType from CatalogItemProductTypes
        SELECT cipt.product_type_id INTO v_product_type_id
        FROM "CatalogItemProductTypes" cipt
        WHERE cipt.catalog_item_id = v_quote_line_record.catalog_item_id
        AND cipt.organization_id = v_quote_line_record.organization_id
        AND cipt.is_primary = true
        AND cipt.deleted = false
        LIMIT 1;
        
        IF v_product_type_id IS NULL THEN
            SELECT cipt.product_type_id INTO v_product_type_id
            FROM "CatalogItemProductTypes" cipt
            WHERE cipt.catalog_item_id = v_quote_line_record.catalog_item_id
            AND cipt.organization_id = v_quote_line_record.organization_id
            AND cipt.deleted = false
            LIMIT 1;
        END IF;
        
        IF v_product_type_id IS NOT NULL THEN
            UPDATE "QuoteLines"
            SET product_type_id = v_product_type_id,
                updated_at = NOW()
            WHERE id = v_quote_line_record.id;
            
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '  ✅ Updated QuoteLine % with product_type_id %', 
                v_quote_line_record.id, 
                v_product_type_id;
        ELSE
            RAISE WARNING '  ⚠️  Could not find ProductType for QuoteLine %', v_quote_line_record.id;
        END IF;
    END LOOP;
    
    IF v_updated_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ Fixed % QuoteLine(s)', v_updated_count;
    ELSE
        RAISE NOTICE 'ℹ️  No QuoteLines needed fixing';
    END IF;
END $$;

-- Step 4: Final Verification
SELECT 
    'Step 4: Final Verification' as check_type,
    ql.id as quote_line_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ NO product_type_id'
        WHEN pt.id IS NULL THEN '❌ ProductType NOT FOUND'
        WHEN bt.id IS NULL THEN '❌ NO BOMTemplate'
        WHEN bt.active = false THEN '⚠️ BOMTemplate INACTIVE'
        WHEN bt.deleted = true THEN '⚠️ BOMTemplate DELETED'
        WHEN COUNT(bc.id) = 0 THEN '❌ NO components'
        WHEN COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) = 0 THEN '❌ ONLY fabric'
        ELSE '✅ OK'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id, ql.product_type_id, pt.id, pt.name, bt.id, bt.name, bt.active, bt.deleted
ORDER BY ql.id;

