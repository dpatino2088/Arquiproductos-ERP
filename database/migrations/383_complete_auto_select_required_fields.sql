-- ====================================================
-- Migration 383: Complete Auto-Select Required Fields
-- ====================================================
-- Completes missing required fields (sku_resolution_rule, qty_type) for auto-select components
-- Based on component_role, sets sensible defaults
-- ====================================================
-- This migration fixes INCOMPLETE_AUTO_SELECT issues by setting defaults:
-- - sku_resolution_rule: 'CATEGORY_FIRST_MATCH' (standard resolution)
-- - qty_type: 'fixed' for most roles, 'by_width' for bottom_rail
-- ====================================================

DO $$
DECLARE
    v_updated_count integer;
    rec RECORD;
BEGIN
    -- Update auto-select components missing sku_resolution_rule or qty_type
    -- Set defaults based on component_role
    UPDATE "BOMComponents" bc
    SET 
        sku_resolution_rule = COALESCE(bc.sku_resolution_rule, 'CATEGORY_FIRST_MATCH'),
        qty_type = COALESCE(
            bc.qty_type,
            CASE 
                WHEN bc.component_role = 'bottom_rail' THEN 'per_width'::bom_qty_type
                WHEN bc.component_role = 'fabric' THEN 'per_area'::bom_qty_type
                ELSE 'fixed'::bom_qty_type
            END
        ),
        updated_at = now()
    WHERE (bc.auto_select = true OR bc.component_item_id IS NULL)
        AND bc.component_role IS NOT NULL
        AND (bc.sku_resolution_rule IS NULL OR bc.qty_type IS NULL)
        AND bc.deleted = false
        AND EXISTS (
            SELECT 1 
            FROM "BOMTemplates" bt 
            WHERE bt.id = bc.bom_template_id 
            AND bt.deleted = false
            AND bt.active = true
        );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % auto-select components with missing required fields', v_updated_count;
    
    -- Report breakdown by role
    RAISE NOTICE 'Breakdown by role:';
    FOR rec IN
        SELECT 
            bc.component_role,
            COUNT(*)::integer as count
        FROM "BOMComponents" bc
        WHERE (bc.auto_select = true OR bc.component_item_id IS NULL)
            AND bc.component_role IS NOT NULL
            AND bc.deleted = false
            AND EXISTS (
                SELECT 1 
                FROM "BOMTemplates" bt 
                WHERE bt.id = bc.bom_template_id 
                AND bt.deleted = false
                AND bt.active = true
            )
        GROUP BY bc.component_role
        ORDER BY bc.component_role
    LOOP
        RAISE NOTICE '  - %: % components', rec.component_role, rec.count;
    END LOOP;
END $$;

-- Verification query (run separately to verify)
-- SELECT 
--     bc.component_role,
--     COUNT(*) FILTER (WHERE bc.sku_resolution_rule IS NULL) as missing_sku_rule,
--     COUNT(*) FILTER (WHERE bc.qty_type IS NULL) as missing_qty_type,
--     COUNT(*) as total_auto_select
-- FROM "BOMComponents" bc
-- WHERE (bc.auto_select = true OR bc.component_item_id IS NULL)
--     AND bc.component_role IS NOT NULL
--     AND bc.deleted = false
--     AND EXISTS (
--         SELECT 1 
--         FROM "BOMTemplates" bt 
--         WHERE bt.id = bc.bom_template_id 
--         AND bt.deleted = false
--         AND bt.active = true
--     )
-- GROUP BY bc.component_role
-- ORDER BY bc.component_role;

