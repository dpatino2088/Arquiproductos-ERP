-- ====================================================
-- Script: Copy QuoteLineComponents to BomInstanceLines
-- ====================================================
-- If BomInstanceLines are missing or incomplete,
-- copy components from QuoteLineComponents to BomInstanceLines
-- ====================================================

-- Step 1: Check current state of BomInstanceLines for SO-000008
SELECT 
    'Step 1: Current BomInstanceLines' as check_type,
    bil.category_code,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY bil.category_code;

-- Step 2: Check QuoteLineComponents that should be copied
SELECT 
    'Step 2: QuoteLineComponents to Copy' as check_type,
    public.derive_category_code_from_role(qlc.component_role) as category_code,
    COUNT(*) as count,
    SUM(qlc.qty) as total_qty
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY public.derive_category_code_from_role(qlc.component_role)
ORDER BY category_code;

-- Step 3: Add organization_id column to BomInstanceLines if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'organization_id'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN organization_id uuid;
        
        RAISE NOTICE '✅ Added organization_id column to BomInstanceLines';
        
        -- Update existing rows with organization_id from BomInstances
        UPDATE "BomInstanceLines" bil
        SET organization_id = bi.organization_id
        FROM "BomInstances" bi
        WHERE bil.bom_instance_id = bi.id
        AND bil.organization_id IS NULL;
        
        RAISE NOTICE '✅ Updated existing BomInstanceLines with organization_id';
    ELSE
        RAISE NOTICE '⏭️  organization_id column already exists in BomInstanceLines';
    END IF;
END $$;

-- Step 4: Copy QuoteLineComponents to BomInstanceLines
DO $$
DECLARE
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_component_count integer := 0;
    v_updated_count integer;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'COPYING QUOTELINECOMPONENTS TO BOMINSTANCELINES';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Get Sale Order ID
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE sale_order_no IN ('SO-000008', '50-000008')
    AND deleted = false
    LIMIT 1;
    
    IF v_sale_order_id IS NULL THEN
        RAISE EXCEPTION 'Sale Order SO-000008 or 50-000008 not found';
    END IF;
    
    RAISE NOTICE '✅ Found Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '';
    
    -- Process each SaleOrderLine
    FOR v_sale_order_line_id, v_quote_line_id, v_bom_instance_id IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            bi.id as bom_instance_id
        FROM "SaleOrderLines" sol
        INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
        LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
        WHERE sol.sale_order_id = v_sale_order_id
        AND sol.deleted = false
    LOOP
        RAISE NOTICE 'Processing SaleOrderLine: %', v_sale_order_line_id;
        RAISE NOTICE '  QuoteLine ID: %', v_quote_line_id;
        RAISE NOTICE '  BomInstance ID: %', COALESCE(v_bom_instance_id::text, 'NULL - will create');
        
        -- Create BomInstance if it doesn't exist
        IF v_bom_instance_id IS NULL THEN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                created_at,
                updated_at,
                deleted
            )
            SELECT 
                ql.organization_id,
                v_sale_order_line_id,
                v_quote_line_id,
                NOW(),
                NOW(),
                false
            FROM "QuoteLines" ql
            WHERE ql.id = v_quote_line_id
            RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  ✅ Created BomInstance: %', v_bom_instance_id;
        END IF;
        
        -- Delete existing BomInstanceLines for this BomInstance
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        RAISE NOTICE '  ✅ Deleted % existing BomInstanceLines', v_updated_count;
        
        -- Copy QuoteLineComponents to BomInstanceLines
        INSERT INTO "BomInstanceLines" (
            organization_id,
            bom_instance_id,
            resolved_part_id,
            resolved_sku,
            part_role,
            qty,
            uom,
            unit_cost_exw,
            total_cost_exw,
            category_code,
            description,
            created_at,
            updated_at,
            deleted
        )
        SELECT 
            qlc.organization_id,
            v_bom_instance_id,
            qlc.catalog_item_id,
            ci.sku as resolved_sku,
            qlc.component_role as part_role,
            qlc.qty,
            qlc.uom,
            qlc.unit_cost_exw,
            qlc.qty * COALESCE(qlc.unit_cost_exw, 0) as total_cost_exw,
            public.derive_category_code_from_role(qlc.component_role) as category_code,
            ci.item_name as description,
            NOW(),
            NOW(),
            false
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        GET DIAGNOSTICS v_component_count = ROW_COUNT;
        RAISE NOTICE '  ✅ Copied % components to BomInstanceLines', v_component_count;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'COPY COMPLETED';
    RAISE NOTICE '========================================';
END $$;

-- Step 5: Verify copied data
SELECT 
    'Step 4: Verification - BomInstanceLines after Copy' as check_type,
    bil.category_code,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY bil.category_code;

-- Step 6: Check SaleOrderMaterialList view
SELECT 
    'Step 5: SaleOrderMaterialList View' as check_type,
    category_code,
    COUNT(*) as count,
    SUM(total_qty) as total_qty,
    STRING_AGG(DISTINCT sku, ', ' ORDER BY sku) FILTER (WHERE sku IS NOT NULL) as sample_skus
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no IN ('SO-000008', '50-000008') AND deleted = false LIMIT 1)
GROUP BY category_code
ORDER BY category_code;

