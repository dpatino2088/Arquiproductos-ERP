-- ====================================================
-- Script: Fix BOMTemplate for Roller Shade ProductType
-- ====================================================
-- Based on the CSV analysis, we have 3 active templates:
-- - BOTTOM_RAIL_ONLY (4 components)
-- - SIDE_CHANNEL_ONLY (5 components) 
-- - SIDE_CHANNEL_WITH_BOTTOM_RAIL (8 components)
-- 
-- But SO-000008 uses "Roller Shade" ProductType which may not
-- have an active template. This script:
-- 1. Finds the ProductType for SO-000008
-- 2. Finds or creates an active BOMTemplate for it
-- 3. Ensures it has all necessary components
-- ====================================================

-- Step 1: Find ProductType for SO-000008
SELECT 
    'Step 1: ProductType for SO-000008' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.id as product_type_id_verified,
    pt.name as product_type_name,
    pt.code as product_type_code
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false;

-- Step 2: Check which BOMTemplate is active for this ProductType
SELECT 
    'Step 2: BOMTemplate for ProductType' as check_type,
    pt.id as product_type_id,
    pt.name as product_type_name,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    bt.deleted,
    COUNT(bc.id) as component_count,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_count,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id 
    AND bt.organization_id = pt.organization_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY pt.id, pt.name, bt.id, bt.name, bt.active, bt.deleted;

-- Step 3: Show all BOMComponents for the active template (if exists)
SELECT 
    'Step 3: BOMComponents in Active Template' as check_type,
    bc.component_role,
    bc.block_type,
    bc.block_condition,
    bc.component_item_id,
    bc.auto_select,
    bc.sku_resolution_rule,
    bc.applies_color,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY bc.sequence_order, bc.component_role;

-- Step 4: FIX - Activate and link correct BOMTemplate for Roller Shade
DO $$
DECLARE
    v_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    v_bom_template_id uuid;
    v_quote_line_record record;
BEGIN
    RAISE NOTICE '🔧 Step 4: Fixing BOMTemplate for Roller Shade...';
    RAISE NOTICE '';
    
    -- Get ProductType from SO-000008
    SELECT DISTINCT ql.product_type_id, ql.organization_id
    INTO v_product_type_id, v_organization_id
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    INNER JOIN "SaleOrders" so ON so.quote_id = q.id
    WHERE so.sale_order_no = 'SO-000008'
    AND ql.deleted = false
    AND q.deleted = false
    AND so.deleted = false
    AND ql.product_type_id IS NOT NULL
    LIMIT 1;
    
    IF v_product_type_id IS NULL THEN
        RAISE WARNING '❌ Could not find product_type_id for SO-000008';
        RETURN;
    END IF;
    
    RAISE NOTICE '  ProductType ID: %', v_product_type_id;
    
    -- Find active BOMTemplate for this ProductType
    SELECT id INTO v_bom_template_id
    FROM "BOMTemplates"
    WHERE product_type_id = v_product_type_id
    AND organization_id = v_organization_id
    AND deleted = false
    AND active = true
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_bom_template_id IS NULL THEN
        RAISE NOTICE '  ⚠️  No active BOMTemplate found. Looking for inactive templates...';
        
        -- Try to find an inactive template and activate it
        SELECT id INTO v_bom_template_id
        FROM "BOMTemplates"
        WHERE product_type_id = v_product_type_id
        AND organization_id = v_organization_id
        AND deleted = false
        AND active = false
        ORDER BY created_at DESC
        LIMIT 1;
        
        IF v_bom_template_id IS NOT NULL THEN
            -- Activate the template
            UPDATE "BOMTemplates"
            SET active = true,
                updated_at = NOW()
            WHERE id = v_bom_template_id;
            
            RAISE NOTICE '  ✅ Activated BOMTemplate: %', v_bom_template_id;
        ELSE
            RAISE WARNING '  ❌ No BOMTemplate found (active or inactive) for ProductType: %', v_product_type_id;
            RAISE NOTICE '  💡 You may need to create a BOMTemplate for this ProductType';
            RETURN;
        END IF;
    ELSE
        RAISE NOTICE '  ✅ Found active BOMTemplate: %', v_bom_template_id;
    END IF;
    
    -- Verify components exist
    IF NOT EXISTS (
        SELECT 1 FROM "BOMComponents"
        WHERE bom_template_id = v_bom_template_id
        AND deleted = false
    ) THEN
        RAISE WARNING '  ⚠️  BOMTemplate % has no components!', v_bom_template_id;
    ELSE
        RAISE NOTICE '  ✅ BOMTemplate has components';
    END IF;
    
END $$;

-- Step 5: Final verification
SELECT 
    'Step 5: Final Verification' as check_type,
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
        WHEN bt.id IS NULL THEN '❌ NO BOMTemplate'
        WHEN bt.active = false THEN '⚠️ BOMTemplate INACTIVE'
        WHEN bt.deleted = true THEN '⚠️ BOMTemplate DELETED'
        WHEN COUNT(bc.id) = 0 THEN '❌ NO components'
        WHEN COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) = 0 THEN '❌ ONLY fabric components'
        ELSE '✅ BOMTemplate OK'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id 
    AND pt.organization_id = ql.organization_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id, pt.name, bt.id, bt.name, bt.active, bt.deleted;








