-- ====================================================
-- Migration: Add missing rail categories for components
-- ====================================================
-- Adds:
--   - Top Rail (COMP-TOP-RAIL)
--   - Bottom Rail (COMP-BOTTOM-RAIL)
--   - Bottom Channel (COMP-BOTTOM-CHANNEL) if it doesn't exist
-- ====================================================

DO $$
DECLARE
  org_rec RECORD;
  comp_parent_id uuid;
  tubo_profile_parent_id uuid;
  v_top_rail_id uuid;
  v_bottom_rail_id uuid;
  v_bottom_channel_id uuid;
  v_sort_order integer;
BEGIN
  -- Loop through all organizations
  FOR org_rec IN 
    SELECT DISTINCT organization_id 
    FROM "ItemCategories" 
    WHERE deleted = false
  LOOP
    RAISE NOTICE 'Processing organization: %', org_rec.organization_id;

    -- Get Components parent category
    SELECT id INTO comp_parent_id
    FROM "ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND code = 'COMP'
      AND is_group = true
      AND deleted = false
    LIMIT 1;

    -- Get "Tubo and Profile" parent category (if exists)
    SELECT id INTO tubo_profile_parent_id
    FROM "ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND code = 'COMP-TUBO-PROFILE'
      AND is_group = true
      AND deleted = false
    LIMIT 1;

    -- If Components parent doesn't exist, skip this organization
    IF comp_parent_id IS NULL THEN
      RAISE NOTICE '⚠️ Components parent category not found for org %, skipping', org_rec.organization_id;
      CONTINUE;
    END IF;

    -- Calculate sort_order
    SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_sort_order
    FROM "ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND parent_category_id = COALESCE(tubo_profile_parent_id, comp_parent_id)
      AND deleted = false;

    -- UPSERT Top Rail (check if exists first)
    SELECT id INTO v_top_rail_id
    FROM "ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND code = 'COMP-TOP-RAIL'
      AND deleted = false
    LIMIT 1;

    IF v_top_rail_id IS NULL THEN
      -- Insert new
      INSERT INTO "ItemCategories" (
        organization_id,
        name,
        code,
        is_group,
        parent_category_id,
        sort_order,
        deleted,
        archived,
        created_at,
        updated_at
      )
      VALUES (
        org_rec.organization_id,
        'Top Rail',
        'COMP-TOP-RAIL',
        false,
        COALESCE(tubo_profile_parent_id, comp_parent_id),
        v_sort_order,
        false,
        false,
        NOW(),
        NOW()
      );
    ELSE
      -- Update existing
      UPDATE "ItemCategories"
      SET
        name = 'Top Rail',
        parent_category_id = COALESCE(tubo_profile_parent_id, comp_parent_id),
        updated_at = NOW()
      WHERE id = v_top_rail_id;
    END IF;

    -- UPSERT Bottom Rail
    SELECT id INTO v_bottom_rail_id
    FROM "ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND code = 'COMP-BOTTOM-RAIL'
      AND deleted = false
    LIMIT 1;

    IF v_bottom_rail_id IS NULL THEN
      -- Insert new
      INSERT INTO "ItemCategories" (
        organization_id,
        name,
        code,
        is_group,
        parent_category_id,
        sort_order,
        deleted,
        archived,
        created_at,
        updated_at
      )
      VALUES (
        org_rec.organization_id,
        'Bottom Rail',
        'COMP-BOTTOM-RAIL',
        false,
        COALESCE(tubo_profile_parent_id, comp_parent_id),
        v_sort_order + 1,
        false,
        false,
        NOW(),
        NOW()
      );
    ELSE
      -- Update existing
      UPDATE "ItemCategories"
      SET
        name = 'Bottom Rail',
        parent_category_id = COALESCE(tubo_profile_parent_id, comp_parent_id),
        updated_at = NOW()
      WHERE id = v_bottom_rail_id;
    END IF;

    -- UPSERT Bottom Channel (only if it doesn't exist)
    SELECT id INTO v_bottom_channel_id
    FROM "ItemCategories"
    WHERE organization_id = org_rec.organization_id
      AND code = 'COMP-BOTTOM-CHANNEL'
      AND deleted = false
    LIMIT 1;

    IF v_bottom_channel_id IS NULL THEN
      -- Insert new (only if doesn't exist)
      INSERT INTO "ItemCategories" (
        organization_id,
        name,
        code,
        is_group,
        parent_category_id,
        sort_order,
        deleted,
        archived,
        created_at,
        updated_at
      )
      VALUES (
        org_rec.organization_id,
        'Bottom Channel',
        'COMP-BOTTOM-CHANNEL',
        false,
        COALESCE(tubo_profile_parent_id, comp_parent_id),
        v_sort_order + 2,
        false,
        false,
        NOW(),
        NOW()
      );
    END IF;
    -- If exists, do nothing (as requested)

    RAISE NOTICE '✅ Categories added/updated for organization: %', org_rec.organization_id;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration 207 completed: Rail categories added';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Created/Updated:';
  RAISE NOTICE '   - Top Rail (COMP-TOP-RAIL)';
  RAISE NOTICE '   - Bottom Rail (COMP-BOTTOM-RAIL)';
  RAISE NOTICE '   - Bottom Channel (COMP-BOTTOM-CHANNEL) - only if missing';
  RAISE NOTICE '';
END $$;

