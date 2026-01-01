# Verification Checklist - Migration 214

## PHASE A: SalesOrders appearing in UI

### A1) Check SalesOrders count:
```sql
SELECT 
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE deleted = false) AS active,
  COUNT(*) FILTER (WHERE deleted = true) AS deleted_count
FROM "SalesOrders";
```
**Expected**: `active > 0` if SalesOrders exist

### A2) Verify default is set:
```sql
SELECT 
  column_name, 
  column_default, 
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SalesOrders'
AND column_name = 'deleted';
```
**Expected**: `column_default = 'false'`

### A3) Manual fix if needed (dev only - choose ONE):
```sql
-- Option 1: Safe - only last 30 days
UPDATE "SalesOrders"
SET deleted = false
WHERE deleted = true
  AND created_at >= NOW() - INTERVAL '30 days';

-- Option 2: Global (dev only - be careful!)
UPDATE "SalesOrders"
SET deleted = false
WHERE deleted = true;
```

### A4) Ensure trigger creates deleted=false:
If inserts come out as `deleted=true`, the bug could be:
- Bad default
- Trigger/function inserting explicitly `deleted=true`
- INSERT copying `deleted` from Quote

**Quick check**:
```sql
SELECT sale_order_no, deleted, created_at
FROM "SalesOrders"
ORDER BY created_at DESC
LIMIT 20;
```
**Expected**: Recent SalesOrders should have `deleted = false`

---

## PHASE B: BOM generates but cut_length_mm is NULL

### B1) Find MO-000001 and its BOM instance (CORRECTED JOIN):
```sql
SELECT 
  mo.id AS manufacturing_order_id,
  mo.manufacturing_order_no,
  mo.sale_order_id,
  mo.sale_order_line_id,
  bi.id AS bom_instance_id,
  bi.status AS bom_status,
  so.sale_order_no
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "BomInstances" bi 
  ON bi.sale_order_line_id = mo.sale_order_line_id
 AND bi.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000001'
LIMIT 1;
```
**Expected**: `bom_instance_id NOT NULL`

### B2) First, check actual column names in BomInstanceLines:
```sql
SELECT column_name
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name='BomInstanceLines'
ORDER BY ordinal_position;
```

### B2) Inspect BOM instance lines (replace `<BOM_INSTANCE_ID>`):
```sql
-- Use the correct column names from the query above
-- Typical schema uses: resolved_sku, part_role, OR sku, component_role
SELECT
  bil.id,
  bil.resolved_sku,  -- or bil.sku if that's the column name
  bil.part_role,     -- or bil.component_role if that's the column name
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'
  AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku;  -- Adjust column names as needed
```
**Expected**: 
- `tube` should have `cut_length_mm IS NOT NULL`
- `bottom_rail_profile` should have `cut_length_mm IS NOT NULL`
- If all `cut_*` are NULL: the pipeline didn't run calculation or lacked inputs

### B3) Check BOM template:
```sql
SELECT 
  bi.id,
  bi.bom_template_id,
  bt.name AS template_name,
  bt.active
FROM "BomInstances" bi
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE bi.id = '<BOM_INSTANCE_ID>';
```
**Expected**: `template_name = 'ROLLER_MANUAL_STANDARD'` or similar

### B4) Verify engineering rules exist (more explicit):
```sql
SELECT
  bc.id,
  bc.sequence_order,
  bc.component_role,
  bc.affects_role,
  bc.cut_axis,
  bc.cut_delta_mm,
  bc.cut_delta_scope,
  bc.notes
FROM "BOMComponents" bc
WHERE bc.bom_template_id = (
  SELECT id FROM "BOMTemplates"
  WHERE name = 'ROLLER_MANUAL_STANDARD'
    AND deleted = false
  LIMIT 1
)
AND bc.deleted = false
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis <> 'none'
ORDER BY bc.sequence_order;
```
**Expected rules**:
- `bracket` → `tube` (length)
- `bottom_rail_profile` → `bottom_rail_profile` (length)
- `idle_end/pin` → `tube` (length)

