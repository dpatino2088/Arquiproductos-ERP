-- Script: Cleanup duplicate BOM Components
-- Purpose: Remove duplicate components keeping only the most recently updated one per logical key
-- Run this BEFORE applying migration 444 if you have existing duplicates

-- Keep the newest row per logical key, delete the rest
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
  AND r.rn > 1
RETURNING c.id, c.bom_template_id, c.component_item_id, c.component_role;

-- Verification query: Check for remaining duplicates
SELECT 
  bom_template_id,
  component_item_id,
  component_role,
  COALESCE(block_condition::text, '') AS condition_norm,
  COALESCE(hardware_color::text, '') AS color_norm,
  COUNT(*) AS duplicate_count
FROM "BOMComponents"
WHERE deleted = false
GROUP BY 
  bom_template_id,
  component_item_id,
  component_role,
  COALESCE(block_condition::text, ''),
  COALESCE(hardware_color::text, '')
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

