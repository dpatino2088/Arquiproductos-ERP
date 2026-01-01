-- ====================================================
-- Migration 387: Fix Common BOM Readiness Issues
-- ====================================================
-- This migration attempts to fix common issues detected by bom_readiness_report:
-- 1. Fixed components with missing CatalogItems (soft delete the component)
-- 2. Fixed components with CatalogItems that have NULL/empty UOM (set default UOM)
-- 3. Fixed components with CatalogItems missing item_category_id (try to infer from existing data)
-- ====================================================
-- NOTE: This migration is conservative - it only fixes what can be safely fixed
-- Manual intervention may be required for some cases
-- ====================================================

DO $$
DECLARE
    v_fixed_count integer := 0;
    v_uom_fixed_count integer := 0;
    v_category_fixed_count integer := 0;
    v_deleted_count integer := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE 'Starting BOM Readiness fixes...';
    
    -- ====================================================
    -- Fix 1: Soft delete fixed components with missing CatalogItems
    -- ====================================================
    UPDATE "BOMComponents" bc
    SET deleted = true, updated_at = now()
    WHERE bc.component_item_id IS NOT NULL
        AND bc.deleted = false
        AND NOT EXISTS (
            SELECT 1 
            FROM "CatalogItems" ci 
            WHERE ci.id = bc.component_item_id 
            AND ci.deleted = false
        )
        AND EXISTS (
            SELECT 1 
            FROM "BOMTemplates" bt 
            WHERE bt.id = bc.bom_template_id 
            AND bt.deleted = false 
            AND bt.active = true
        );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count > 0 THEN
        RAISE NOTICE '  ✅ Soft deleted % fixed component(s) with missing CatalogItems', v_deleted_count;
    END IF;
    
    -- ====================================================
    -- Fix 2: Set default UOM for CatalogItems with NULL/empty UOM
    -- (Only for CatalogItems that are referenced by BOMComponents)
    -- ====================================================
    UPDATE "CatalogItems" ci
    SET uom = CASE 
        WHEN ci.is_fabric THEN 'sqm'
        WHEN EXISTS (
            SELECT 1 
            FROM "ItemCategories" ic 
            WHERE ic.id = ci.item_category_id 
            AND ic.code IN ('COMP-TUBE', 'COMP-BOTTOM-RAIL', 'COMP-TOP-RAIL')
        ) THEN 'm'
        ELSE 'ea'
    END,
    updated_at = now()
    WHERE ci.deleted = false
        AND (ci.uom IS NULL OR TRIM(ci.uom) = '')
        AND EXISTS (
            SELECT 1 
            FROM "BOMComponents" bc 
            WHERE bc.component_item_id = ci.id 
            AND bc.deleted = false
            AND EXISTS (
                SELECT 1 
                FROM "BOMTemplates" bt 
                WHERE bt.id = bc.bom_template_id 
                AND bt.deleted = false 
                AND bt.active = true
            )
        );
    
    GET DIAGNOSTICS v_uom_fixed_count = ROW_COUNT;
    IF v_uom_fixed_count > 0 THEN
        RAISE NOTICE '  ✅ Fixed UOM for % CatalogItem(s) referenced by BOMComponents', v_uom_fixed_count;
    END IF;
    
    -- ====================================================
    -- Fix 3: Try to infer item_category_id for CatalogItems missing it
    -- (Only if we can find a matching ItemCategory by code/name)
    -- ====================================================
    -- This is more complex and risky, so we'll be very conservative
    -- Only update if there's a clear match and the CatalogItem is referenced by BOMComponents
    
    FOR rec IN
        SELECT DISTINCT
            ci.id as catalog_item_id,
            ci.sku,
            ci.item_name,
            ci.item_category_id,
            -- Try to find a matching category based on common patterns
            (
                SELECT ic2.id
                FROM "ItemCategories" ic2
                WHERE ic2.deleted = false
                AND (
                    -- Match by SKU prefix patterns
                    (ci.sku LIKE 'RC%' AND ic2.code = 'COMP-HARDWARE')
                    OR (ci.sku LIKE 'FAB-%' AND ic2.code = 'FABRIC')
                    OR (ci.sku LIKE 'TUBE-%' AND ic2.code = 'COMP-TUBE')
                    OR (ci.sku LIKE 'BRACKET-%' AND ic2.code = 'COMP-BRACKET')
                    OR (ci.sku LIKE 'CASSETTE-%' AND ic2.code = 'COMP-CASSETTE')
                    OR (ci.sku LIKE 'SIDE-%' AND ic2.code = 'COMP-SIDE')
                    OR (ci.sku LIKE 'BOTTOM-%' AND ic2.code IN ('COMP-BOTTOM-BAR', 'COMP-BOTTOM-RAIL'))
                    OR (ci.sku LIKE 'DRIVE-%' AND ic2.code IN ('DRIVE-MANUAL', 'DRIVE-MOTORIZED'))
                    OR (ci.sku LIKE 'ACC-%' AND ic2.code LIKE 'ACC%')
                    -- Match by item_name patterns
                    OR (ci.item_name ILIKE '%fabric%' AND ic2.code = 'FABRIC')
                    OR (ci.item_name ILIKE '%tube%' AND ic2.code = 'COMP-TUBE')
                    OR (ci.item_name ILIKE '%bracket%' AND ic2.code = 'COMP-BRACKET')
                    OR (ci.item_name ILIKE '%cassette%' AND ic2.code = 'COMP-CASSETTE')
                    OR (ci.item_name ILIKE '%side channel%' AND ic2.code = 'COMP-SIDE')
                    OR (ci.item_name ILIKE '%bottom%' AND ic2.code IN ('COMP-BOTTOM-BAR', 'COMP-BOTTOM-RAIL'))
                    OR (ci.item_name ILIKE '%motor%' AND ic2.code IN ('DRIVE-MANUAL', 'DRIVE-MOTORIZED'))
                )
                LIMIT 1
            ) as inferred_category_id
        FROM "CatalogItems" ci
        WHERE ci.deleted = false
            AND ci.item_category_id IS NULL
            AND EXISTS (
                SELECT 1 
                FROM "BOMComponents" bc 
                WHERE bc.component_item_id = ci.id 
                AND bc.deleted = false
                AND EXISTS (
                    SELECT 1 
                    FROM "BOMTemplates" bt 
                    WHERE bt.id = bc.bom_template_id 
                    AND bt.deleted = false 
                    AND bt.active = true
                )
            )
    LOOP
        IF rec.inferred_category_id IS NOT NULL THEN
            UPDATE "CatalogItems"
            SET item_category_id = rec.inferred_category_id,
                updated_at = now()
            WHERE id = rec.catalog_item_id;
            
            v_category_fixed_count := v_category_fixed_count + 1;
            RAISE NOTICE '  ✅ Inferred category for CatalogItem % (SKU: %, Name: %) -> Category ID: %', 
                rec.catalog_item_id, rec.sku, rec.item_name, rec.inferred_category_id;
        END IF;
    END LOOP;
    
    IF v_category_fixed_count > 0 THEN
        RAISE NOTICE '  ✅ Inferred item_category_id for % CatalogItem(s)', v_category_fixed_count;
    END IF;
    
    -- ====================================================
    -- Summary
    -- ====================================================
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM Readiness fixes completed:';
    RAISE NOTICE '  - Soft deleted % component(s) with missing CatalogItems', v_deleted_count;
    RAISE NOTICE '  - Fixed UOM for % CatalogItem(s)', v_uom_fixed_count;
    RAISE NOTICE '  - Inferred category for % CatalogItem(s)', v_category_fixed_count;
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  NOTE: Some issues may require manual intervention:';
    RAISE NOTICE '  - CatalogItems with no clear category pattern';
    RAISE NOTICE '  - Auto-select components with no available CatalogItems in mapped categories';
    RAISE NOTICE '  - Components that need to be recreated with correct CatalogItems';
