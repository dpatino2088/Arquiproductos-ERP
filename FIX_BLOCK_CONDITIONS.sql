-- ========================================
-- FIX: Adjust Block Conditions in BOMComponents
-- ========================================
-- This script helps identify and fix block_condition mismatches
-- INSTRUCTIONS: 
-- 1. Replace 'YOUR_BOM_TEMPLATE_ID' with your actual BOMTemplate ID
-- 2. Review the block_condition values and adjust them to match your QuoteLine configurations
-- ========================================

-- INSTRUCTIONS: Replace 'YOUR_BOM_TEMPLATE_ID' with actual value

-- Step 1: Check current block_conditions
SELECT 
  'Current Block Conditions' as check_name,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.hardware_color,
  COUNT(*) as count
FROM "BOMComponents" bc
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.deleted = false
GROUP BY bc.component_role, bc.block_type, bc.block_condition, bc.applies_color, bc.hardware_color
ORDER BY bc.component_role;

-- Step 2: Check what values are actually in QuoteLines
SELECT 
  'QuoteLine Configuration Values' as check_name,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.cassette_type,
  ql.side_channel,
  ql.side_channel_type,
  ql.hardware_color,
  COUNT(*) as count
FROM "QuoteLines" ql
WHERE ql.deleted = false
  AND ql.product_type_id IN (
    SELECT product_type_id 
    FROM "BOMTemplates" 
    WHERE id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  )
GROUP BY ql.drive_type, ql.bottom_rail_type, ql.cassette, ql.cassette_type, 
         ql.side_channel, ql.side_channel_type, ql.hardware_color
ORDER BY count DESC;

-- Step 3: Example fixes for common issues

-- Fix 1: Make drive components work for both 'motor' and 'manual'
-- Option A: Create separate components for each drive type
-- Option B: Remove block_condition to make it always active
/*
UPDATE "BOMComponents"
SET 
  block_condition = NULL, -- Remove condition to make always active
  updated_at = now()
WHERE bom_template_id = :bom_template_id_param::uuid
  AND component_role = 'operating_system_drive'
  AND block_condition->>'drive_type' IS NOT NULL
  AND deleted = false;
*/

-- Fix 2: Make bottom_bar work for both 'standard' and 'wrapped'
-- Option A: Create separate components for each type
-- Option B: Remove block_condition
/*
UPDATE "BOMComponents"
SET 
  block_condition = NULL, -- Remove condition to make always active
  updated_at = now()
WHERE bom_template_id = :bom_template_id_param::uuid
  AND component_role = 'bottom_bar'
  AND block_condition->>'bottom_rail_type' IS NOT NULL
  AND deleted = false;
*/

-- Fix 3: Make cassette components optional (only when cassette = true)
-- Keep block_condition but ensure it matches QuoteLine values
/*
UPDATE "BOMComponents"
SET 
  block_condition = jsonb_build_object('cassette', true),
  updated_at = now()
WHERE bom_template_id = :bom_template_id_param::uuid
  AND component_role LIKE '%cassette%'
  AND deleted = false;
*/

-- Fix 4: Make side_channel components optional (only when side_channel = true)
/*
UPDATE "BOMComponents"
SET 
  block_condition = jsonb_build_object('side_channel', true),
  updated_at = now()
WHERE bom_template_id = :bom_template_id_param::uuid
  AND component_role LIKE '%side_channel%'
  AND deleted = false;
*/

-- Fix 5: Adjust hardware_color matching
-- If applies_color = true, ensure hardware_color matches QuoteLine values
/*
UPDATE "BOMComponents"
SET 
  hardware_color = 'white', -- or the most common color
  updated_at = now()
WHERE bom_template_id = :bom_template_id_param::uuid
  AND applies_color = true
  AND hardware_color IS NULL
  AND deleted = false;
*/

-- ========================================
-- Step 4: Verify Block Conditions After Fix
-- ========================================
SELECT 
  'Verification: Block Conditions after fix' as check_name,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.hardware_color,
  CASE 
    WHEN bc.block_condition IS NULL OR bc.block_condition = '{}'::jsonb THEN '✅ Always Active'
    WHEN bc.block_condition IS NOT NULL THEN '⚠️ Conditional'
    ELSE '❌ Unknown'
  END as status
FROM "BOMComponents" bc
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.deleted = false
ORDER BY bc.sequence_order;

-- ========================================
-- NOTE: After adjusting block_conditions:
-- 1. Test BOM generation with different configurations
-- 2. Verify that components appear when conditions match
-- 3. Ensure components don't appear when conditions don't match
-- ========================================

