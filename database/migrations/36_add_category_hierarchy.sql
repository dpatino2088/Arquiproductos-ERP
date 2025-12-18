-- ====================================================
-- Migration: Add 2-Level Category Hierarchy
-- ====================================================
-- Adds parent_category_id and is_group to ItemCategories
-- Reclassifies existing categories into parent groups and children
-- ====================================================

DO $$
DECLARE
  v_fab_id uuid;
  v_comp_id uuid;
  v_acc_id uuid;
  v_motor_id uuid;
  org_rec RECORD;
  fab_parent_id uuid;
  comp_parent_id uuid;
  acc_parent_id uuid;
  motor_parent_id uuid;
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding category hierarchy (parent_category_id, is_group)';
  RAISE NOTICE '====================================================';

  -- Step 1: Add parent_category_id column (if it doesn't exist)
  -- Note: The table might already have parent_id, so we'll check and rename if needed
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'ItemCategories' 
    AND column_name = 'parent_id'
  ) THEN
    -- Rename parent_id to parent_category_id for consistency
    ALTER TABLE public."ItemCategories" 
    RENAME COLUMN parent_id TO parent_category_id;
    RAISE NOTICE '✅ Renamed parent_id to parent_category_id';
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'ItemCategories' 
    AND column_name = 'parent_category_id'
  ) THEN
    -- Add parent_category_id column
    ALTER TABLE public."ItemCategories" 
    ADD COLUMN parent_category_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL;
    RAISE NOTICE '✅ Added parent_category_id column';
  ELSE
    RAISE NOTICE 'ℹ️  Column parent_category_id already exists';
  END IF;

  -- Step 2: Add is_group column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'ItemCategories' 
    AND column_name = 'is_group'
  ) THEN
    ALTER TABLE public."ItemCategories" 
    ADD COLUMN is_group boolean NOT NULL DEFAULT false;
    RAISE NOTICE '✅ Added is_group column (default: false)';
  ELSE
    RAISE NOTICE 'ℹ️  Column is_group already exists';
  END IF;

  -- Step 3: Create parent categories (if they don't exist) - per organization
  FOR org_rec IN SELECT DISTINCT organization_id FROM public."ItemCategories" WHERE deleted = false
  LOOP
    -- FAB (Fabrics)
    INSERT INTO public."ItemCategories" (
      organization_id,
      name,
      code,
      is_group,
      sort_order,
      deleted,
      archived
    )
    SELECT 
      org_rec.organization_id,
      'Fabrics',
      'FAB',
      true,
      1,
      false,
      false
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'FAB' 
        AND is_group = true 
        AND deleted = false
    );

    -- COMP (Components)
    INSERT INTO public."ItemCategories" (
      organization_id,
      name,
      code,
      is_group,
      sort_order,
      deleted,
      archived
    )
    SELECT 
      org_rec.organization_id,
      'Components',
      'COMP',
      true,
      2,
      false,
      false
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'COMP' 
        AND is_group = true 
        AND deleted = false
    );

    -- ACC (Accessories)
    INSERT INTO public."ItemCategories" (
      organization_id,
      name,
      code,
      is_group,
      sort_order,
      deleted,
      archived
    )
    SELECT 
      org_rec.organization_id,
      'Accessories',
      'ACC',
      true,
      3,
      false,
      false
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'ACC' 
        AND is_group = true 
        AND deleted = false
    );

    -- MOTOR (Motors & Controls)
    INSERT INTO public."ItemCategories" (
      organization_id,
      name,
      code,
      is_group,
      sort_order,
      deleted,
      archived
    )
    SELECT 
      org_rec.organization_id,
      'Drives & Controls',
      'MOTOR',
      true,
      4,
      false,
      false
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" 
      WHERE organization_id = org_rec.organization_id 
        AND code = 'MOTOR' 
        AND is_group = true 
        AND deleted = false
    );
  END LOOP;

  RAISE NOTICE '✅ Created parent categories (FAB, COMP, ACC, MOTOR)';

  -- Step 4: Reclassify existing categories per organization
  FOR org_rec IN SELECT DISTINCT organization_id FROM public."ItemCategories" WHERE deleted = false
    LOOP
      -- Get parent IDs for this organization
      SELECT id INTO fab_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'FAB' AND is_group = true AND deleted = false LIMIT 1;
      SELECT id INTO comp_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'COMP' AND is_group = true AND deleted = false LIMIT 1;
      SELECT id INTO acc_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'ACC' AND is_group = true AND deleted = false LIMIT 1;
      SELECT id INTO motor_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'MOTOR' AND is_group = true AND deleted = false LIMIT 1;

      -- Update Fabric-related categories
      IF fab_parent_id IS NOT NULL THEN
        UPDATE public."ItemCategories"
        SET 
          parent_category_id = fab_parent_id,
          is_group = false
        WHERE organization_id = org_rec.organization_id
          AND deleted = false
          AND is_group = false -- Don't update parent groups
          AND (
            LOWER(name) LIKE '%fabric%' OR
            LOWER(name) LIKE '%roller%' OR
            LOWER(name) LIKE '%drapery%' OR
            LOWER(name) LIKE '%window film%' OR
            LOWER(name) LIKE '%film%' OR
            LOWER(code) LIKE 'FAB-%' OR
            LOWER(code) LIKE '%FAB%'
          )
          AND parent_category_id IS NULL;
      END IF;

      -- Update Component-related categories
      IF comp_parent_id IS NOT NULL THEN
        UPDATE public."ItemCategories"
        SET 
          parent_category_id = comp_parent_id,
          is_group = false
        WHERE organization_id = org_rec.organization_id
          AND deleted = false
          AND is_group = false
          AND (
            LOWER(name) LIKE '%tubes & cassettes%' OR
            LOWER(name) LIKE '%tube%' OR
            LOWER(name) LIKE '%cassette%' OR
            LOWER(name) LIKE '%bottom bar%' OR
            LOWER(name) LIKE '%side channel%' OR
            LOWER(name) LIKE '%bracket%' OR
            LOWER(code) LIKE 'COMP-%' OR
            LOWER(code) LIKE '%COMP%'
          )
          AND parent_category_id IS NULL;
      END IF;

      -- Update Accessory-related categories
      IF acc_parent_id IS NOT NULL THEN
        UPDATE public."ItemCategories"
        SET 
          parent_category_id = acc_parent_id,
          is_group = false
        WHERE organization_id = org_rec.organization_id
          AND deleted = false
          AND is_group = false
          AND (
            LOWER(name) LIKE '%remote%' OR
            LOWER(name) LIKE '%battery%' OR
            LOWER(name) LIKE '%sensor%' OR
            LOWER(code) LIKE 'ACC-%' OR
            LOWER(code) LIKE '%ACC%'
          )
          AND parent_category_id IS NULL;
      END IF;

      -- Update Motor/Control-related categories
      IF motor_parent_id IS NOT NULL THEN
        UPDATE public."ItemCategories"
        SET 
          parent_category_id = motor_parent_id,
          is_group = false
        WHERE organization_id = org_rec.organization_id
          AND deleted = false
          AND is_group = false
          AND (
            LOWER(name) LIKE '%manual drive%' OR
            LOWER(name) LIKE '%motorized drive%' OR
            LOWER(name) LIKE '%control%' OR
            LOWER(name) LIKE '%motor%' OR
            LOWER(name) LIKE '%drive%' OR
            LOWER(code) LIKE 'MOTOR-%' OR
            LOWER(code) LIKE '%MOTOR%'
          )
          AND parent_category_id IS NULL;
      END IF;
    END LOOP;

  RAISE NOTICE '✅ Reclassified existing categories';

  -- Step 5: Create child categories if they don't exist (with proper codes)
  -- This is a safety step - create common child categories per organization
  -- Reuse variables from outer scope
  FOR org_rec IN SELECT DISTINCT organization_id FROM public."ItemCategories" WHERE deleted = false
    LOOP
      -- Get parent IDs for this organization
      SELECT id INTO fab_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'FAB' AND is_group = true AND deleted = false LIMIT 1;
      SELECT id INTO comp_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'COMP' AND is_group = true AND deleted = false LIMIT 1;
      SELECT id INTO acc_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'ACC' AND is_group = true AND deleted = false LIMIT 1;
      SELECT id INTO motor_parent_id FROM public."ItemCategories" 
        WHERE organization_id = org_rec.organization_id AND code = 'MOTOR' AND is_group = true AND deleted = false LIMIT 1;

      -- Create child categories if they don't exist
      -- FAB children
      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Roller Shade Fabrics', 'FAB-ROLLER', fab_parent_id, false, 1, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'FAB-ROLLER' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Drapery Fabrics', 'FAB-DRAPERY', fab_parent_id, false, 2, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'FAB-DRAPERY' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Window Film', 'FAB-FILM', fab_parent_id, false, 3, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'FAB-FILM' AND deleted = false);

      -- COMP children
      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Tubes & Cassettes', 'COMP-TUBE', comp_parent_id, false, 1, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'COMP-TUBE' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Bottom Bars', 'COMP-BOTTOM', comp_parent_id, false, 2, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'COMP-BOTTOM' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Side Channels', 'COMP-SIDE', comp_parent_id, false, 3, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'COMP-SIDE' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Brackets', 'COMP-BRACKET', comp_parent_id, false, 4, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'COMP-BRACKET' AND deleted = false);

      -- ACC children
      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Remotes', 'ACC-REMOTE', acc_parent_id, false, 1, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'ACC-REMOTE' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Batteries', 'ACC-BATTERY', acc_parent_id, false, 2, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'ACC-BATTERY' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Sensors', 'ACC-SENSOR', acc_parent_id, false, 3, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'ACC-SENSOR' AND deleted = false);

      -- MOTOR children
      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Manual Drives', 'MOTOR-MANUAL', motor_parent_id, false, 1, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'MOTOR-MANUAL' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Motorized Drives', 'MOTOR-MOTORIZED', motor_parent_id, false, 2, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'MOTOR-MOTORIZED' AND deleted = false);

      INSERT INTO public."ItemCategories" (organization_id, name, code, parent_category_id, is_group, sort_order, deleted, archived)
      SELECT org_rec.organization_id, 'Controls', 'MOTOR-CONTROL', motor_parent_id, false, 3, false, false
      WHERE NOT EXISTS (SELECT 1 FROM public."ItemCategories" WHERE organization_id = org_rec.organization_id AND code = 'MOTOR-CONTROL' AND deleted = false);
  END LOOP;

  RAISE NOTICE '✅ Created child categories (if they did not exist)';

  -- Step 6: Add index on parent_category_id for performance
  CREATE INDEX IF NOT EXISTS idx_itemcategories_parent_category_id 
    ON public."ItemCategories"(parent_category_id) 
    WHERE parent_category_id IS NOT NULL;

  CREATE INDEX IF NOT EXISTS idx_itemcategories_is_group 
    ON public."ItemCategories"(is_group) 
    WHERE is_group = true;

  RAISE NOTICE '✅ Created indexes';

  -- Step 7: Add check constraint to prevent circular references
  -- (A category cannot be its own parent, and cannot have a parent that is a child)
  -- This is handled by the FK constraint, but we can add a check for self-reference
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_itemcategories_no_self_parent' 
    AND conrelid = '"ItemCategories"'::regclass
  ) THEN
    ALTER TABLE public."ItemCategories"
    ADD CONSTRAINT check_itemcategories_no_self_parent
    CHECK (id != parent_category_id);
    RAISE NOTICE '✅ Added check constraint (no self-parent)';
  ELSE
    RAISE NOTICE 'ℹ️  Check constraint already exists';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration completed successfully';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Summary:';
  RAISE NOTICE '   - Added parent_category_id column';
  RAISE NOTICE '   - Added is_group column';
  RAISE NOTICE '   - Created parent categories (FAB, COMP, ACC, MOTOR)';
  RAISE NOTICE '   - Reclassified existing categories';
  RAISE NOTICE '   - Created child categories';
  RAISE NOTICE '   - Added indexes and constraints';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  Next steps:';
  RAISE NOTICE '   1. Update frontend to show only leaf categories (is_group=false) in dropdowns';
  RAISE NOTICE '   2. Update Categories admin UI to show grouped view';
  RAISE NOTICE '   3. Add warning badge if CatalogItem points to is_group=true category';
  RAISE NOTICE '';
END $$;

