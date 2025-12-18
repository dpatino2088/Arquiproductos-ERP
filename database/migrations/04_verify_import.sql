-- ====================================================
-- Migration: Verify Import Results
-- ====================================================
-- Run this after importing to verify the data
-- ====================================================

DO $$
DECLARE
    target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    collection_count int;
    item_count int;
    fabric_count int;
    item_name_count int;
    variant_name_count int;
    rec RECORD;  -- Variable for loop
BEGIN

    -- Count Collections
    SELECT COUNT(*) INTO collection_count
    FROM "CollectionsCatalog" 
    WHERE organization_id = target_org_id;
    
    RAISE NOTICE '📊 Collections: %', collection_count;

    -- Count CatalogItems
    SELECT 
      COUNT(*) INTO item_count
    FROM "CatalogItems"
    WHERE organization_id = target_org_id;
    
    RAISE NOTICE '📊 Total CatalogItems: %', item_count;

    -- Count Fabrics
    SELECT 
      COUNT(*) INTO fabric_count
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND is_fabric = TRUE;
    
    RAISE NOTICE '📊 Fabrics: %', fabric_count;

    -- Count items with item_name
    SELECT 
      COUNT(*) INTO item_name_count
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND item_name IS NOT NULL
      AND trim(item_name) <> '';
    
    RAISE NOTICE '📊 Items with item_name: %', item_name_count;

    -- Count fabrics with variant_name
    SELECT 
      COUNT(*) INTO variant_name_count
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND is_fabric = TRUE
      AND variant_name IS NOT NULL
      AND trim(variant_name) <> '';
    
    RAISE NOTICE '📊 Fabrics with variant_name: %', variant_name_count;

    -- Show sample data
    RAISE NOTICE '';
    RAISE NOTICE '📋 Sample Fabrics (Collection + Variant):';
    FOR rec IN 
      SELECT 
        ci.sku,
        ci.item_name,
        cc.collection_name,
        ci.variant_name,
        CASE 
          WHEN ci.is_fabric AND cc.collection_name IS NOT NULL AND ci.variant_name IS NOT NULL
          THEN cc.collection_name || ' ' || ci.variant_name
          ELSE ci.item_name
        END as display_name
      FROM "CatalogItems" ci
      LEFT JOIN "CollectionsCatalog" cc ON cc.id = ci.collection_id
      WHERE ci.organization_id = target_org_id
        AND ci.is_fabric = TRUE
      LIMIT 5
    LOOP
      RAISE NOTICE '  - %: %', rec.sku, rec.display_name;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '📋 Sample Non-Fabrics (item_name):';
    FOR rec IN 
      SELECT 
        ci.sku,
        ci.item_name
      FROM "CatalogItems" ci
      WHERE ci.organization_id = target_org_id
        AND ci.is_fabric = FALSE
      LIMIT 5
    LOOP
      RAISE NOTICE '  - %: %', rec.sku, rec.item_name;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '✅ Verification complete!';

END $$;
