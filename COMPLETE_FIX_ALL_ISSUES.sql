-- ====================================================
-- Script: Complete Fix for All BOM Issues
-- ====================================================
-- This script fixes:
-- 1. organization_id in BomInstanceLines (multi-org support)
-- 2. Fabric UOM "ea" → "m" or "m2"
-- 3. Regenerates BOM with correct block_conditions
-- 4. Copies all components to BomInstanceLines
-- ====================================================

-- ====================================================
-- PART 1: Ensure organization_id in BomInstanceLines
-- ====================================================
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
        
        CREATE INDEX IF NOT EXISTS idx_bom_instance_lines_organization_id 
        ON "BomInstanceLines"(organization_id);
        
        RAISE NOTICE '✅ Added organization_id column and index to BomInstanceLines';
        
        -- Update existing rows
        UPDATE "BomInstanceLines" bil
        SET organization_id = bi.organization_id,
            updated_at = NOW()
        FROM "BomInstances" bi
        WHERE bil.bom_instance_id = bi.id
        AND bil.organization_id IS NULL;
        
        RAISE NOTICE '✅ Updated existing BomInstanceLines with organization_id';
    ELSE
        RAISE NOTICE '⏭️  organization_id column already exists in BomInstanceLines';
    END IF;
END $$;

-- ====================================================
-- PART 2: Fix Fabric UOM "ea" → "m" or "m2"
-- ====================================================
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FIXING FABRIC UOM';
    RAISE NOTICE '========================================';
    
    -- Fix CatalogItems
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
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Fixed % CatalogItems with UOM = ea', v_updated_count;
    
    -- Fix QuoteLineComponents
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
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Fixed % QuoteLineComponents with UOM = ea', v_updated_count;
    
    -- Fix BomInstanceLines
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
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Fixed % BomInstanceLines with UOM = ea', v_updated_count;
END $$;

-- ====================================================
-- PART 3: Regenerate BOM for SO-000008
-- ====================================================
DO $$
DECLARE
    v_quote_line_record record;
    v_result jsonb;
    v_success_count integer := 0;
    v_error_count integer := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REGENERATING BOM';
    RAISE NOTICE '========================================';
    
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            COALESCE(ql.drive_type, 'manual') as drive_type,
            COALESCE(ql.bottom_rail_type, 'standard') as bottom_rail_type,
            COALESCE(ql.cassette, false) as cassette,
            ql.cassette_type,
            COALESCE(ql.side_channel, false) as side_channel,
            ql.side_channel_type,
            COALESCE(ql.hardware_color, 'white') as hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty
        FROM "QuoteLines" ql
        INNER JOIN "Quotes" q ON q.id = ql.quote_id
        INNER JOIN "SaleOrders" so ON so.quote_id = q.id
        WHERE so.sale_order_no IN ('SO-000008', '50-000008')
        AND ql.deleted = false
        AND q.deleted = false
        AND so.deleted = false
        AND ql.product_type_id IS NOT NULL
    LOOP
        BEGIN
            -- Delete existing configured components
            DELETE FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line_record.quote_line_id
            AND source = 'configured_component'
            AND organization_id = v_quote_line_record.organization_id;
            
            -- Regenerate BOM
            SELECT public.generate_configured_bom_for_quote_line(
                v_quote_line_record.quote_line_id,
                v_quote_line_record.product_type_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.cassette,
                v_quote_line_record.cassette_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.qty
            ) INTO v_result;
            
            IF v_result->>'success' = 'true' THEN
                v_success_count := v_success_count + 1;
                RAISE NOTICE '✅ Regenerated BOM for QuoteLine %: % components', v_quote_line_record.quote_line_id, v_result->>'count';
            ELSE
                v_error_count := v_error_count + 1;
                RAISE WARNING '❌ Error for QuoteLine %: %', v_quote_line_record.quote_line_id, COALESCE(v_result->>'error', v_result->>'message');
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING '❌ Exception for QuoteLine %: %', v_quote_line_record.quote_line_id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Regenerated % QuoteLines successfully', v_success_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '❌ Errors in % QuoteLines', v_error_count;
    END IF;
END $$;

-- ====================================================
-- PART 4: Copy QuoteLineComponents to BomInstanceLines
-- ====================================================
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
    RAISE NOTICE 'COPYING TO BOMINSTANCELINES';
    RAISE NOTICE '========================================';
    
    -- Get Sale Order ID
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE sale_order_no IN ('SO-000008', '50-000008')
    AND deleted = false
    LIMIT 1;
    
    IF v_sale_order_id IS NULL THEN
        RAISE EXCEPTION 'Sale Order SO-000008 or 50-000008 not found';
    END IF;
    
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
        END IF;
        
        -- Delete existing BomInstanceLines
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
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
        RAISE NOTICE '✅ Copied % components to BomInstanceLines for SaleOrderLine %', v_component_count, v_sale_order_line_id;
    END LOOP;
    
    RAISE NOTICE '✅ Copy completed';
END $$;

-- ====================================================
-- PART 5: Final Verification
-- ====================================================
-- Step 5.1: QuoteLineComponents
SELECT 
    'Final: QuoteLineComponents' as check_type,
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

-- Step 5.2: BomInstanceLines
SELECT 
    'Final: BomInstanceLines' as check_type,
    bil.category_code,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty,
    COUNT(DISTINCT bil.organization_id) as distinct_orgs
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND so.deleted = false
GROUP BY bil.category_code
ORDER BY bil.category_code;

-- Step 5.3: SaleOrderMaterialList View
SELECT 
    'Final: SaleOrderMaterialList' as check_type,
    category_code,
    COUNT(*) as count,
    SUM(total_qty) as total_qty
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (SELECT id FROM "SaleOrders" WHERE sale_order_no IN ('SO-000008', '50-000008') AND deleted = false LIMIT 1)
GROUP BY category_code
ORDER BY category_code;








