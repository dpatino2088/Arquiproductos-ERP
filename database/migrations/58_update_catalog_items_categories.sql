-- Migration: Update item_category_id in CatalogItems based on CSV mapping
-- This script uses a temporary table to load CSV data and then updates CatalogItems
-- 
-- CSV Categories -> Database Categories mapping:
-- - Hardware -> Components (or subcategories)
-- - Motors -> Drives & Controls -> Motorized
-- - Controls -> Drives & Controls -> Controls
-- - Accessories -> Accessories (or subcategories)
-- - Fabrics -> Fabric
-- - Chains -> Components (or subcategories)
-- - Brackets -> Components -> Brackets
-- - Tool -> Components (or subcategories)
-- - Servicio -> NULL (services, not physical products)

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer := 0;
  not_found_count integer := 0;
  
  -- Category IDs (will be populated)
  v_fabric_id uuid;
  v_components_id uuid;
  v_brackets_id uuid;
  v_drives_controls_id uuid;
  v_controls_id uuid;
  v_motorized_id uuid;
  v_accessories_id uuid;
  v_accessories_leaf_id uuid;
  v_components_leaf_id uuid;
  
  -- CSV mapping data
  csv_data RECORD;
BEGIN
  RAISE NOTICE '🚀 Starting category update for CatalogItems...';
  RAISE NOTICE '   Organization ID: %', target_org_id;
  
  -- Step 1: Get category IDs
  -- Fabric (leaf category)
  SELECT id INTO v_fabric_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Fabric'
    AND is_group = false
    AND deleted = false
  LIMIT 1;
  
  -- Components (parent group)
  SELECT id INTO v_components_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Components'
    AND is_group = true
    AND deleted = false
  LIMIT 1;
  
  -- Brackets (leaf category under Components)
  SELECT id INTO v_brackets_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Brackets'
    AND is_group = false
    AND deleted = false
  LIMIT 1;
  
  -- Drives & Controls (parent group)
  SELECT id INTO v_drives_controls_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Drives & Controls'
    AND is_group = true
    AND deleted = false
  LIMIT 1;
  
  -- Controls (leaf category under Drives & Controls)
  SELECT id INTO v_controls_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Controls'
    AND is_group = false
    AND deleted = false
  LIMIT 1;
  
  -- Motorized (leaf category under Drives & Controls)
  SELECT id INTO v_motorized_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Motorized'
    AND is_group = false
    AND deleted = false
  LIMIT 1;
  
  -- Accessories (parent group)
  SELECT id INTO v_accessories_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name = 'Accessories'
    AND is_group = true
    AND deleted = false
  LIMIT 1;
  
  -- Get leaf categories for Accessories and Components
  SELECT id INTO v_accessories_leaf_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND parent_category_id = v_accessories_id
    AND is_group = false
    AND deleted = false
  LIMIT 1;
  
  IF v_accessories_leaf_id IS NULL THEN
    v_accessories_leaf_id := v_accessories_id;
  END IF;
  
  SELECT id INTO v_components_leaf_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND parent_category_id = v_components_id
    AND is_group = false
    AND deleted = false
  LIMIT 1;
  
  IF v_components_leaf_id IS NULL THEN
    v_components_leaf_id := v_components_id;
  END IF;
  
  -- Log category IDs found
  RAISE NOTICE '📋 Category IDs found:';
  RAISE NOTICE '   Fabric: %', COALESCE(v_fabric_id::text, 'NOT FOUND');
  RAISE NOTICE '   Components: %', COALESCE(v_components_id::text, 'NOT FOUND');
  RAISE NOTICE '   Components Leaf: %', COALESCE(v_components_leaf_id::text, 'NOT FOUND');
  RAISE NOTICE '   Brackets: %', COALESCE(v_brackets_id::text, 'NOT FOUND');
  RAISE NOTICE '   Drives & Controls: %', COALESCE(v_drives_controls_id::text, 'NOT FOUND');
  RAISE NOTICE '   Controls: %', COALESCE(v_controls_id::text, 'NOT FOUND');
  RAISE NOTICE '   Motorized: %', COALESCE(v_motorized_id::text, 'NOT FOUND');
  RAISE NOTICE '   Accessories: %', COALESCE(v_accessories_id::text, 'NOT FOUND');
  RAISE NOTICE '   Accessories Leaf: %', COALESCE(v_accessories_leaf_id::text, 'NOT FOUND');
  
  -- Step 2: Create temporary table for CSV data
  CREATE TEMP TABLE IF NOT EXISTS _stg_category_mapping (
    sku text NOT NULL,
    category text NOT NULL
  ) ON COMMIT DROP;
  
  -- Step 3: Insert CSV data into temporary table
  -- Note: In Supabase, you would import the CSV first, then this script would read from that table
  -- For now, we'll use a VALUES clause with all the data
  
  -- Insert all CSV rows (this is a large INSERT, but more maintainable than hardcoding in UPDATE)
  INSERT INTO _stg_category_mapping (sku, category) VALUES
    ('ABC-04-LW', 'Hardware'),
    ('ABC-27-W', 'Hardware'),
    ('CC1001-BK', 'Hardware'),
    ('CC1001-W', 'Hardware'),
    ('CC1002', 'Hardware'),
    ('CC1003-BK', 'Hardware'),
    ('CC1003-W', 'Hardware'),
    ('CC1004-BK', 'Hardware'),
    ('CC1004-W', 'Hardware'),
    ('CC1005-BK', 'Hardware'),
    ('CC1005-W', 'Hardware'),
    ('CC1006-BK', 'Hardware'),
    ('CC1006-W', 'Hardware'),
    ('CC1007-TR', 'Hardware'),
    ('CC1008-TR', 'Hardware'),
    ('CC1009', 'Hardware'),
    ('CC1010', 'Hardware'),
    ('CC1011-BK', 'Hardware'),
    ('CC1011-W', 'Hardware'),
    ('CC1012-BK', 'Hardware'),
    ('CC1012-W', 'Hardware'),
    ('CC1013-BK', 'Hardware'),
    ('CC1013-W', 'Hardware'),
    ('CC1014-BK', 'Hardware'),
    ('CC1014-W', 'Hardware'),
    ('CC1015-BK', 'Hardware'),
    ('CC1015-W', 'Hardware'),
    ('CC1016-BK', 'Hardware'),
    ('CC1016-W', 'Hardware'),
    ('CC1017-BK', 'Hardware'),
    ('CC1017-W', 'Hardware'),
    ('CC1018-BK', 'Hardware'),
    ('CC1018-W', 'Hardware'),
    ('CC1019-BK', 'Motors'),
    ('CC1019-W', 'Motors'),
    ('CC1020-BK', 'Hardware'),
    ('CC1020-W', 'Hardware'),
    ('CC1021-BK', 'Hardware'),
    ('CC1021-W', 'Hardware'),
    ('CC1022-BK', 'Hardware'),
    ('CC1023-BK', 'Hardware'),
    ('CC1023-W', 'Hardware'),
    ('CC1025-W', 'Hardware'),
    ('CC1026-W', 'Hardware'),
    ('CC1028-W', 'Hardware'),
    ('CC1029-W', 'Hardware'),
    ('CC1030-W', 'Hardware'),
    ('CC1031-W', 'Hardware'),
    ('CC1032-TR', 'Hardware'),
    ('CM-01', 'Motors'),
    ('CM-02', 'Motors'),
    ('CM-03', 'Motors'),
    ('CM-03-E', 'Motors'),
    ('CM-04', 'Motors'),
    ('CM-05', 'Motors'),
    ('CM-06', 'Motors'),
    ('CM-06-E-R', 'Motors'),
    ('CM-07', 'Motors'),
    ('CM-08', 'Motors'),
    ('CM-08-E', 'Motors'),
    ('CM-09-C120', 'Motors'),
    ('CM-09-MC120', 'Motors'),
    ('CM-09-QC120', 'Motors'),
    ('CM-09-QMC120', 'Motors'),
    ('CM-10-QC120', 'Motors'),
    ('CM-10-QMC120', 'Motors'),
    ('CM-11-BK', 'Controls'),
    ('CM-11-W', 'Controls'),
    ('CM-12-BK', 'Controls'),
    ('CM-13-BK', 'Controls'),
    ('CM-15-W', 'Controls'),
    ('CM-16-BK', 'Controls'),
    ('CM-17-BK', 'Controls'),
    ('CM-18-W', 'Controls'),
    ('CM-19', 'Controls'),
    ('CM-20', 'Controls'),
    ('CM-21-USA', 'Accessories'),
    ('CM-22', 'Accessories'),
    ('CM-23-US', 'Accessories'),
    ('CM-29', 'Accessories'),
    ('CM-30', 'Accessories'),
    ('CM-31-W', 'Accessories'),
    ('CM-32-W', 'Accessories'),
    ('CM-34-120', 'Accessories'),
    ('CM-35-120', 'Accessories'),
    ('CM-36-E', 'Accessories'),
    ('CM-36-W', 'Accessories'),
    ('CM-38', 'Accessories'),
    ('CM-39', 'Accessories'),
    ('CM-40', 'Accessories'),
    ('CM-41', 'Accessories'),
    ('CM-43-AN', 'Accessories'),
    ('CM-43-BK', 'Accessories'),
    ('CM-43-DBR', 'Accessories'),
    ('CM-43-GR', 'Accessories'),
    ('CM-43-LB', 'Accessories'),
    ('CM-43-SA', 'Accessories'),
    ('CM-43-TP', 'Accessories'),
    ('CM-43-W', 'Accessories'),
    ('CM-45', 'Motors'),
    ('CM-46-G', 'Controls'),
    ('CM-48-W', 'Controls'),
    ('CM-49-W', 'Hardware'),
    ('CR-16-W', 'Hardware'),
    ('CSD05-G', 'Chains'),
    ('CSD05-TR', 'Chains'),
    ('CSD05-W', 'Hardware'),
    ('CSD13-TR', 'Hardware'),
    ('CSD15-AN', 'Hardware'),
    ('CSD15-BK', 'Hardware'),
    ('CSD15-DBR', 'Hardware'),
    ('CSD15-G', 'Hardware'),
    ('CSD15-LB', 'Hardware'),
    ('CSD15-S', 'Hardware'),
    ('CSD15-SA', 'Hardware'),
    ('CSD15-TP', 'Hardware'),
    ('CSD15-W', 'Hardware'),
    ('CSD17-TR', 'Hardware'),
    ('CSD18', 'Chains'),
    ('CSD19', 'Chains'),
    ('DRC-03-AN', 'Accessories'),
    ('DRC-03-BK', 'Accessories'),
    ('DRC-03-DBR', 'Accessories'),
    ('DRC-03-GR', 'Accessories'),
    ('DRC-03-LB', 'Accessories'),
    ('DRC-03-W', 'Accessories'),
    ('DRC-04-A', 'Hardware'),
    ('DRC-04-AN', 'Hardware'),
    ('DRC-04-BK', 'Hardware'),
    ('DRC-04-DBR', 'Hardware'),
    ('DRC-04-LB', 'Hardware'),
    ('DRC-04-W', 'Hardware'),
    ('DRC-05-A', 'Hardware'),
    ('DRC-05-AN', 'Hardware'),
    ('DRC-05-BK', 'Hardware'),
    ('DRC-05-DBR', 'Hardware'),
    ('DRC-05-LB', 'Hardware'),
    ('DRC-05-W', 'Hardware'),
    ('DRC-07-A', 'Hardware'),
    ('DRC-07-AN', 'Hardware'),
    ('DRC-07-BK', 'Hardware'),
    ('DRC-07-DBR', 'Hardware'),
    ('DRC-07-LB', 'Hardware'),
    ('DRC-07-W', 'Hardware'),
    ('DRC-08-AN', 'Accessories'),
    ('DRC-08-BK', 'Accessories'),
    ('DRC-08-DBR', 'Accessories'),
    ('DRC-08-GR', 'Accessories'),
    ('DRC-08-LB', 'Accessories'),
    ('DRC-08-W', 'Accessories'),
    ('DRC-09-A', 'Accessories'),
    ('DRC-09-AN', 'Accessories'),
    ('DRC-09-BK', 'Accessories'),
    ('DRC-09-DBR', 'Accessories'),
    ('DRC-09-LB', 'Accessories'),
    ('DRC-09-W', 'Accessories')
    -- Note: This is a truncated version. The full CSV has ~2490 rows.
    -- You should import the CSV into Supabase first, then use this approach:
    -- INSERT INTO _stg_category_mapping (sku, category)
    -- SELECT sku, category FROM your_imported_csv_table;
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE '📊 Loaded % rows into temporary table', (SELECT COUNT(*) FROM _stg_category_mapping);
  
  -- Step 4: Update CatalogItems based on category mapping
  -- Fabrics
  UPDATE "CatalogItems" ci
  SET item_category_id = v_fabric_id,
      updated_at = NOW()
  FROM _stg_category_mapping stg
  WHERE ci.organization_id = target_org_id
    AND ci.sku = stg.sku
    AND stg.category = 'Fabrics'
    AND v_fabric_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Updated % Fabrics', updated_count;
  
  -- Motors -> Motorized
  UPDATE "CatalogItems" ci
  SET item_category_id = v_motorized_id,
      updated_at = NOW()
  FROM _stg_category_mapping stg
  WHERE ci.organization_id = target_org_id
    AND ci.sku = stg.sku
    AND stg.category = 'Motors'
    AND v_motorized_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Updated % Motors', updated_count;
  
  -- Controls -> Controls
  UPDATE "CatalogItems" ci
  SET item_category_id = v_controls_id,
      updated_at = NOW()
  FROM _stg_category_mapping stg
  WHERE ci.organization_id = target_org_id
    AND ci.sku = stg.sku
    AND stg.category = 'Controls'
    AND v_controls_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Updated % Controls', updated_count;
  
  -- Brackets -> Brackets
  UPDATE "CatalogItems" ci
  SET item_category_id = v_brackets_id,
      updated_at = NOW()
  FROM _stg_category_mapping stg
  WHERE ci.organization_id = target_org_id
    AND ci.sku = stg.sku
    AND stg.category = 'Brackets'
    AND v_brackets_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Updated % Brackets', updated_count;
  
  -- Accessories -> Accessories (leaf category)
  UPDATE "CatalogItems" ci
  SET item_category_id = v_accessories_leaf_id,
      updated_at = NOW()
  FROM _stg_category_mapping stg
  WHERE ci.organization_id = target_org_id
    AND ci.sku = stg.sku
    AND stg.category = 'Accessories'
    AND v_accessories_leaf_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Updated % Accessories', updated_count;
  
  -- Hardware, Chains, Tool -> Components (leaf category)
  UPDATE "CatalogItems" ci
  SET item_category_id = v_components_leaf_id,
      updated_at = NOW()
  FROM _stg_category_mapping stg
  WHERE ci.organization_id = target_org_id
    AND ci.sku = stg.sku
    AND stg.category IN ('Hardware', 'Chains', 'Tool')
    AND v_components_leaf_id IS NOT NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Updated % Hardware/Chains/Tool items', updated_count;
  
  -- Servicio -> NULL (leave as NULL, services are not physical products)
  -- No update needed for Servicio items
  
  -- Final summary
  SELECT COUNT(*) INTO updated_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND item_category_id IS NOT NULL
    AND deleted = false;
  
  SELECT COUNT(*) INTO not_found_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND item_category_id IS NULL
    AND deleted = false;
  
  RAISE NOTICE '';
  RAISE NOTICE '📊 Summary:';
  RAISE NOTICE '   ✅ Items with category: %', updated_count;
  RAISE NOTICE '   ⚠️  Items without category: %', not_found_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Category update completed!';
  
  -- Cleanup
  DROP TABLE IF EXISTS _stg_category_mapping;
  
END $$;
