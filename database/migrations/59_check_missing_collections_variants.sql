-- Migration 59: Check for missing collections and variants in CatalogItems
-- This script helps identify data inconsistencies

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  fabric_items_count integer;
  items_with_collection integer;
  items_with_variant integer;
  items_with_both integer;
  items_without_collection integer;
  items_without_variant integer;
  unique_collections_count integer;
  unique_variants_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Checking Collections and Variants in CatalogItems';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Count fabric items
  SELECT COUNT(*) INTO fabric_items_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false;

  RAISE NOTICE '📊 Fabric Items Summary:';
  RAISE NOTICE '   Total fabric items: %', fabric_items_count;

  -- Count items with collection_name
  SELECT COUNT(*) INTO items_with_collection
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND collection_name IS NOT NULL
    AND TRIM(collection_name) != '';

  RAISE NOTICE '   Items with collection_name: %', items_with_collection;

  -- Count items with variant_name
  SELECT COUNT(*) INTO items_with_variant
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND variant_name IS NOT NULL
    AND TRIM(variant_name) != '';

  RAISE NOTICE '   Items with variant_name: %', items_with_variant;

  -- Count items with both
  SELECT COUNT(*) INTO items_with_both
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND collection_name IS NOT NULL
    AND TRIM(collection_name) != ''
    AND variant_name IS NOT NULL
    AND TRIM(variant_name) != '';

  RAISE NOTICE '   Items with both collection_name AND variant_name: %', items_with_both;

  -- Count items missing collection_name
  SELECT COUNT(*) INTO items_without_collection
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND (collection_name IS NULL OR TRIM(collection_name) = '');

  RAISE NOTICE '';
  RAISE NOTICE '⚠️  Missing Data:';
  RAISE NOTICE '   Fabric items WITHOUT collection_name: %', items_without_collection;

  -- Count items missing variant_name
  SELECT COUNT(*) INTO items_without_variant
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND collection_name IS NOT NULL
    AND TRIM(collection_name) != ''
    AND (variant_name IS NULL OR TRIM(variant_name) = '');

  RAISE NOTICE '   Fabric items WITH collection_name but WITHOUT variant_name: %', items_without_variant;

  -- Count unique collections
  SELECT COUNT(DISTINCT collection_name) INTO unique_collections_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND collection_name IS NOT NULL
    AND TRIM(collection_name) != '';

  RAISE NOTICE '';
  RAISE NOTICE '📋 Unique Values:';
  RAISE NOTICE '   Unique collection_name values: %', unique_collections_count;

  -- Count unique variants
  SELECT COUNT(DISTINCT variant_name) INTO unique_variants_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND variant_name IS NOT NULL
    AND TRIM(variant_name) != '';

  RAISE NOTICE '   Unique variant_name values: %', unique_variants_count;

  -- Show sample of items missing collection_name
  RAISE NOTICE '';
  RAISE NOTICE '📝 Sample Items Missing collection_name (first 10):';
  FOR rec IN (
    SELECT sku, item_name, is_fabric
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND is_fabric = true
      AND deleted = false
      AND (collection_name IS NULL OR TRIM(collection_name) = '')
    LIMIT 10
  ) LOOP
    RAISE NOTICE '   - SKU: %, Name: %', rec.sku, rec.item_name;
  END LOOP;

  -- Show sample of items missing variant_name
  RAISE NOTICE '';
  RAISE NOTICE '📝 Sample Items Missing variant_name (first 10):';
  FOR rec IN (
    SELECT sku, item_name, collection_name
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND is_fabric = true
      AND deleted = false
      AND collection_name IS NOT NULL
      AND TRIM(collection_name) != ''
      AND (variant_name IS NULL OR TRIM(variant_name) = '')
    LIMIT 10
  ) LOOP
    RAISE NOTICE '   - SKU: %, Collection: %, Name: %', rec.sku, rec.collection_name, rec.item_name;
  END LOOP;

  -- Show unique collections
  RAISE NOTICE '';
  RAISE NOTICE '📋 All Unique Collections:';
  FOR rec IN (
    SELECT DISTINCT collection_name, COUNT(*) as item_count
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND is_fabric = true
      AND deleted = false
      AND collection_name IS NOT NULL
      AND TRIM(collection_name) != ''
    GROUP BY collection_name
    ORDER BY collection_name
  ) LOOP
    RAISE NOTICE '   - % (% items)', rec.collection_name, rec.item_count;
  END LOOP;

  -- Show collections with their variants
  RAISE NOTICE '';
  RAISE NOTICE '📋 Collections with Variants:';
  FOR rec IN (
    SELECT 
      collection_name,
      variant_name,
      COUNT(*) as item_count,
      STRING_AGG(DISTINCT sku, ', ' ORDER BY sku) as sample_skus
    FROM "CatalogItems"
    WHERE organization_id = target_org_id
      AND is_fabric = true
      AND deleted = false
      AND collection_name IS NOT NULL
      AND TRIM(collection_name) != ''
      AND variant_name IS NOT NULL
      AND TRIM(variant_name) != ''
    GROUP BY collection_name, variant_name
    ORDER BY collection_name, variant_name
    LIMIT 20
  ) LOOP
    RAISE NOTICE '   - Collection: %, Variant: % (% items) [SKUs: %]', 
      rec.collection_name, rec.variant_name, rec.item_count, 
      SUBSTRING(rec.sample_skus, 1, 50);
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Check completed!';
  RAISE NOTICE '';

END $$;













