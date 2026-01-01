-- ====================================================
-- Migration: Update BOM Unit Costs using UOM Conversions
-- ====================================================
-- Updates existing QuoteLineComponents to calculate unit_cost_exw
-- using get_unit_cost_in_uom function
-- 
-- ⚠️  IMPORTANT: This migration requires migration 168 to be executed first!
--    Make sure migration 168_uom_conversions_and_cost_normalization.sql
--    has been executed successfully before running this migration.
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '🔄 Updating BOM unit costs using get_unit_cost_in_uom function...';
    
    -- Update unit_cost_exw for all configured components
    -- If function doesn't exist, this will raise an error naturally
    UPDATE "QuoteLineComponents" qlc
    SET 
        unit_cost_exw = public.get_unit_cost_in_uom(
            qlc.catalog_item_id,
            CASE 
                WHEN qlc.component_role LIKE '%tube%' OR 
                     qlc.component_role LIKE '%rail%' OR 
                     qlc.component_role LIKE '%profile%' OR 
                     qlc.component_role LIKE '%cassette%' OR
                     qlc.component_role LIKE '%channel%' THEN 'm'
                WHEN qlc.component_role LIKE '%fabric%' THEN 'm2'
                ELSE 'ea'
            END,
            qlc.organization_id
        ),
        updated_at = NOW()
    FROM "CatalogItems" ci
    WHERE qlc.catalog_item_id = ci.id
    AND qlc.source = 'configured_component'
    AND qlc.deleted = false
    AND ci.deleted = false;
    
    RAISE NOTICE '✅ Updated unit_cost_exw for all configured BOM components';
END $$;