END $$;

-- ====================================================
-- Verification Query
-- ====================================================
-- Run this query after the migration to verify the fixes
-- ====================================================
-- SELECT 
--     pt.name as product_type_name,
--     COUNT(DISTINCT bc.id) FILTER (
--         WHERE bc.component_item_id IS NOT NULL
--         AND (
--             NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false)
--             OR EXISTS (
--                 SELECT 1 FROM "CatalogItems" ci 
--                 WHERE ci.id = bc.component_item_id 
--                 AND (ci.uom IS NULL OR TRIM(ci.uom) = '' OR ci.item_category_id IS NULL)
--             )
--         )
--     ) as remaining_invalid_fixed_count
-- FROM "ProductTypes" pt
-- LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id AND bt.deleted = false AND bt.active = true
-- LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
-- WHERE pt.deleted = false
-- GROUP BY pt.id, pt.name
-- HAVING COUNT(DISTINCT bc.id) FILTER (
--     WHERE bc.component_item_id IS NOT NULL
--     AND (
--         NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false)
--         OR EXISTS (
--             SELECT 1 FROM "CatalogItems" ci 
--             WHERE ci.id = bc.component_item_id 
--             AND (ci.uom IS NULL OR TRIM(ci.uom) = '' OR ci.item_category_id IS NULL)
--         )
--     )
-- ) > 0
-- ORDER BY pt.name;

