# Execution Summary - Fixes for SalesOrders and BOM Compute

## Overview
This set of migrations fixes three critical issues:
1. **SalesOrders not appearing** (deleted column default)
2. **BOM cut dimensions not computed** (engineering rules function bug)
3. **Existing BOMs missing cut dimensions** (backfill)

## Migration Order

Execute in this order:

1. **214_fix_salesorders_and_bom_compute.sql** - Sets default for `deleted` column
2. **215_fix_engineering_rules_function.sql** - Fixes the engineering rules computation function
3. **216_reapply_engineering_rules_existing_boms.sql** - Backfills cut dimensions for existing BOMs

## What Each Migration Does

### Migration 214
- ✅ Sets `SalesOrders.deleted` default to `false`
- ✅ Verifies that `apply_engineering_rules_to_bom_instance` function exists

### Migration 215 (Critical Fix)
- ✅ **Fixes the engineering rules function** to:
  - Get rules directly from `BOMComponents` (not through non-existent `quote_line_component_id`)
  - Handle `bottom_rail_profile` base dimensions
  - Match rules by `part_role` correctly
  - Apply base dimensions even when no rules exist
  - Better error handling and fallbacks

### Migration 216
- ✅ Re-runs engineering rules for all existing `BomInstances` that have `cut_length_mm IS NULL`
- ✅ Updates `tube` and `bottom_rail_profile` components

## Verification Steps

After running migrations, use **VERIFICATION_CHECKLIST_214.md** to verify:

1. **SalesOrders appear in UI** (query A1, A2)
2. **BOM cut dimensions are computed** (queries B1-B4)
3. **Inputs exist** (queries C1-C3)
4. **RC3085 rules exist** (query D1)

## Expected Results

### After Migration 214:
- New `SalesOrders` will have `deleted = false` by default
- Historical `SalesOrders` may still be `deleted = true` (run one-time fix if needed)

### After Migration 215:
- New BOMs will correctly compute `cut_length_mm`, `cut_width_mm`, `cut_height_mm`
- `tube` components will have length based on `width_m * 1000`
- `bottom_rail_profile` components will have length based on `width_m * 1000`
- Engineering rule deltas will be applied correctly

### After Migration 216:
- Existing BOMs will have cut dimensions populated
- Materials tab in UI should show Cut L (mm) values (not "—")
- Cut List tab should show Cut L (mm) values (not "—")

## One-Time Fix (Dev Only)

If you have historical SalesOrders that are incorrectly soft-deleted:

```sql
-- Safe: only last 30 days
UPDATE "SalesOrders"
SET deleted = false
WHERE deleted = true
  AND created_at >= NOW() - INTERVAL '30 days';

-- OR Global (dev only - be careful!)
UPDATE "SalesOrders"
SET deleted = false
WHERE deleted = true;
```

## Testing Checklist

- [ ] Run migration 214
- [ ] Run migration 215
- [ ] Run migration 216
- [ ] Verify SalesOrders appear in `/sale-orders` page
- [ ] Verify a Manufacturing Order shows materials with Cut L (mm) values
- [ ] Verify Cut List tab shows Cut L (mm) values
- [ ] Create a new Quote, approve it, verify SalesOrder created
- [ ] Verify new SalesOrder's BOM has cut dimensions computed




