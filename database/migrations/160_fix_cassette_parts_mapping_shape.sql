-- ====================================================
-- Migration: Fix CassettePartsMapping Shape Detection
-- ====================================================
-- This script corrects incorrect shape assignments in CassettePartsMapping
-- Specifically fixes RC3132 and RC3052 which should be 'square' not 'round'
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_updated_count integer := 0;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Fixing CassettePartsMapping shape assignments...';
  RAISE NOTICE '';

  -- Get organization ID
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found';
  END IF;

  RAISE NOTICE '  📦 Organization ID: %', v_org_id;
  RAISE NOTICE '';

  -- Fix entries where item_name says "square" but shape is "round"
  -- If a correct entry already exists, delete the incorrect one instead of updating
  FOR rec IN (
    SELECT 
      cpm.id,
      cpm.cassette_shape,
      cpm.part_role,
      ci.sku,
      ci.item_name
    FROM "CassettePartsMapping" cpm
    JOIN "CatalogItems" ci ON cpm.catalog_item_id = ci.id
    WHERE cpm.organization_id = v_org_id
    AND cpm.deleted = false
    AND cpm.cassette_shape = 'round'
    AND ci.item_name ILIKE '%square%'
  ) LOOP
    -- Check if a correct entry already exists
    IF EXISTS (
      SELECT 1
      FROM "CassettePartsMapping" existing
      WHERE existing.organization_id = v_org_id
      AND existing.cassette_shape = 'square'
      AND existing.part_role = rec.part_role
      AND existing.deleted = false
      AND existing.id != rec.id
    ) THEN
      -- Delete the incorrect entry (duplicate)
      UPDATE "CassettePartsMapping"
      SET 
        deleted = true,
        updated_at = now()
      WHERE id = rec.id;

      v_updated_count := v_updated_count + 1;
      RAISE NOTICE '  🗑️  Deleted duplicate: % (was round, correct square entry already exists) - %', rec.sku, rec.item_name;
    ELSE
      -- No duplicate exists, safe to update
      UPDATE "CassettePartsMapping"
      SET 
        cassette_shape = 'square',
        updated_at = now()
      WHERE id = rec.id
      AND deleted = false;

      v_updated_count := v_updated_count + 1;
      RAISE NOTICE '  ✅ Fixed: % (was round, now square) - %', rec.sku, rec.item_name;
    END IF;
  END LOOP;

  -- Fix entries where SKU pattern indicates square but shape is round
  FOR rec IN (
    SELECT 
      cpm.id,
      cpm.cassette_shape,
      cpm.part_role,
      ci.sku,
      ci.item_name
    FROM "CassettePartsMapping" cpm
    JOIN "CatalogItems" ci ON cpm.catalog_item_id = ci.id
    WHERE cpm.organization_id = v_org_id
    AND cpm.deleted = false
    AND cpm.cassette_shape = 'round'
    AND (
      ci.sku LIKE '%3132%' OR  -- Semi-open cassette endcap set M square
      ci.sku LIKE '%3052%'      -- Semi-open cassette end cap set M square
    )
  ) LOOP
    -- Check if a correct entry already exists
    IF EXISTS (
      SELECT 1
      FROM "CassettePartsMapping" existing
      WHERE existing.organization_id = v_org_id
      AND existing.cassette_shape = 'square'
      AND existing.part_role = rec.part_role
      AND existing.deleted = false
      AND existing.id != rec.id
    ) THEN
      -- Delete the incorrect entry (duplicate)
      UPDATE "CassettePartsMapping"
      SET 
        deleted = true,
        updated_at = now()
      WHERE id = rec.id;

      v_updated_count := v_updated_count + 1;
      RAISE NOTICE '  🗑️  Deleted duplicate: % (was round, correct square entry already exists) - %', rec.sku, rec.item_name;
    ELSE
      -- No duplicate exists, safe to update
      UPDATE "CassettePartsMapping"
      SET 
        cassette_shape = 'square',
        updated_at = now()
      WHERE id = rec.id
      AND deleted = false;

      v_updated_count := v_updated_count + 1;
      RAISE NOTICE '  ✅ Fixed: % (was round, now square) - %', rec.sku, rec.item_name;
    END IF;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Fixed % CassettePartsMapping entries', v_updated_count;
  RAISE NOTICE '';

  -- Show summary
  RAISE NOTICE '📊 Current CassettePartsMapping summary:';
  FOR rec IN (
    SELECT 
      cassette_shape,
      part_role,
      COUNT(*) as count
    FROM "CassettePartsMapping"
    WHERE organization_id = v_org_id
    AND deleted = false
    GROUP BY cassette_shape, part_role
    ORDER BY cassette_shape, part_role
  ) LOOP
    RAISE NOTICE '  - % / %: % entries', rec.cassette_shape, rec.part_role, rec.count;
  END LOOP;

END $$;