---

## PHASE C: Verify compute has inputs

### C1) Check inputs for SO-053830:
```sql
SELECT 
  sol.id, 
  sol.width_m,
  sol.height_m,
  sol.product_type, 
  sol.drive_type,
  sol.qty,
  sol.product_type_id
FROM "SalesOrderLines" sol
WHERE sol.sale_order_id = (
  SELECT id FROM "SalesOrders" WHERE sale_order_no = 'SO-053830'
)
AND sol.deleted = false;
```
**Expected**: `width_m IS NOT NULL` and `height_m IS NOT NULL`

### C2) Check QuoteLine for the same dimensions:
```sql
SELECT 
  ql.id,
  ql.width_m,
  ql.height_m,
  ql.qty
FROM "QuoteLines" ql
WHERE ql.quote_id = (
  SELECT quote_id FROM "SalesOrders" WHERE sale_order_no = 'SO-053830'
)
AND ql.deleted = false;
```
**Expected**: Dimensions should match SalesOrderLines

### C3) Verify engineering rules function exists AND is called by trigger:
```sql
-- First, check function exists
SELECT 
  p.proname,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'apply_engineering_rules_to_bom_instance'
AND n.nspname = 'public';
```
**Expected**: Function exists and reads from SalesOrderLines/QuoteLines for width_m/height_m

### C3b) Verify trigger calls the function:
```sql
-- Check triggers on SalesOrders table
SELECT 
  t.tgname,
  p.proname AS function_name,
  pg_get_functiondef(p.oid) AS function_def
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = '"SalesOrders"'::regclass
  AND NOT t.tgisinternal;
```
**Expected**: The trigger function (e.g., `on_sale_order_status_changed_generate_bom` or `on_quote_approved_create_operational_docs`) must contain a call to `apply_engineering_rules_to_bom_instance(...)` or the function that sets `cut_length_mm`.

**Manually inspect**: Open the trigger function definition and search for `apply_engineering_rules_to_bom_instance` to confirm it's called.

---

## PHASE D: RC3085 rule verification

### D1) Check idle_end components in template:
```sql
SELECT
  bc.id,
  bc.component_role,
  ci.sku,
  bc.affects_role,
  bc.cut_axis,
  bc.cut_delta_mm,
  bc.cut_delta_scope
FROM "BOMComponents" bc
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bc.bom_template_id = (
  SELECT id FROM "BOMTemplates"
  WHERE name = 'ROLLER_MANUAL_STANDARD' AND deleted=false
  LIMIT 1
)
AND bc.component_role IN ('idle_end', 'pin')
AND bc.deleted = false;
```
**Expected**: 
- Should have `affects_role = 'tube'`
- Should have `cut_axis = 'length'`
- Should have `cut_delta_scope` coherente

### D2) Verify RC3085 vs RC3005+RC2003 exclusivity in BOM instance:
```sql
-- Replace <BOM_INSTANCE_ID> with actual ID from B1
SELECT 
  bil.resolved_sku,  -- or bil.sku
  bil.part_role,     -- or bil.component_role
  bil.qty
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'
  AND bil.deleted = false
  AND bil.resolved_sku IN ('RC3085', 'RC3085-W', 'RC3005', 'RC2003');
```
**Expected**: 
- Either RC3085(-W) appears alone, OR
- RC3005 + RC2003 appear together
- Never mixed (RC3085 with RC3005/RC2003)

---

## FINAL ACCEPTANCE

### SalesOrders:
- ✅ `/sale-orders` shows existing orders
- ✅ Active SalesOrders have `deleted = false`

### BOM:
- ✅ `tube` has `cut_length_mm IS NOT NULL`
- ✅ `bottom_rail_profile` has `cut_length_mm IS NOT NULL`
- ✅ `calc_notes` explains base + deltas (if implemented)

### UI:
- ✅ Materials tab shows Cut L (mm) values (not "—")
- ✅ Cut List shows Cut L (mm) values (not "—")
- ✅ Totals and quantities make sense per UoM

