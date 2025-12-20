-- ====================================================
-- Migration: Fix BOMComponents constraint for auto_select
-- ====================================================
-- This migration ensures that the constraint allows NULL component_item_id
-- when auto_select = true (for components resolved by rules)
-- ====================================================

DO $$
DECLARE
  v_rows_updated integer;
BEGIN
  RAISE NOTICE '🔧 Fixing BOMComponents constraint for auto_select...';
  RAISE NOTICE '';

  -- STEP 1: Drop existing constraint if it exists
  ALTER TABLE public."BOMComponents"
    DROP CONSTRAINT IF EXISTS check_bomcomponents_fixed_has_item;

  RAISE NOTICE '  ✅ Dropped existing constraint';

  -- STEP 2: Clean existing data - set auto_select = true for rows with component_item_id = NULL
  UPDATE public."BOMComponents"
  SET auto_select = true
  WHERE component_item_id IS NULL
  AND (auto_select = false OR auto_select IS NULL);

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  RAISE NOTICE '  ✅ Updated % rows: set auto_select = true for NULL component_item_id', v_rows_updated;

  -- STEP 3: Set auto_select = false for rows with component_item_id NOT NULL and auto_select IS NULL (legacy)
  UPDATE public."BOMComponents"
  SET auto_select = false
  WHERE component_item_id IS NOT NULL
  AND auto_select IS NULL;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  RAISE NOTICE '  ✅ Updated % rows: set auto_select = false for NOT NULL component_item_id (legacy)', v_rows_updated;

  -- STEP 4: Create new constraint that allows NULL component_item_id when auto_select = true
  ALTER TABLE public."BOMComponents"
    ADD CONSTRAINT check_bomcomponents_fixed_has_item 
    CHECK (
      -- If auto_select = false, component_item_id must be NOT NULL
      (auto_select = false AND component_item_id IS NOT NULL)
      OR
      -- If auto_select = true, component_item_id can be NULL (resolved by rules)
      (auto_select = true)
      OR
      -- If auto_select is NULL (legacy), component_item_id must be NOT NULL
      (auto_select IS NULL AND component_item_id IS NOT NULL)
    );

  RAISE NOTICE '  ✅ Updated check_bomcomponents_fixed_has_item constraint';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Constraint now allows:';
  RAISE NOTICE '   - auto_select = false → component_item_id must be NOT NULL';
  RAISE NOTICE '   - auto_select = true → component_item_id can be NULL (resolved by rules)';
  RAISE NOTICE '   - auto_select = NULL → component_item_id must be NOT NULL (legacy)';

END $$;

