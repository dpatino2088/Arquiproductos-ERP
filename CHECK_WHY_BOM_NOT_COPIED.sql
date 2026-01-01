-- ========================================
-- CHECK: Why BomInstanceLines are Empty
-- ========================================
-- This script checks why components weren't copied to BomInstanceLines
-- INSTRUCTIONS: Replace 'SO-000006' with your Sale Order number
-- ========================================

-- Step 1: Check Quote status
SELECT 
  'Step 1: Quote Status' as check_name,
  q.id as quote_id,
  q.quote_no,
  q.status,
  q.organization_id,
  CASE 
    WHEN q.status = 'approved' THEN '✅ Approved (trigger should have run)'
    WHEN q.status = 'draft' THEN '⚠️ Draft (trigger will not run)'
    ELSE '⚠️ Other status'
  END as status_info
FROM "SaleOrders" so
  INNER JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 2: Check QuoteLineComponents that should be copied
SELECT 
  'Step 2: QuoteLineComponents to Copy' as check_name,
  qlc.id as quote_line_component_id,
  qlc.quote_line_id,
  qlc.component_role,
  qlc.source,
  qlc.catalog_item_id,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  ci.is_fabric,
  ci.deleted as catalog_item_deleted
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component'
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 3: Check if BomInstances exist
SELECT 
  'Step 3: BomInstances Status' as check_name,
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  bi.quote_line_id,
  bi.status,
  bi.created_at
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 4: Check if BomInstanceLines exist (even if empty)
SELECT 
  'Step 4: BomInstanceLines Status' as check_name,
  bil.id as bom_instance_line_id,
  bil.bom_instance_id,
  bil.resolved_part_id,
  bil.part_role,
  bil.qty,
  bil.uom,
  ci.sku,
  ci.item_name
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000006' -- CHANGE THIS
  AND so.deleted = false;

-- Step 5: Check if trigger function exists and is enabled
SELECT 
  'Step 5: Trigger Status' as check_name,
  tg.trigger_name,
  tg.event_manipulation,
  tg.event_object_table,
  tg.action_statement,
  tg.action_timing,
  CASE 
    WHEN tg.trigger_name IS NOT NULL THEN '✅ Trigger exists'
    ELSE '❌ Trigger not found'
  END as trigger_status
FROM information_schema.triggers tg
WHERE tg.trigger_name = 'trg_on_quote_approved_create_operational_docs'
  AND tg.event_object_table = 'Quotes'
LIMIT 1;

-- ========================================
-- INTERPRETATION
-- ========================================
-- 
-- Step 1: If status is not 'approved' → Quote needs to be approved
-- Step 2: Shows what should be copied (QuoteLineComponents with source='configured_component')
-- Step 3: If BomInstances is empty → Trigger didn't run or failed
-- Step 4: If BomInstanceLines is empty → Components weren't copied (check Step 2 for issues)
-- Step 5: If trigger not found → Trigger needs to be created
--
-- Common issues:
-- - Quote status is not 'approved' → Change to 'approved'
-- - CatalogItems are deleted → Fix ci.deleted = false
-- - Trigger didn't run → Check logs or re-approve Quote
--
-- ========================================








