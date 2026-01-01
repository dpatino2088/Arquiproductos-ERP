-- ========================================
-- FIX: Re-approve Quote to Trigger BOM Creation
-- ========================================
-- This script helps re-approve a Quote to trigger BOM creation
-- INSTRUCTIONS: Replace 'SO-000006' with your Sale Order number
-- ========================================

-- Step 1: Check current Quote status
SELECT 
  'Step 1: Current Quote Status' as check_name,
  q.id as quote_id,
  q.quote_no,
  q.status,
  so.sale_order_no
FROM "SaleOrders" so
  INNER JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 2: Re-approve Quote (uncomment to execute)
/*
-- First, set status to 'draft' to allow re-approval
UPDATE "Quotes"
SET 
  status = 'draft',
  updated_at = NOW()
WHERE id = (
  SELECT q.id
  FROM "SaleOrders" so
  INNER JOIN "Quotes" q ON q.id = so.quote_id
  WHERE so.sale_order_no = 'SO-000006'
    AND so.deleted = false
  LIMIT 1
);

-- Then, set status back to 'approved' to trigger the function
UPDATE "Quotes"
SET 
  status = 'approved',
  updated_at = NOW()
WHERE id = (
  SELECT q.id
  FROM "SaleOrders" so
  INNER JOIN "Quotes" q ON q.id = so.quote_id
  WHERE so.sale_order_no = 'SO-000006'
    AND so.deleted = false
  LIMIT 1
);
*/

-- Step 3: Verify BomInstances were created after re-approval
SELECT 
  'Step 3: BomInstances After Re-approval' as check_name,
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  bi.status,
  COUNT(bil.id) as bom_instance_line_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bi.id, bi.sale_order_line_id, bi.status;

-- ========================================
-- INSTRUCTIONS
-- ========================================
-- 
-- 1. Review Step 1 to see current Quote status
-- 2. If status is 'approved', uncomment Step 2 to re-approve
-- 3. After re-approval, check Step 3 to verify BomInstances were created
-- 4. Run CHECK_BOM_COMPLETE_FLOW.sql again to verify all components
--
-- ========================================








