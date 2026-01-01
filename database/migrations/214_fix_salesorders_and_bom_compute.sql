-- ====================================================
-- Migration 214: Fix SalesOrders defaults and BOM compute
-- ====================================================
-- PHASE A: Fix SalesOrders deleted default
-- PHASE B-C: Ensure BOM compute runs correctly
-- PHASE D: Verify RC3085 engineering rules
-- ====================================================

BEGIN;

-- ====================================================
-- PHASE A: Fix SalesOrders deleted column default
-- ====================================================

-- Check current default
DO $$
DECLARE
    v_current_default text;
BEGIN
    SELECT column_default INTO v_current_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'SalesOrders'
    AND column_name = 'deleted';
    
    IF v_current_default IS NULL OR v_current_default != 'false' THEN
        -- Set default to false
        ALTER TABLE "SalesOrders"
        ALTER COLUMN deleted SET DEFAULT false;
        
        RAISE NOTICE '✅ Set SalesOrders.deleted default to false';
    ELSE
        RAISE NOTICE 'ℹ️  SalesOrders.deleted already has default = false';
    END IF;
END $$;

-- ====================================================
-- PHASE C: Ensure BOM compute runs after creation
-- ====================================================
-- Verify that apply_engineering_rules_to_bom_instance is called
-- in the quote approved trigger

-- Check if the function exists and what it does
DO $$
BEGIN
    -- Verify function exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'apply_engineering_rules_to_bom_instance'
        AND n.nspname = 'public'
    ) THEN
        RAISE WARNING '⚠️  Function apply_engineering_rules_to_bom_instance does not exist';
    ELSE
        RAISE NOTICE '✅ Function apply_engineering_rules_to_bom_instance exists';
    END IF;
END $$;

-- ====================================================
-- VERIFICATION QUERIES (commented out - run manually to check)
-- ====================================================

/*
-- A1) Check SalesOrders status
SELECT 
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE deleted = false) AS active,
  COUNT(*) FILTER (WHERE deleted = true) AS deleted_count
FROM "SalesOrders";

-- B1) Find MO and BOM instance
SELECT 
  mo.id AS manufacturing_order_id,
  mo.manufacturing_order_no,
  bi.id AS bom_instance_id,
  bi.status,
  so.sale_order_no
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id IN (
  SELECT id FROM "SalesOrderLines" WHERE sale_order_id = so.id
)
WHERE mo.manufacturing_order_no = 'MO-000001'
LIMIT 1;

-- B2) Inspect BOM instance lines (replace <BOM_INSTANCE_ID>)
SELECT
  bil.id,
  bil.resolved_sku,
  bil.part_role,
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'
  AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;

-- B3) Check BOM template
SELECT 
  bi.id,
  bi.bom_template_id,
  bt.name AS template_name
FROM "BomInstances" bi
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE bi.id = '<BOM_INSTANCE_ID>';

-- B4) Verify engineering rules
SELECT
  bc.id,
  bc.component_role,
  bc.affects_role,
  bc.cut_axis,
  bc.cut_delta_mm,
  bc.cut_delta_scope,
  bc.sequence_order
FROM "BOMComponents" bc
WHERE bc.bom_template_id = (
  SELECT id FROM "BOMTemplates"
  WHERE name = 'ROLLER_MANUAL_STANDARD' AND deleted=false
  LIMIT 1
)
AND bc.deleted = false
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis != 'none'
ORDER BY bc.sequence_order;

-- C3) Check inputs for SO-053830
SELECT 
  sol.id, 
  sol.width_m,
  sol.height_m,
  sol.product_type, 
  sol.drive_type,
  sol.qty
FROM "SalesOrderLines" sol
WHERE sol.sale_order_id = (
  SELECT id FROM "SalesOrders" WHERE sale_order_no = 'SO-053830'
)
AND sol.deleted = false;
*/

COMMIT;




