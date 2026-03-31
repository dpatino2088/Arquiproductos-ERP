-- Drop legacy unique constraints on BOMComponents that prevent the same SKU
-- from being used in multiple roles within the same BOM template.
--
-- The original table-level constraint (parent_item_id, component_item_id, organization_id)
-- and the matching partial index block adding the same component_item_id twice
-- regardless of component_role. This is too restrictive: a single SKU (e.g. a channel
-- profile) legitimately appears as both "bottom_channel" and "side_channel" in the
-- same template.
--
-- The correct constraint already exists: bomcomponents_unique_logical_key
-- which includes (bom_template_id, component_item_id, component_role,
-- block_condition, hardware_color), allowing the same SKU in different roles.

-- 1. Drop the table-level constraint
ALTER TABLE public."BOMComponents"
  DROP CONSTRAINT IF EXISTS bom_components_parent_component_unique;

-- 2. Drop the redundant partial unique index
DROP INDEX IF EXISTS idx_bom_components_parent_component_unique;

-- 3. Verify the correct constraint is still in place
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'BOMComponents'
      AND indexname = 'bomcomponents_unique_logical_key'
  ) THEN
    RAISE WARNING 'bomcomponents_unique_logical_key index is missing — same-SKU-different-role will be unrestricted';
  END IF;
END $$;
