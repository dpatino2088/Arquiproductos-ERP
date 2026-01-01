-- ====================================================
-- Migration 218: Fix missing bom_template_id in BomInstances
-- ====================================================
-- Many BomInstances were created without bom_template_id.
-- This migration populates bom_template_id from SaleOrderLine.product_type_id
-- ====================================================

BEGIN;

-- Step 1: Identify BomInstances without bom_template_id
DO $$
DECLARE
    v_updated_count integer := 0;
    v_bom_instance RECORD;
    v_template_id uuid;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Fixing missing bom_template_id in BomInstances';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- For each BomInstance without bom_template_id
    FOR v_bom_instance IN
        SELECT 
            bi.id,
            bi.organization_id,
            bi.sale_order_line_id,
            sol.product_type_id
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE bi.deleted = false
        AND bi.bom_template_id IS NULL
        AND sol.product_type_id IS NOT NULL
        AND sol.deleted = false
    LOOP
        -- Find template by product_type_id
        SELECT id INTO v_template_id
        FROM "BOMTemplates"
        WHERE product_type_id = v_bom_instance.product_type_id
        AND deleted = false
        AND active = true
        ORDER BY 
            CASE WHEN organization_id = v_bom_instance.organization_id THEN 0 ELSE 1 END,
            created_at DESC
        LIMIT 1;
        
        IF v_template_id IS NOT NULL THEN
            -- Update BomInstance with template_id
            UPDATE "BomInstances"
            SET 
                bom_template_id = v_template_id,
                updated_at = NOW()
            WHERE id = v_bom_instance.id;
            
            v_updated_count := v_updated_count + 1;
            RAISE NOTICE '✅ Updated BomInstance % with template %', v_bom_instance.id, v_template_id;
        ELSE
            RAISE WARNING '⚠️  No template found for BomInstance % (product_type_id: %)', 
                v_bom_instance.id, v_bom_instance.product_type_id;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Summary: Updated % BomInstances', v_updated_count;
    RAISE NOTICE '========================================';
END $$;

-- Step 2: Verify the fix
SELECT 
    COUNT(*) FILTER (WHERE bom_template_id IS NULL) as missing_template_count,
    COUNT(*) FILTER (WHERE bom_template_id IS NOT NULL) as has_template_count,
    COUNT(*) as total
FROM "BomInstances"
WHERE deleted = false;

COMMIT;




