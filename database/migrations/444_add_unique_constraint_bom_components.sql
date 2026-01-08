-- Migration 444: Add unique constraint to BOMComponents to prevent duplicates
-- This prevents duplicate components with the same logical key (bom_template_id, component_item_id, role, condition, color_id)

-- Step 1: Clean up existing duplicates first (keep most recent)
-- This uses the cleanup script logic to remove duplicates before adding constraint
-- Note: block_condition is JSONB, so we convert to text for comparison
WITH ranked AS (
  SELECT
    id,
    bom_template_id,
    component_item_id,
    component_role,
    COALESCE(block_condition::text, '') AS condition_norm,
    COALESCE(hardware_color::text, '') AS color_norm,
    updated_at,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY 
        bom_template_id, 
        component_item_id, 
        component_role, 
        COALESCE(block_condition::text, ''), 
        COALESCE(hardware_color::text, '')
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
    ) AS rn
  FROM "BOMComponents"
  WHERE deleted = false
)
DELETE FROM "BOMComponents" c
USING ranked r
WHERE c.id = r.id
  AND r.rn > 1;

-- Step 2: Add unique constraint
-- Using expression index to handle nullable fields (condition and color_id)
-- Note: block_condition is JSONB, so we convert to text for comparison
CREATE UNIQUE INDEX IF NOT EXISTS bomcomponents_unique_logical_key
ON "BOMComponents" (
  bom_template_id,
  component_item_id,
  component_role,
  COALESCE(block_condition::text, ''),
  COALESCE(hardware_color::text, '')
)
WHERE deleted = false;

-- Step 3: Add comment for documentation
COMMENT ON INDEX bomcomponents_unique_logical_key IS 
'Prevents duplicate BOM components with the same logical key (template, item, role, condition, color). Nullable fields are normalized to empty string.';

-- Step 4: Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

